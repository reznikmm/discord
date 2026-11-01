--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Ada.Exceptions;

with VSS.Strings.Conversions;

with Discord.Gateway.Payloads;

package body Discord.Gateway is

   use type Ada.Real_Time.Time;
   use type Discord.Schema.Integer_64;
   use type Discord.Gateway.Payloads.Event_Kind;

   package Web_Sockets renames Discord.Implementation.Web_Sockets;

   Hello_Timeout : constant Duration := 30.0;

   URL_Parameters : constant String := "/?v=10&encoding=json";

   Library_Name : constant VSS.Strings.Virtual_String := "discord-ada";

   procedure Open (Self : in out Client; URL : String);
   --  Open web socket connection to URL, wait for Hello

   procedure Identify (Self : in out Client);
   --  Send Identify payload to start a new session

   procedure Resume (Self : in out Client);
   --  Send Resume payload to continue the session

   procedure Reconnect (Self : in out Client; Try_Resume : Boolean);
   --  Close connection and open a new one. Resume the session if Try_Resume
   --  and the session is known, otherwise start a new session.

   procedure Send_Heartbeat (Self : in out Client);
   --  Send Heartbeat payload and plan the next one

   procedure Process
     (Self     : in out Client;
      Listener : in out Discord.Gateway.Listener'Class;
      Text     : String);
   --  Process a payload received from the server

   procedure Process_Close (Self : in out Client);
   --  Process the closed connection: reconnect or raise Gateway_Error

   procedure Raise_Gateway_Error (Self : Client; Message : String)
     with No_Return;
   --  Raise Gateway_Error with Message and the close code/reason if any

   function To_UTF_8 (Text : VSS.Strings.Virtual_String) return String is
     (VSS.Strings.Conversions.To_UTF_8_String (Text));

   -------------
   -- Connect --
   -------------

   procedure Connect
     (Self    : in out Client;
      Token   : VSS.Strings.Virtual_String;
      Intents : Intent_Set;
      URL     : String := Default_URL) is
   begin
      Self.URL := Ada.Strings.Unbounded.To_Unbounded_String (URL);
      Self.Token := Token;
      Self.Intents := Intents;
      Self.Sequence := (Is_Set => False);
      Self.Session_Id.Clear;
      Self.Resume_URL.Clear;
      Self.Stop_Requested := False;

      Self.Open (URL);
      Self.Identify;
   end Connect;

   --------------
   -- Identify --
   --------------

   procedure Identify (Self : in out Client) is
      Data : constant Discord.Schema.GatewayIdentifyData :=
        (token           => Self.Token,
         properties      =>
           (os      => "unknown",
            browser => Library_Name,
            device  => Library_Name),
         intents         => To_Bit_Field (Self.Intents),
         compress        => False,
         large_threshold => (Is_Set => False));
   begin
      Self.Web_Socket.Send_Text (Payloads.Encode_Identify (Data));
   end Identify;

   ----------
   -- Open --
   ----------

   procedure Open (Self : in out Client; URL : String) is
      Text    : Ada.Strings.Unbounded.Unbounded_String;
      Status  : Web_Sockets.Receive_Status;
      Event   : Payloads.Event;
      Success : Boolean;
   begin
      begin
         Self.Web_Socket.Connect (URL);
      exception
         when Error : Web_Sockets.Connection_Error =>
            raise Gateway_Error with Ada.Exceptions.Exception_Message (Error);
      end;

      Self.Web_Socket.Receive (Text, Hello_Timeout, Status);

      case Status is
         when Web_Sockets.Received =>
            Payloads.Decode
              (Ada.Strings.Unbounded.To_String (Text), Event, Success);

            if not Success or else Event.Kind /= Payloads.Hello then
               raise Gateway_Error with
                 "Hello expected, but got: "
                 & Ada.Strings.Unbounded.To_String (Text);
            end if;

            Self.Heartbeat_Interval :=
              Duration (Event.Hello_Data.heartbeat_interval) / 1000;

            Self.Is_Acknowledged := True;
            Self.Next_Heartbeat := Ada.Real_Time.Clock
              + Ada.Real_Time.To_Time_Span (Self.Heartbeat_Interval);

         when Web_Sockets.Timed_Out =>
            Self.Raise_Gateway_Error ("Hello timed out");

         when Web_Sockets.Closed =>
            Self.Raise_Gateway_Error ("Connection closed before Hello");
      end case;
   end Open;

   -------------
   -- Process --
   -------------

   procedure Process
     (Self     : in out Client;
      Listener : in out Discord.Gateway.Listener'Class;
      Text     : String)
   is
      Event   : Payloads.Event;
      Success : Boolean;
   begin
      Payloads.Decode (Text, Event, Success);

      if not Success then
         raise Gateway_Error with "Unable to decode payload: " & Text;
      end if;

      if Event.Sequence.Is_Set then
         Self.Sequence := Event.Sequence;
      end if;

      case Event.Kind is
         when Payloads.Hello =>
            Self.Heartbeat_Interval :=
              Duration (Event.Hello_Data.heartbeat_interval) / 1000;

         when Payloads.Heartbeat_Request =>
            Self.Send_Heartbeat;

         when Payloads.Heartbeat_Acknowledge =>
            Self.Is_Acknowledged := True;

         when Payloads.Reconnect =>
            Self.Reconnect (Try_Resume => True);

         when Payloads.Invalid_Session =>
            --  Discord asks to wait a random time between 1 and 5 seconds
            delay 2.0;
            Self.Reconnect (Try_Resume => Event.Is_Resumable);

         when Payloads.Ready =>
            Self.Session_Id := Event.Ready_Data.session_id;
            Self.Resume_URL := Event.Ready_Data.resume_gateway_url;
            Listener.On_Ready (Event.Ready_Data);

         when Payloads.Message_Create =>
            Listener.On_Message_Create (Event.Message);

         when Payloads.Other_Dispatch =>
            Listener.On_Other_Event (Event.Event_Name);

         when Payloads.Unknown =>
            --  Ignore opcodes that are not expected to be received
            null;
      end case;
   end Process;

   -------------------
   -- Process_Close --
   -------------------

   procedure Process_Close (Self : in out Client) is
   begin
      case Self.Web_Socket.Close_Code is
         when 4004 | 4010 .. 4014 =>
            --  Authentication failed, invalid shard/version/intents
            Self.Raise_Gateway_Error ("Connection closed");

         when 1000 | 1001 | 4007 | 4009 =>
            --  The session is invalid, start a new one
            Self.Reconnect (Try_Resume => False);

         when others =>
            Self.Reconnect (Try_Resume => True);
      end case;
   end Process_Close;

   -------------------------
   -- Raise_Gateway_Error --
   -------------------------

   procedure Raise_Gateway_Error (Self : Client; Message : String) is
      Code : constant Natural := Self.Web_Socket.Close_Code;
   begin
      if Code = 0 then
         raise Gateway_Error with Message;
      else
         raise Gateway_Error with
           Message & ", code" & Code'Image & ": "
           & Self.Web_Socket.Close_Reason;
      end if;
   end Raise_Gateway_Error;

   ---------------
   -- Reconnect --
   ---------------

   procedure Reconnect (Self : in out Client; Try_Resume : Boolean) is
      --  A close code other than 1000/1001 keeps the session resumable
      Close_Code : constant Positive := (if Try_Resume then 4000 else 1000);
   begin
      Self.Web_Socket.Close (Close_Code);

      if Try_Resume
        and then not Self.Session_Id.Is_Empty
        and then not Self.Resume_URL.Is_Empty
      then
         Self.Open (To_UTF_8 (Self.Resume_URL) & URL_Parameters);
         Self.Resume;
      else
         Self.Sequence := (Is_Set => False);
         Self.Session_Id.Clear;
         Self.Resume_URL.Clear;
         Self.Open (Ada.Strings.Unbounded.To_String (Self.URL));
         Self.Identify;
      end if;
   end Reconnect;

   ------------
   -- Resume --
   ------------

   procedure Resume (Self : in out Client) is
      Data : constant Discord.Schema.GatewayResumeData :=
        (token      => Self.Token,
         session_id => Self.Session_Id,
         seq        => (if Self.Sequence.Is_Set then Self.Sequence.Value
                        else 0));
   begin
      Self.Web_Socket.Send_Text (Payloads.Encode_Resume (Data));
   end Resume;

   ---------
   -- Run --
   ---------

   procedure Run
     (Self     : in out Client;
      Listener : in out Discord.Gateway.Listener'Class)
   is
      Text   : Ada.Strings.Unbounded.Unbounded_String;
      Status : Web_Sockets.Receive_Status;
      Now    : Ada.Real_Time.Time;
   begin
      while not Self.Stop_Requested loop
         Now := Ada.Real_Time.Clock;

         if Now < Self.Next_Heartbeat then
            Self.Web_Socket.Receive
              (Text,
               Ada.Real_Time.To_Duration (Self.Next_Heartbeat - Now),
               Status);

            case Status is
               when Web_Sockets.Received =>
                  Self.Process
                    (Listener, Ada.Strings.Unbounded.To_String (Text));

               when Web_Sockets.Timed_Out =>
                  --  Time to send a heartbeat, see the next iteration
                  null;

               when Web_Sockets.Closed =>
                  if not Self.Stop_Requested then
                     Self.Process_Close;
                  end if;
            end case;

         elsif Self.Is_Acknowledged then
            Self.Send_Heartbeat;

         else
            --  No acknowledge for the last heartbeat, the connection is dead
            Self.Reconnect (Try_Resume => True);
         end if;
      end loop;

      Self.Web_Socket.Close;
   end Run;

   --------------------
   -- Send_Heartbeat --
   --------------------

   procedure Send_Heartbeat (Self : in out Client) is
   begin
      Self.Web_Socket.Send_Text (Payloads.Encode_Heartbeat (Self.Sequence));
      Self.Is_Acknowledged := False;
      Self.Next_Heartbeat := Ada.Real_Time.Clock
        + Ada.Real_Time.To_Time_Span (Self.Heartbeat_Interval);
   end Send_Heartbeat;

   ----------
   -- Stop --
   ----------

   procedure Stop (Self : in out Client) is
   begin
      Self.Stop_Requested := True;
   end Stop;

   ------------------
   -- To_Bit_Field --
   ------------------

   function To_Bit_Field
     (Intents : Intent_Set) return Discord.Schema.Integer_64
   is
      Result : Discord.Schema.Integer_64 := 0;
   begin
      for Item in Intent loop
         if Intents (Item) then
            Result := Result + 2 ** Intent'Enum_Rep (Item);
         end if;
      end loop;

      return Result;
   end To_Bit_Field;

end Discord.Gateway;
