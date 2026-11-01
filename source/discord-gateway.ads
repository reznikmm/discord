--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  Discord Gateway client: receive events over a web socket connection.

with Ada.Strings.Unbounded;

with VSS.Strings;

with Discord.Schema;

private with Ada.Real_Time;
private with Discord.Implementation.Web_Sockets;

package Discord.Gateway is

   type Intent is
     (Guilds,
      Guild_Members,
      Guild_Moderation,
      Guild_Expressions,
      Guild_Integrations,
      Guild_Webhooks,
      Guild_Invites,
      Guild_Voice_States,
      Guild_Presences,
      Guild_Messages,
      Guild_Message_Reactions,
      Guild_Message_Typing,
      Direct_Messages,
      Direct_Message_Reactions,
      Direct_Message_Typing,
      Message_Content,
      Guild_Scheduled_Events,
      Auto_Moderation_Configuration,
      Auto_Moderation_Execution,
      Guild_Message_Polls,
      Direct_Message_Polls);
   --  Groups of events to receive. Guild_Members, Guild_Presences and
   --  Message_Content are privileged: enable them in the Developer Portal.

   for Intent use
     (Guilds                        => 0,
      Guild_Members                 => 1,
      Guild_Moderation              => 2,
      Guild_Expressions             => 3,
      Guild_Integrations            => 4,
      Guild_Webhooks                => 5,
      Guild_Invites                 => 6,
      Guild_Voice_States            => 7,
      Guild_Presences               => 8,
      Guild_Messages                => 9,
      Guild_Message_Reactions       => 10,
      Guild_Message_Typing          => 11,
      Direct_Messages               => 12,
      Direct_Message_Reactions      => 13,
      Direct_Message_Typing         => 14,
      Message_Content               => 15,
      Guild_Scheduled_Events        => 16,
      Auto_Moderation_Configuration => 20,
      Auto_Moderation_Execution     => 21,
      Guild_Message_Polls           => 24,
      Direct_Message_Polls          => 25);
   --  The representation is a bit number in the intents bit field

   type Intent_Set is array (Intent) of Boolean;

   function To_Bit_Field
     (Intents : Intent_Set) return Discord.Schema.Integer_64;
   --  Convert Intents to a value of `intents` field in Identify payload

   Default_URL : constant String :=
     "wss://gateway.discord.gg/?v=10&encoding=json";

   type Listener is limited interface;
   --  Receiver of gateway events. Override required subprograms.

   procedure On_Ready
     (Self : in out Listener;
      Data : Discord.Schema.GatewayReadyDispatchData) is null;
   --  Called once the connection is established

   procedure On_Message_Create
     (Self    : in out Listener;
      Message : Discord.Schema.GatewayMessageCreateDispatchData) is null;
   --  Called when a new message is posted. Message content is empty unless
   --  Message_Content intent is enabled or the message mentions the bot.

   procedure On_Other_Event
     (Self : in out Listener;
      Name : VSS.Strings.Virtual_String) is null;
   --  Called for any other dispatch event, such as RESUMED or GUILD_CREATE

   type Client is tagged limited private;

   Gateway_Error : exception;

   procedure Connect
     (Self    : in out Client;
      Token   : VSS.Strings.Virtual_String;
      Intents : Intent_Set;
      URL     : String := Default_URL);
   --  Connect to the gateway, wait for Hello and send Identify. Raise
   --  Gateway_Error on failure.

   procedure Run
     (Self     : in out Client;
      Listener : in out Discord.Gateway.Listener'Class);
   --  Receive events and call Listener, send heartbeats, reconnect when
   --  needed until Stop is called. Raise Gateway_Error if the server closes
   --  the connection with a fatal code (bad token, disallowed intents, etc).

   procedure Stop (Self : in out Client);
   --  Ask Run to close the connection and return. Could be called from
   --  Listener callbacks. Note, that when called from another task, it
   --  takes effect after the next event or heartbeat.

private

   type Client is tagged limited record
      Web_Socket         : Discord.Implementation.Web_Sockets.Web_Socket;
      URL                : Ada.Strings.Unbounded.Unbounded_String;
      Token              : VSS.Strings.Virtual_String;
      Intents            : Intent_Set := [others => False];
      Heartbeat_Interval : Duration := 0.0;
      Next_Heartbeat     : Ada.Real_Time.Time;
      Is_Acknowledged    : Boolean := True;
      --  The last heartbeat was acknowledged by the server
      Sequence           : Discord.Schema.Optional_Integer_64;
      --  The last sequence number received
      Session_Id         : VSS.Strings.Virtual_String;
      Resume_URL         : VSS.Strings.Virtual_String;
      Stop_Requested     : Boolean := False with Atomic;
   end record;

end Discord.Gateway;
