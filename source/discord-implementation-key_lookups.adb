--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

package body Discord.Implementation.Key_Lookups is

   ---------------
   -- Get_Index --
   ---------------

   function Get_Index (Text : VSS.Strings.Virtual_String) return Natural is
      use type VSS.Strings.Virtual_String;
   begin
      --  Objects have a few keys, so a linear search is good enough
      for Index in 1 .. Variants.Length loop
         if Variants (Index) = Text then
            return Index;
         end if;
      end loop;

      return 0;
   end Get_Index;

end Discord.Implementation.Key_Lookups;
