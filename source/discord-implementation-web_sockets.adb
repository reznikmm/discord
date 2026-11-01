--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Ada.Exceptions;
with Ada.Unchecked_Deallocation;

with AHT.Bytes;
with AHT.Transport;
with AHT.Websocket.Client;

package body Discord.Implementation.Web_Sockets is

   Network_Timeout : constant Duration := 30.0;

   type Connection is limited record
      Client    : AHT.Websocket.Client.Client_Type;
      Abandoned : Boolean := False;
      --  Close didn't complete, so the client could be still in use by its
      --  receiver task and can't be deallocated.
   end record;

   procedure Free is new Ada.Unchecked_Deallocation
     (Connection, Connection_Access);

   procedure On_Close
     (Information : AHT.Websocket.Close_Info;
      Reason      : String);
   --  AHT callback to catch the close code sent by the server

   protected Last_Close is
      --  AHT callbacks have no client parameter, so the last close code is
      --  shared by all connections. Good enough for a single gateway
      --  connection per process.

      procedure Clear;

      procedure Set (Code : Natural; Reason : String);

      function Code return Natural;

      function Reason return String;
   private
      Close_Code   : Natural := 0;
      Close_Reason : Ada.Strings.Unbounded.Unbounded_String;
   end Last_Close;

   -----------
   -- Close --
   -----------

   procedure Close (Self : in out Web_Socket; Code : Positive := 1000) is
   begin
      if Self.Connection /= null then
         if Self.Connection.Client.Is_Open then
            begin
               Self.Connection.Client.Close (Code);
            exception
               when AHT.Transport.Timeout_Error =>
                  Self.Connection.Abandoned := True;
            end;
         end if;

         if Self.Connection.Abandoned then
            --  Leave it to the receiver task, don't deallocate
            Self.Connection := null;
         else
            Free (Self.Connection);
         end if;
      end if;
   end Close;

   ----------------
   -- Close_Code --
   ----------------

   function Close_Code (Self : Web_Socket) return Natural is
     (Last_Close.Code);

   ------------------
   -- Close_Reason --
   ------------------

   function Close_Reason (Self : Web_Socket) return String is
     (Last_Close.Reason);

   -------------
   -- Connect --
   -------------

   procedure Connect (Self : in out Web_Socket; URL : String) is
   begin
      Self.Close;
      Self.Connection := new Connection;
      Last_Close.Clear;

      Self.Connection.Client.Configure
        ((Delivery => AHT.Websocket.Client.Pull_Only, others => <>));

      Self.Connection.Client.Set_On_Close (On_Close'Access);

      Self.Connection.Client.Connect
        (URL                => URL,
         Connect_Timeout    => Network_Timeout,
         Handshake_Deadline => Network_Timeout,
         Upgrade_Deadline   => Network_Timeout,
         Resolve_Timeout    => Network_Timeout);
   exception
      when Error : others =>
         raise Connection_Error
           with URL & ": " & Ada.Exceptions.Exception_Information (Error);
   end Connect;

   --------------
   -- Finalize --
   --------------

   overriding procedure Finalize (Self : in out Web_Socket) is
   begin
      Self.Close;
   end Finalize;

   ----------------
   -- Last_Close --
   ----------------

   protected body Last_Close is

      procedure Clear is
      begin
         Close_Code := 0;
         Close_Reason := Ada.Strings.Unbounded.Null_Unbounded_String;
      end Clear;

      function Code return Natural is (Close_Code);

      function Reason return String is
        (Ada.Strings.Unbounded.To_String (Close_Reason));

      procedure Set (Code : Natural; Reason : String) is
      begin
         Close_Code := Code;
         Close_Reason := Ada.Strings.Unbounded.To_Unbounded_String (Reason);
      end Set;

   end Last_Close;

   --------------
   -- On_Close --
   --------------

   procedure On_Close
     (Information : AHT.Websocket.Close_Info;
      Reason      : String) is
   begin
      if Information.Has_Code then
         Last_Close.Set (Information.Code, Reason);
      end if;
   end On_Close;

   -------------
   -- Receive --
   -------------

   procedure Receive
     (Self    : in out Web_Socket;
      Text    : out Ada.Strings.Unbounded.Unbounded_String;
      Timeout : Duration;
      Status  : out Receive_Status)
   is
      Message : AHT.Websocket.Client.Message_Type;
   begin
      Text := Ada.Strings.Unbounded.Null_Unbounded_String;

      if Self.Connection = null then
         Status := Closed;
         return;
      end if;

      Self.Connection.Client.Receive (Message, Timeout);
      Text := Ada.Strings.Unbounded.To_Unbounded_String
        (AHT.Bytes.To_String (Message.Payload));
      Status := Received;
   exception
      when AHT.Transport.Timeout_Error =>
         Status := Timed_Out;
      when AHT.Websocket.Closed_Error =>
         Status := Closed;
   end Receive;

   ---------------
   -- Send_Text --
   ---------------

   procedure Send_Text (Self : in out Web_Socket; Text : String) is
   begin
      if Self.Connection = null then
         raise Connection_Error with "Web socket is not connected";
      end if;

      Self.Connection.Client.Send_Text (Text);
   end Send_Text;

end Discord.Implementation.Web_Sockets;
