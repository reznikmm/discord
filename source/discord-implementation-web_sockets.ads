--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  A minimal web socket client used by the gateway. It hides the web socket
--  library: to replace it, rewrite the body of this package only.

with Ada.Strings.Unbounded;

private with Ada.Finalization;

package Discord.Implementation.Web_Sockets is

   type Web_Socket is tagged limited private;

   Connection_Error : exception;

   procedure Connect (Self : in out Web_Socket; URL : String);
   --  Open a (secure) web socket connection to URL. Close previous connection
   --  if any. Raise Connection_Error on failure.

   procedure Send_Text (Self : in out Web_Socket; Text : String);
   --  Send UTF-8 encoded Text as a text message.

   type Receive_Status is (Received, Timed_Out, Closed);

   procedure Receive
     (Self    : in out Web_Socket;
      Text    : out Ada.Strings.Unbounded.Unbounded_String;
      Timeout : Duration;
      Status  : out Receive_Status);
   --  Wait up to Timeout for the next message. Text is UTF-8 encoded.

   function Close_Code (Self : Web_Socket) return Natural;
   --  Close code sent by the server or zero if unknown.

   function Close_Reason (Self : Web_Socket) return String;
   --  Close reason sent by the server.

   procedure Close (Self : in out Web_Socket; Code : Positive := 1000);
   --  Close connection with given Code

private

   type Connection;
   type Connection_Access is access Connection;

   type Web_Socket is new Ada.Finalization.Limited_Controlled with record
      Connection : Connection_Access;
   end record;

   overriding procedure Finalize (Self : in out Web_Socket);

end Discord.Implementation.Web_Sockets;
