--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Ada.Exceptions;
with Ada.Strings.Unbounded;

with VSS.JSON.Content_Handlers;
with VSS.JSON.Pull_Readers;
with VSS.Strings.Conversions;

with Discord.Implementation.HTTP;
with Discord.Implementation.JSON_Texts;
with Discord.Schema.Inputs;
with Discord.Schema.Outputs;

package body Discord.REST is

   package HTTP renames Discord.Implementation.HTTP;

   User_Agent : constant String :=
     "DiscordBot (https://github.com/reznikmm/discord, 0.1.0)";

   function To_UTF_8 (Text : VSS.Strings.Virtual_String) return String is
     (VSS.Strings.Conversions.To_UTF_8_String (Text));

   generic
      type Request_Type (<>) is limited private;
      type Response_Type is limited private;

      with procedure Output
        (Handler : in out VSS.JSON.Content_Handlers.JSON_Content_Handler'Class;
         Value   : Request_Type);

      with procedure Input
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Value   : out Response_Type;
         Success : in out Boolean);
   procedure Generic_Request
     (Self    : in out Client;
      Method  : HTTP.Method_Kind;
      Path    : String;
      Request : Request_Type;
      Result  : out Response_Type);
   --  Send a request with JSON body and parse JSON response

   generic
      type Response_Type is limited private;

      with procedure Input
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Value   : out Response_Type;
         Success : in out Boolean);
   procedure Generic_Get
     (Self   : in out Client;
      Path   : String;
      Result : out Response_Type);
   --  Send a GET request and parse JSON response

   procedure Send
     (Self          : in out Client;
      Method        : HTTP.Method_Kind;
      Path          : String;
      Request_Body  : String;
      Response_Body : out Ada.Strings.Unbounded.Unbounded_String);
   --  Send a request, raise REST_Error on failure

   -----------------------
   -- Create_DM_Channel --
   -----------------------

   procedure Create_DM_Channel
     (Self         : in out Client;
      Recipient_Id : Discord.Snowflake;
      Result       : out Discord.Schema.APIChannel)
   is
      procedure Request is new Generic_Request
        (Request_Type  =>
           Discord.Schema.RESTPostAPICurrentUserCreateDMChannelJSONBody,
         Response_Type => Discord.Schema.APIChannel,
         Output        => Discord.Schema.Outputs
           .Output_RESTPostAPICurrentUserCreateDMChannelJSONBody,
         Input         => Discord.Schema.Inputs.Input_APIChannel);
   begin
      Request
        (Self, HTTP.Post, "/users/@me/channels",
         (recipient_id => Recipient_Id),
         Result);
   end Create_DM_Channel;

   --------------------
   -- Create_Message --
   --------------------

   procedure Create_Message
     (Self       : in out Client;
      Channel_Id : Discord.Snowflake;
      Message    : Discord.Schema.RESTPostAPIChannelMessageJSONBody;
      Result     : out Discord.Schema.APIMessage)
   is
      procedure Request is new Generic_Request
        (Request_Type  => Discord.Schema.RESTPostAPIChannelMessageJSONBody,
         Response_Type => Discord.Schema.APIMessage,
         Output        => Discord.Schema.Outputs
           .Output_RESTPostAPIChannelMessageJSONBody,
         Input         => Discord.Schema.Inputs.Input_APIMessage);
   begin
      Request
        (Self, HTTP.Post, "/channels/" & To_UTF_8 (Channel_Id) & "/messages",
         Message,
         Result);
   end Create_Message;

   --------------------
   -- Create_Message --
   --------------------

   procedure Create_Message
     (Self       : in out Client;
      Channel_Id : Discord.Snowflake;
      Content    : VSS.Strings.Virtual_String;
      Result     : out Discord.Schema.APIMessage) is
   begin
      Self.Create_Message
        (Channel_Id => Channel_Id,
         Message    => (content => Content, others => <>),
         Result     => Result);
   end Create_Message;

   -----------------
   -- Generic_Get --
   -----------------

   procedure Generic_Get
     (Self   : in out Client;
      Path   : String;
      Result : out Response_Type)
   is
      procedure Parse is new Discord.Implementation.JSON_Texts
        .Parse_JSON_Text (Response_Type, Input);

      Response_Body : Ada.Strings.Unbounded.Unbounded_String;
      Success       : Boolean;
   begin
      Self.Send (HTTP.Get, Path, "", Response_Body);
      Parse (Ada.Strings.Unbounded.To_String (Response_Body), Result, Success);

      if not Success then
         raise REST_Error with
           "GET " & Path & ": unexpected response: "
           & Ada.Strings.Unbounded.To_String (Response_Body);
      end if;
   end Generic_Get;

   ---------------------
   -- Generic_Request --
   ---------------------

   procedure Generic_Request
     (Self    : in out Client;
      Method  : HTTP.Method_Kind;
      Path    : String;
      Request : Request_Type;
      Result  : out Response_Type)
   is
      procedure Write
        (Handler : in out
           VSS.JSON.Content_Handlers.JSON_Content_Handler'Class);

      -----------
      -- Write --
      -----------

      procedure Write
        (Handler : in out
           VSS.JSON.Content_Handlers.JSON_Content_Handler'Class) is
      begin
         Output (Handler, Request);
      end Write;

      function To_Text is new Discord.Implementation.JSON_Texts
        .To_JSON_Text (Write);

      procedure Parse is new Discord.Implementation.JSON_Texts
        .Parse_JSON_Text (Response_Type, Input);

      Response_Body : Ada.Strings.Unbounded.Unbounded_String;
      Success       : Boolean;
   begin
      Self.Send (Method, Path, To_Text, Response_Body);
      Parse (Ada.Strings.Unbounded.To_String (Response_Body), Result, Success);

      if not Success then
         raise REST_Error with
           Method'Image & " " & Path & ": unexpected response: "
           & Ada.Strings.Unbounded.To_String (Response_Body);
      end if;
   end Generic_Request;

   -----------------
   -- Get_Channel --
   -----------------

   procedure Get_Channel
     (Self       : in out Client;
      Channel_Id : Discord.Snowflake;
      Result     : out Discord.Schema.APIChannel)
   is
      procedure Get is new Generic_Get
        (Response_Type => Discord.Schema.APIChannel,
         Input         => Discord.Schema.Inputs.Input_APIChannel);
   begin
      Get (Self, "/channels/" & To_UTF_8 (Channel_Id), Result);
   end Get_Channel;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Self    : in out Client;
      Token   : VSS.Strings.Virtual_String;
      API_URL : String := Default_API_URL)
   is
      use type VSS.Strings.Virtual_String;
   begin
      Self.API_URL := VSS.Strings.Conversions.To_Virtual_String (API_URL);
      Self.Authorization := "Bot " & Token;
   end Initialize;

   -----------
   -- Reply --
   -----------

   procedure Reply
     (Self    : in out Client;
      Message : Discord.Schema.GatewayMessageCreateDispatchData;
      Content : VSS.Strings.Virtual_String;
      Result  : out Discord.Schema.APIMessage) is
   begin
      Self.Create_Message
        (Channel_Id => Message.channel_id,
         Message    =>
           (content           => Content,
            message_reference =>
              (Is_Set => True,
               Value  =>
                 (message_id => Message.id,
                  channel_id => Message.channel_id,
                  guild_id   => Message.guild_id,
                  others     => <>)),
            others            => <>),
         Result     => Result);
   end Reply;

   ----------
   -- Send --
   ----------

   procedure Send
     (Self          : in out Client;
      Method        : HTTP.Method_Kind;
      Path          : String;
      Request_Body  : String;
      Response_Body : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Status : Natural;
   begin
      if Self.Authorization.Is_Empty then
         raise REST_Error with "Client is not initialized";
      end if;

      HTTP.Send
        (Method        => Method,
         URL           => To_UTF_8 (Self.API_URL) & Path,
         Authorization => To_UTF_8 (Self.Authorization),
         User_Agent    => User_Agent,
         Request_Body  => Request_Body,
         Status        => Status,
         Response_Body => Response_Body);

      if Status not in 200 .. 299 then
         raise REST_Error with
           Method'Image & " " & Path & ":" & Status'Image & " "
           & Ada.Strings.Unbounded.To_String (Response_Body);
      end if;
   exception
      when Error : HTTP.Connection_Error =>
         raise REST_Error with Ada.Exceptions.Exception_Message (Error);
   end Send;

end Discord.REST;
