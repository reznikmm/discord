--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with VSS.String_Vectors;
with VSS.Strings;

generic
   Variants : VSS.String_Vectors.Virtual_String_Vector;
   --  Known keys of a JSON object

package Discord.Implementation.Key_Lookups is
   pragma Preelaborate;

   function Get_Index (Text : VSS.Strings.Virtual_String) return Natural;
   --  Return index of Text in Variants or zero if Variants doesn't contain
   --  Text. Generated JSON readers use it to dispatch on a key name.

end Discord.Implementation.Key_Lookups;
