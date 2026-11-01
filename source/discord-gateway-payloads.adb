--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with VSS.JSON.Content_Handlers;
with VSS.JSON.Pull_Readers.Buffered;

with Discord.Implementation.JSON_Texts;
with Discord.Schema.Inputs;
with Discord.Schema.Outputs;

package body Discord.Gateway.Payloads is

   use type Discord.Schema.Integer_64;
   use type VSS.JSON.JSON_Number_Kind;
   use type VSS.Strings.Virtual_String;

   Dispatch_Opcode              : constant := 0;
   Heartbeat_Opcode             : constant := 1;
   Identify_Opcode              : constant := 2;
   Resume_Opcode                : constant := 6;
   Reconnect_Opcode             : constant := 7;
   Invalid_Session_Opcode       : constant := 9;
   Hello_Opcode                 : constant := 10;
   Heartbeat_Acknowledge_Opcode : constant := 11;

   procedure Read_Integer
     (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
      Value   : out Discord.Schema.Optional_Integer_64;
      Success : in out Boolean);
   --  Read an integer or null value

   procedure Read_String
     (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
      Value   : out VSS.Strings.Virtual_String;
      Success : in out Boolean);
   --  Read a string or null value

   ------------
   -- Decode --
   ------------

   procedure Decode
     (Text    : String;
      Value   : out Event;
      Success : out Boolean)
   is
      procedure Process
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Success : in out Boolean);

      procedure Read_Data
        (Reader   : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Opcode   : Discord.Schema.Integer_64;
         Name     : VSS.Strings.Virtual_String;
         Sequence : Discord.Schema.Optional_Integer_64;
         Success  : in out Boolean);
      --  Read the `d` value of the payload according to Opcode and event
      --  Name and assign Value.

      -------------
      -- Process --
      -------------

      procedure Process
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Success : in out Boolean)
      is
         Buffered : VSS.JSON.Pull_Readers.Buffered.JSON_Buffered_Pull_Reader
           (Reader'Unchecked_Access);

         Opcode   : Discord.Schema.Optional_Integer_64;
         Name     : VSS.Strings.Virtual_String;
         Sequence : Discord.Schema.Optional_Integer_64;
         Has_Data : Boolean := False;
      begin
         if not Buffered.Is_Start_Object then
            Success := False;
            return;
         end if;

         --  The order of keys is not defined, so find `op`, `t` and `s`
         --  first, then return to the beginning of the object and read `d`.

         Buffered.Mark;
         Buffered.Read_Next;

         while Success and then Buffered.Is_Key_Name loop
            declare
               Key : constant VSS.Strings.Virtual_String :=
                 Buffered.Key_Name;
            begin
               Buffered.Read_Next;

               if Key = "op" then
                  Read_Integer (Buffered, Opcode, Success);
               elsif Key = "s" then
                  Read_Integer (Buffered, Sequence, Success);
               elsif Key = "t" then
                  Read_String (Buffered, Name, Success);
               else
                  Has_Data := Has_Data or Key = "d";
                  Buffered.Skip_Current_Value;
               end if;
            end;
         end loop;

         if not Success or else not Opcode.Is_Set then
            Success := False;
            return;
         end if;

         if not Has_Data then
            Read_Data (Buffered, Opcode.Value, Name, Sequence, Success);
            return;
         end if;

         Buffered.Reset;
         Buffered.Read_Next;  --  Skip Start_Object

         while Buffered.Key_Name /= "d" loop
            Buffered.Read_Next;
            Buffered.Skip_Current_Value;
         end loop;

         Buffered.Read_Next;  --  Skip `d` key
         Read_Data (Buffered, Opcode.Value, Name, Sequence, Success);
      end Process;

      ---------------
      -- Read_Data --
      ---------------

      procedure Read_Data
        (Reader   : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Opcode   : Discord.Schema.Integer_64;
         Name     : VSS.Strings.Virtual_String;
         Sequence : Discord.Schema.Optional_Integer_64;
         Success  : in out Boolean) is
      begin
         case Opcode is
            when Dispatch_Opcode =>
               if Name = "READY" then
                  declare
                     Data : Discord.Schema.GatewayReadyDispatchData;
                  begin
                     Discord.Schema.Inputs.Input_GatewayReadyDispatchData
                       (Reader, Data, Success);

                     Value :=
                       (Kind       => Ready,
                        Sequence   => Sequence,
                        Ready_Data => Data);
                  end;

               elsif Name = "MESSAGE_CREATE" then
                  declare
                     Data : Discord.Schema.GatewayMessageCreateDispatchData;
                  begin
                     Discord.Schema.Inputs
                       .Input_GatewayMessageCreateDispatchData
                         (Reader, Data, Success);

                     Value :=
                       (Kind     => Message_Create,
                        Sequence => Sequence,
                        Message  => Data);
                  end;

               else
                  Value :=
                    (Kind       => Other_Dispatch,
                     Sequence   => Sequence,
                     Event_Name => Name);
               end if;

            when Hello_Opcode =>
               declare
                  Data : Discord.Schema.GatewayHelloData;
               begin
                  Discord.Schema.Inputs.Input_GatewayHelloData
                    (Reader, Data, Success);

                  Value :=
                    (Kind       => Hello,
                     Sequence   => Sequence,
                     Hello_Data => Data);
               end;

            when Heartbeat_Opcode =>
               Value := (Kind => Heartbeat_Request, Sequence => Sequence);

            when Heartbeat_Acknowledge_Opcode =>
               Value := (Kind => Heartbeat_Acknowledge, Sequence => Sequence);

            when Reconnect_Opcode =>
               Value := (Kind => Reconnect, Sequence => Sequence);

            when Invalid_Session_Opcode =>
               Value :=
                 (Kind         => Invalid_Session,
                  Sequence     => Sequence,
                  Is_Resumable =>
                    Reader.Is_Boolean_Value and then Reader.Boolean_Value);

            when others =>
               Value :=
                 (Kind     => Unknown,
                  Sequence => Sequence,
                  Opcode   => Opcode);
         end case;
      end Read_Data;

      procedure Read is
        new Discord.Implementation.JSON_Texts.Read_JSON_Text (Process);
   begin
      Value := (Kind => Unknown, Sequence => (Is_Set => False), Opcode => 0);
      Read (Text, Success);
   end Decode;

   ----------------------
   -- Encode_Heartbeat --
   ----------------------

   function Encode_Heartbeat
     (Sequence : Discord.Schema.Optional_Integer_64) return String
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
         Handler.Start_Object;
         Handler.Key_Name ("op");
         Handler.Integer_Value (Heartbeat_Opcode);
         Handler.Key_Name ("d");

         if Sequence.Is_Set then
            Handler.Integer_Value (Sequence.Value);
         else
            Handler.Null_Value;
         end if;

         Handler.End_Object;
      end Write;

      function To_Text is
        new Discord.Implementation.JSON_Texts.To_JSON_Text (Write);
   begin
      return To_Text;
   end Encode_Heartbeat;

   ---------------------
   -- Encode_Identify --
   ---------------------

   function Encode_Identify
     (Data : Discord.Schema.GatewayIdentifyData) return String
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
         Handler.Start_Object;
         Handler.Key_Name ("op");
         Handler.Integer_Value (Identify_Opcode);
         Handler.Key_Name ("d");
         Discord.Schema.Outputs.Output_GatewayIdentifyData (Handler, Data);
         Handler.End_Object;
      end Write;

      function To_Text is
        new Discord.Implementation.JSON_Texts.To_JSON_Text (Write);
   begin
      return To_Text;
   end Encode_Identify;

   -------------------
   -- Encode_Resume --
   -------------------

   function Encode_Resume
     (Data : Discord.Schema.GatewayResumeData) return String
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
         Handler.Start_Object;
         Handler.Key_Name ("op");
         Handler.Integer_Value (Resume_Opcode);
         Handler.Key_Name ("d");
         Discord.Schema.Outputs.Output_GatewayResumeData (Handler, Data);
         Handler.End_Object;
      end Write;

      function To_Text is
        new Discord.Implementation.JSON_Texts.To_JSON_Text (Write);
   begin
      return To_Text;
   end Encode_Resume;

   ------------------
   -- Read_Integer --
   ------------------

   procedure Read_Integer
     (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
      Value   : out Discord.Schema.Optional_Integer_64;
      Success : in out Boolean) is
   begin
      if Reader.Is_Null_Value then
         Value := (Is_Set => False);
         Reader.Read_Next;
      elsif Reader.Is_Number_Value
        and then Reader.Number_Value.Kind = VSS.JSON.JSON_Integer
      then
         Value := (Is_Set => True, Value => Reader.Number_Value.Integer_Value);
         Reader.Read_Next;
      else
         Value := (Is_Set => False);
         Success := False;
      end if;
   end Read_Integer;

   -----------------
   -- Read_String --
   -----------------

   procedure Read_String
     (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
      Value   : out VSS.Strings.Virtual_String;
      Success : in out Boolean) is
   begin
      Value.Clear;

      if Reader.Is_Null_Value then
         Reader.Read_Next;
      elsif Reader.Is_String_Value then
         Value := Reader.String_Value;
         Reader.Read_Next;
      else
         Success := False;
      end if;
   end Read_String;

end Discord.Gateway.Payloads;
