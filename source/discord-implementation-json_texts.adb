--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Ada.Streams;

with VSS.JSON.Pull_Readers.Simple;
with VSS.JSON.Push_Writers;
with VSS.Stream_Element_Vectors.Conversions;
with VSS.Text_Streams.Memory_UTF8_Input;
with VSS.Text_Streams.Memory_UTF8_Output;

package body Discord.Implementation.JSON_Texts is

   function To_Vector
     (Text : String) return VSS.Stream_Element_Vectors.Stream_Element_Vector;

   ---------------------
   -- Parse_JSON_Text --
   ---------------------

   procedure Parse_JSON_Text
     (Text    : String;
      Value   : out Value_Type;
      Success : out Boolean)
   is
      procedure Process
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Success : in out Boolean);

      -------------
      -- Process --
      -------------

      procedure Process
        (Reader  : in out VSS.JSON.Pull_Readers.JSON_Pull_Reader'Class;
         Success : in out Boolean) is
      begin
         Input (Reader, Value, Success);
      end Process;

      procedure Read is new Read_JSON_Text (Process);
   begin
      Read (Text, Success);
   end Parse_JSON_Text;

   --------------------
   -- Read_JSON_Text --
   --------------------

   procedure Read_JSON_Text (Text : String; Success : out Boolean) is
      Input  : aliased VSS.Text_Streams.Memory_UTF8_Input
        .Memory_UTF8_Input_Stream;
      Reader : VSS.JSON.Pull_Readers.Simple.JSON_Simple_Pull_Reader;
   begin
      Input.Set_Data (To_Vector (Text));
      Reader.Set_Stream (Input'Unchecked_Access);
      Reader.Read_Next;  --  Start_Document

      if Reader.Is_Start_Document then
         Reader.Read_Next;
         Success := True;
         Process (Reader, Success);
      else
         Success := False;
      end if;
   end Read_JSON_Text;

   ------------------
   -- To_JSON_Text --
   ------------------

   function To_JSON_Text return String is
      Output : aliased VSS.Text_Streams.Memory_UTF8_Output
        .Memory_UTF8_Output_Stream;
      Writer : VSS.JSON.Push_Writers.JSON_Simple_Push_Writer;
   begin
      Writer.Set_Stream (Output'Unchecked_Access);
      Writer.Start_Document;
      Write (Writer);
      Writer.End_Document;

      return VSS.Stream_Element_Vectors.Conversions.Unchecked_To_String
        (Output.Buffer);
   end To_JSON_Text;

   ---------------
   -- To_Vector --
   ---------------

   function To_Vector
     (Text : String) return VSS.Stream_Element_Vectors.Stream_Element_Vector
   is
      Result : VSS.Stream_Element_Vectors.Stream_Element_Vector;
   begin
      for Character of Text loop
         Result.Append (Ada.Streams.Stream_Element'Val
                          (Standard.Character'Pos (Character)));
      end loop;

      return Result;
   end To_Vector;

end Discord.Implementation.JSON_Texts;
