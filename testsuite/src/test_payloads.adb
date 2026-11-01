--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

with Interfaces;

with VSS.Strings;

with Discord.Gateway.Payloads;
with Discord.Schema;

package body Test_Payloads is

   use Discord.Gateway.Payloads;
   use type Interfaces.Integer_64;
   use type VSS.Strings.Virtual_String;

   --  Payloads based on examples from the Discord documentation

   Hello_Text : constant String :=
     "{""op"":10,""d"":{""heartbeat_interval"":45000},""s"":null,""t"":null}";

   Ready_Text : constant String :=
     "{""t"":""READY"",""s"":1,""op"":0,""d"":{""v"":10,"
     & """user_settings"":{},""user"":{""verified"":true,"
     & """username"":""ada-bot"",""mfa_enabled"":false,"
     & """id"":""1234567890"",""global_name"":null,""flags"":0,"
     & """email"":null,""discriminator"":""0000"",""bot"":true,"
     & """avatar"":null},""session_type"":""normal"","
     & """session_id"":""abcdef"","
     & """resume_gateway_url"":""wss://gateway-us-east1-b.discord.gg"","
     & """relationships"":[],""private_channels"":[],""presences"":[],"
     & """guilds"":[{""unavailable"":true,""id"":""42""}],"
     & """guild_join_requests"":[],""geo_ordered_rtc_regions"":[],"
     & """application"":{""id"":""1234567890"",""flags"":565248},"
     & """_trace"":[""[\""gateway-prd\"",{}]""]}}";

   Message_Text : constant String :=
     "{""t"":""MESSAGE_CREATE"",""s"":3,""op"":0,""d"":{""type"":0,"
     & """tts"":false,""timestamp"":""2026-10-22T10:00:00.000000+00:00"","
     & """pinned"":false,""nonce"":""1300000000000000000"","
     & """mentions"":[],""mention_roles"":[],""mention_everyone"":false,"
     & """member"":{""roles"":[],""mute"":false,""deaf"":false},"
     & """id"":""1300000000000000001"",""flags"":0,""embeds"":[],"
     & """edited_timestamp"":null,"
     & """content"":""\u041f\u0440\u0438\u0432\u0456\u0442, Ada!"","
     & """components"":[],""channel_id"":""777"","
     & """author"":{""username"":""max"",""id"":""555"","
     & """global_name"":""Max"",""discriminator"":""0"","
     & """avatar"":null},""attachments"":[],""guild_id"":""42""}}";

   Data_First_Text : constant String :=
     "{""d"":{""heartbeat_interval"":41250},""op"":10}";

   Other_Text : constant String :=
     "{""t"":""TYPING_START"",""s"":5,""op"":0,""d"":{""user_id"":""1""}}";

   -----------------------
   -- Test_Decode_Hello --
   -----------------------

   procedure Test_Decode_Hello (Op : in out Trendy_Test.Operation'Class) is
      Value   : Event;
      Success : Boolean;
   begin
      Op.Register;
      Decode (Hello_Text, Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Hello);
      Op.Assert (not Value.Sequence.Is_Set);
      Op.Assert (Value.Hello_Data.heartbeat_interval = 45_000);
   end Test_Decode_Hello;

   ----------------------------
   -- Test_Decode_Data_First --
   ----------------------------

   procedure Test_Decode_Data_First
     (Op : in out Trendy_Test.Operation'Class)
   is
      Value   : Event;
      Success : Boolean;
   begin
      Op.Register;
      Decode (Data_First_Text, Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Hello);
      Op.Assert (Value.Hello_Data.heartbeat_interval = 41_250);
   end Test_Decode_Data_First;

   --------------------------------
   -- Test_Decode_Message_Create --
   --------------------------------

   procedure Test_Decode_Message_Create
     (Op : in out Trendy_Test.Operation'Class)
   is
      Value   : Event;
      Success : Boolean;
   begin
      Op.Register;
      Decode (Message_Text, Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Message_Create);
      Op.Assert (Value.Sequence.Is_Set and then Value.Sequence.Value = 3);
      Op.Assert (Value.Message.content = "Привіт, Ada!");
      Op.Assert (Value.Message.channel_id = "777");
      Op.Assert (Value.Message.guild_id = "42");
      Op.Assert (Value.Message.author.username = "max");
      Op.Assert (not Value.Message.author.bot);
      Op.Assert (Value.Message.edited_timestamp.Is_Null);
   end Test_Decode_Message_Create;

   -----------------------
   -- Test_Decode_Other --
   -----------------------

   procedure Test_Decode_Other (Op : in out Trendy_Test.Operation'Class) is
      Value   : Event;
      Success : Boolean;
   begin
      Op.Register;
      Decode (Other_Text, Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Other_Dispatch);
      Op.Assert (Value.Event_Name = "TYPING_START");

      Decode ("{""op"":11}", Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Heartbeat_Acknowledge);

      Decode ("{""op"":9,""d"":true}", Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Invalid_Session);
      Op.Assert (Value.Is_Resumable);

      Decode ("{""op"" 10}", Value, Success);
      Op.Assert (not Success);
   end Test_Decode_Other;

   -----------------------
   -- Test_Decode_Ready --
   -----------------------

   procedure Test_Decode_Ready (Op : in out Trendy_Test.Operation'Class) is
      Value   : Event;
      Success : Boolean;
   begin
      Op.Register;
      Decode (Ready_Text, Value, Success);
      Op.Assert (Success);
      Op.Assert (Value.Kind = Ready);
      Op.Assert (Value.Ready_Data.v = 10);
      Op.Assert (Value.Ready_Data.session_id = "abcdef");
      Op.Assert (Value.Ready_Data.user.username = "ada-bot");
      Op.Assert (Value.Ready_Data.user.bot);
      Op.Assert (Value.Ready_Data.guilds.Length = 1);
      Op.Assert
        (Value.Ready_Data.resume_gateway_url =
           "wss://gateway-us-east1-b.discord.gg");
   end Test_Decode_Ready;

   ---------------------------
   -- Test_Encode_Heartbeat --
   ---------------------------

   procedure Test_Encode_Heartbeat
     (Op : in out Trendy_Test.Operation'Class) is
   begin
      Op.Register;
      Op.Assert
        (Encode_Heartbeat ((Is_Set => False)) = "{""op"":1,""d"":null}");
      Op.Assert
        (Encode_Heartbeat ((Is_Set => True, Value => 251))
         = "{""op"":1,""d"":251}");
   end Test_Encode_Heartbeat;

   --------------------------
   -- Test_Encode_Identify --
   --------------------------

   procedure Test_Encode_Identify
     (Op : in out Trendy_Test.Operation'Class)
   is
      Text : constant String := Encode_Identify
        ((token      => "secret",
          properties => (os => "linux", browser => "ada", device => "ada"),
          intents    => 33281,
          others     => <>));
   begin
      Op.Register;
      Op.Assert
        (Text = "{""op"":2,""d"":{""token"":""secret"",""properties"":"
         & "{""browser"":""ada"",""device"":""ada"",""os"":""linux""},"
         & """intents"":33281}}");
   end Test_Encode_Identify;

   ------------------
   -- Test_Intents --
   ------------------

   procedure Test_Intents (Op : in out Trendy_Test.Operation'Class) is
      use Discord.Gateway;
   begin
      Op.Register;
      Op.Assert
        (To_Bit_Field
           ([Guilds | Guild_Messages | Message_Content => True,
             others => False]) = 33_281);
      Op.Assert
        (To_Bit_Field ([Direct_Message_Polls => True, others => False])
         = 2 ** 25);
   end Test_Intents;

end Test_Payloads;
