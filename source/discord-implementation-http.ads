--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  A minimal HTTPS client used by the REST API. It hides the HTTP library:
--  to replace it, rewrite the body of this package only.

with Ada.Strings.Unbounded;

package Discord.Implementation.HTTP is

   type Method_Kind is (Get, Post, Put, Patch, Delete);

   Connection_Error : exception;

   procedure Send
     (Method        : Method_Kind;
      URL           : String;
      Authorization : String;
      User_Agent    : String;
      Request_Body  : String;
      Status        : out Natural;
      Response_Body : out Ada.Strings.Unbounded.Unbounded_String);
   --  Send a request with JSON Request_Body (when not empty) and return
   --  response status and body. Both bodies are UTF-8 encoded. Raise
   --  Connection_Error on a network failure.

end Discord.Implementation.HTTP;
