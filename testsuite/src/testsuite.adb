--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

with Test_Payloads;
with Trendy_Test.Reports;

procedure Testsuite is
   Tests : constant Trendy_Test.Test_Group :=
     [Test_Payloads.Test_Decode_Hello'Access,
      Test_Payloads.Test_Decode_Ready'Access,
      Test_Payloads.Test_Decode_Message_Create'Access,
      Test_Payloads.Test_Decode_Data_First'Access,
      Test_Payloads.Test_Decode_Other'Access,
      Test_Payloads.Test_Encode_Heartbeat'Access,
      Test_Payloads.Test_Encode_Identify'Access,
      Test_Payloads.Test_Intents'Access];
begin
   Trendy_Test.Register (Tests);
   Trendy_Test.Reports.Print_Basic_Report (Trendy_Test.Run);
end Testsuite;
