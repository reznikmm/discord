--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

with Trendy_Test;

package Test_Payloads is

   procedure Test_Decode_Hello (Op : in out Trendy_Test.Operation'Class);
   procedure Test_Decode_Ready (Op : in out Trendy_Test.Operation'Class);

   procedure Test_Decode_Message_Create
     (Op : in out Trendy_Test.Operation'Class);

   procedure Test_Decode_Data_First
     (Op : in out Trendy_Test.Operation'Class);

   procedure Test_Decode_Other (Op : in out Trendy_Test.Operation'Class);
   procedure Test_Encode_Heartbeat (Op : in out Trendy_Test.Operation'Class);
   procedure Test_Encode_Identify (Op : in out Trendy_Test.Operation'Class);
   procedure Test_Intents (Op : in out Trendy_Test.Operation'Class);

end Test_Payloads;
