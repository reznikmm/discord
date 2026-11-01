--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  Encoding and decoding of gateway payloads: {"op":..,"d":..,"s":..,"t":..}

with VSS.Strings;

with Discord.Schema;

package Discord.Gateway.Payloads is

   type Event_Kind is
     (Hello,                  --  op 10
      Heartbeat_Request,      --  op 1
      Heartbeat_Acknowledge,  --  op 11
      Reconnect,              --  op 7
      Invalid_Session,        --  op 9
      Ready,                  --  op 0, t = READY
      Message_Create,         --  op 0, t = MESSAGE_CREATE
      Other_Dispatch,         --  op 0, any other t
      Unknown);               --  any other op

   type Event (Kind : Event_Kind := Unknown) is record
      Sequence : Discord.Schema.Optional_Integer_64;
      --  Sequence number, used for resuming sessions and heartbeating

      case Kind is
         when Hello =>
            Hello_Data : Discord.Schema.GatewayHelloData;
         when Invalid_Session =>
            Is_Resumable : Boolean;
         when Ready =>
            Ready_Data : Discord.Schema.GatewayReadyDispatchData;
         when Message_Create =>
            Message : Discord.Schema.GatewayMessageCreateDispatchData;
         when Other_Dispatch =>
            Event_Name : VSS.Strings.Virtual_String;
         when Unknown =>
            Opcode : Discord.Schema.Integer_64;
         when Heartbeat_Request | Heartbeat_Acknowledge | Reconnect =>
            null;
      end case;
   end record;

   procedure Decode
     (Text    : String;
      Value   : out Event;
      Success : out Boolean);
   --  Decode UTF-8 encoded payload Text

   function Encode_Identify
     (Data : Discord.Schema.GatewayIdentifyData) return String;
   --  Encode Identify (op 2) payload as UTF-8 text

   function Encode_Resume
     (Data : Discord.Schema.GatewayResumeData) return String;
   --  Encode Resume (op 6) payload as UTF-8 text

   function Encode_Heartbeat
     (Sequence : Discord.Schema.Optional_Integer_64) return String;
   --  Encode Heartbeat (op 1) payload as UTF-8 text

end Discord.Gateway.Payloads;
