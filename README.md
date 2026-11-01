Discord
=======

[![Build with Alire](https://github.com/reznikmm/discord/actions/workflows/alire.yml/badge.svg)](https://github.com/reznikmm/discord/actions/workflows/alire.yml)
[![REUSE status](https://api.reuse.software/badge/github.com/reznikmm/discord)](https://api.reuse.software/info/github.com/reznikmm/discord)

> Discord API client library for Ada (a prototype).

## Features

- `Discord.Schema` - Ada types and JSON readers/writers generated from
  [discord-api-types](https://github.com/discordjs/discord-api-types)
  by `gen_json` from [VSS](https://github.com/AdaCore/vss-extra).
- `Discord.REST` - send messages, reply, get channels, open DM channels.
- `Discord.Gateway` - receive events (`READY`, `MESSAGE_CREATE`, etc),
  heartbeats, reconnect and resume.

The HTTP and web socket library ([AHT](https://github.com/ovenpasta/aht))
is used only in bodies of `Discord.Implementation.*` packages, so it could
be replaced without API changes.

## Example

```ada
type Bot_Listener is limited new Discord.Gateway.Listener with record
   REST : Discord.REST.Client;
end record;

overriding procedure On_Message_Create
  (Self    : in out Bot_Listener;
   Message : Discord.Schema.GatewayMessageCreateDispatchData) is
begin
   if not Message.author.bot and Message.content = "!ping" then
      Self.REST.Reply (Message, "pong", Result);
   end if;
end On_Message_Create;
...
Listener.REST.Initialize (Token);
Gateway.Connect (Token, [Guild_Messages | Message_Content => True,
                         others => False]);
Gateway.Run (Listener);
```

See `examples/src/echo_bot.adb`. Run it with:

```sh
cd examples
DISCORD_TOKEN=... alr run
```

Enable *Message Content Intent* for the bot in the Developer Portal,
otherwise the gateway closes the connection with code 4014.

## Regenerate schema bindings

```sh
GEN_JSON=/path/to/gen_json tools/schema/generate.sh
```

Edit `tools/schema/filter_schema.py` to add types or properties.

## Build and test

```sh
alr build
alr test
```

## License

Apache-2.0 WITH LLVM-exception. The schema (`tools/schema/discord.json`)
is derived from discord-api-types (MIT). See `LICENSES/` and `REUSE.toml`.
