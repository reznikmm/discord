--  SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
--
--  SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
----------------------------------------------------------------

--  Discord HTTP API client

with VSS.Strings;

with Discord.Schema;

package Discord.REST is

   type Client is tagged limited private;

   REST_Error : exception;
   --  Raised on a network failure or when the server rejects a request.
   --  The message contains the HTTP status and the response body.

   Default_API_URL : constant String := "https://discord.com/api/v10";

   procedure Initialize
     (Self    : in out Client;
      Token   : VSS.Strings.Virtual_String;
      API_URL : String := Default_API_URL);
   --  Set the bot token to authorize requests

   procedure Create_Message
     (Self       : in out Client;
      Channel_Id : Discord.Snowflake;
      Message    : Discord.Schema.RESTPostAPIChannelMessageJSONBody;
      Result     : out Discord.Schema.APIMessage);
   --  Post a message to a channel

   procedure Create_Message
     (Self       : in out Client;
      Channel_Id : Discord.Snowflake;
      Content    : VSS.Strings.Virtual_String;
      Result     : out Discord.Schema.APIMessage);
   --  Post a text message to a channel

   procedure Reply
     (Self    : in out Client;
      Message : Discord.Schema.GatewayMessageCreateDispatchData;
      Content : VSS.Strings.Virtual_String;
      Result  : out Discord.Schema.APIMessage);
   --  Post a text message as a reply to the given Message

   procedure Get_Channel
     (Self       : in out Client;
      Channel_Id : Discord.Snowflake;
      Result     : out Discord.Schema.APIChannel);
   --  Get a channel by its id

   procedure Create_DM_Channel
     (Self         : in out Client;
      Recipient_Id : Discord.Snowflake;
      Result       : out Discord.Schema.APIChannel);
   --  Open (or get existing) direct message channel with a user

private

   type Client is tagged limited record
      API_URL       : VSS.Strings.Virtual_String;
      Authorization : VSS.Strings.Virtual_String;
   end record;

end Discord.REST;
