--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

with Ada.Exceptions;

with AHT.HTTP.Client;
with AHT.HTTP.Methods;
with AHT.HTTP.Request;
with AHT.HTTP.Response;
with AHT.URL;

package body Discord.Implementation.HTTP is

   ----------
   -- Send --
   ----------

   procedure Send
     (Method        : Method_Kind;
      URL           : String;
      Authorization : String;
      User_Agent    : String;
      Request_Body  : String;
      Status        : out Natural;
      Response_Body : out Ada.Strings.Unbounded.Unbounded_String)
   is
      Client   : AHT.HTTP.Client.Client_Type;
      Request  : AHT.HTTP.Request.Request_Type;
      Response : AHT.HTTP.Response.Response_Type;
   begin
      Client.User_Agent := Ada.Strings.Unbounded.To_Unbounded_String
        (User_Agent);

      Request.Method :=
        (case Method is
            when Get    => AHT.HTTP.Methods.GET,
            when Post   => AHT.HTTP.Methods.POST,
            when Put    => AHT.HTTP.Methods.PUT,
            when Patch  => AHT.HTTP.Methods.PATCH,
            when Delete => AHT.HTTP.Methods.DELETE);

      Request.Target := AHT.URL.Parse (URL);
      Request.Headers.Set ("authorization", Authorization);

      if Request_Body /= "" then
         Request.Headers.Set ("content-type", "application/json");
         Request.Set_Body (Request_Body);
      end if;

      Client.Send (Request, Response);

      Status := Response.Status;
      Response_Body := Ada.Strings.Unbounded.To_Unbounded_String
        (Response.Body_Text);
   exception
      when Error : others =>
         raise Connection_Error
           with URL & ": " & Ada.Exceptions.Exception_Information (Error);
   end Send;

end Discord.Implementation.HTTP;
