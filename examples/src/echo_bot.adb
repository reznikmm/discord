--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

with Ada.Environment_Variables;
with Ada.Text_IO;

with VSS.Strings.Character_Iterators;
with VSS.Strings.Conversions;

with Discord.Gateway;
with Discord.REST;
with Discord.Schema;

procedure Echo_Bot is

   use type VSS.Strings.Virtual_String;

   function Image (Text : VSS.Strings.Virtual_String) return String is
     (VSS.Strings.Conversions.To_UTF_8_String (Text));

   Echo_Prefix : constant VSS.Strings.Virtual_String := "!echo ";

   function Without_Prefix
     (Text   : VSS.Strings.Virtual_String;
      Prefix : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String;
   --  Return Text without the leading Prefix

   type Bot_Listener is limited new Discord.Gateway.Listener with record
      REST : Discord.REST.Client;
   end record;

   overriding procedure On_Ready
     (Self : in out Bot_Listener;
      Data : Discord.Schema.GatewayReadyDispatchData);

   overriding procedure On_Message_Create
     (Self    : in out Bot_Listener;
      Message : Discord.Schema.GatewayMessageCreateDispatchData);

   -----------------------
   -- On_Message_Create --
   -----------------------

   overriding procedure On_Message_Create
     (Self    : in out Bot_Listener;
      Message : Discord.Schema.GatewayMessageCreateDispatchData)
   is
      Content : constant VSS.Strings.Virtual_String := Message.content;
      Result  : Discord.Schema.APIMessage;
   begin
      if Message.author.bot then
         return;  --  Ignore bots, including ourself
      end if;

      Ada.Text_IO.Put_Line
        (Image (Message.author.username) & ": " & Image (Content));

      if Content = "!ping" then
         Self.REST.Reply (Message, "pong", Result);
      elsif Content.Starts_With (Echo_Prefix) then
         Self.REST.Create_Message
           (Channel_Id => Message.channel_id,
            Content    => Without_Prefix (Content, Echo_Prefix),
            Result     => Result);
      end if;
   end On_Message_Create;

   --------------
   -- On_Ready --
   --------------

   overriding procedure On_Ready
     (Self : in out Bot_Listener;
      Data : Discord.Schema.GatewayReadyDispatchData) is
   begin
      Ada.Text_IO.Put_Line ("Logged in as " & Image (Data.user.username));
   end On_Ready;

   --------------------
   -- Without_Prefix --
   --------------------

   function Without_Prefix
     (Text   : VSS.Strings.Virtual_String;
      Prefix : VSS.Strings.Virtual_String) return VSS.Strings.Virtual_String
   is
      Position : VSS.Strings.Character_Iterators.Character_Iterator :=
        Text.At_First_Character;
   begin
      for Index in 2 .. Prefix.Character_Length loop
         exit when not Position.Forward;
      end loop;

      return Text.Tail_After (Position);
   end Without_Prefix;

   Token : constant VSS.Strings.Virtual_String :=
     VSS.Strings.Conversions.To_Virtual_String
       (Ada.Environment_Variables.Value ("DISCORD_TOKEN", ""));

   Listener : Bot_Listener;
   Gateway  : Discord.Gateway.Client;
begin
   if Token.Is_Empty then
      Ada.Text_IO.Put_Line ("Set DISCORD_TOKEN environment variable");
      return;
   end if;

   Listener.REST.Initialize (Token);

   Gateway.Connect
     (Token   => Token,
      Intents =>
        [Discord.Gateway.Guild_Messages
         | Discord.Gateway.Direct_Messages
         | Discord.Gateway.Message_Content => True,
         others => False]);

   Gateway.Run (Listener);
end Echo_Bot;
