--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  Discord API client library.
--
--  * Discord.Schema - data types generated from discord-api-types
--  * Discord.REST - HTTP API (send messages, get channels, etc)
--  * Discord.Gateway - web socket API (receive events)

with VSS.Strings;

package Discord is
   pragma Preelaborate;

   subtype Snowflake is VSS.Strings.Virtual_String;
   --  Discord unique identifier (a decimal number in a string)

end Discord;
