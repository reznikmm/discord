--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  Conversions between JSON texts (UTF-8 encoded String) and VSS JSON
--  readers/writers.

with VSS.JSON.Content_Handlers;
with VSS.JSON.Pull_Readers;

package Discord.Implementation.JSON_Texts is

   generic
      with procedure Write
        (Handler : in out
           VSS.JSON.Content_Handlers.JSON_Content_Handler'Class);
   function To_JSON_Text return String;
   --  Return JSON document written by Write as UTF-8 encoded text.

   generic
      type Value_Type is limited private;

      with procedure Input
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Value   : out Value_Type;
         Success : in out Boolean);
   procedure Parse_JSON_Text
     (Text    : String;
      Value   : out Value_Type;
      Success : out Boolean);
   --  Parse UTF-8 encoded JSON Text with given Input procedure.

   generic
      with procedure Process
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Success : in out Boolean);
   procedure Read_JSON_Text (Text : String; Success : out Boolean);
   --  Create a reader for UTF-8 encoded Text, move it to the first element
   --  after the Start_Document and call Process.

end Discord.Implementation.JSON_Texts;
