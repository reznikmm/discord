#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
"""Extract a small, gen_json-friendly subset of discord-api-types schemas.

Usage: filter_schema.py <output.json> <input.json>...

Every input is a schema produced by ts-json-schema-generator for one root
type.  Definitions of all inputs are merged, then only definitions (and
only properties) listed in SELECTION are kept.  Constructions that gen_json
does not handle are simplified:

* "number" becomes "integer" (Discord sends integers for all of them);
* numeric enumerations become plain "integer";
* {"anyOf": [X, {"type": "null"}]} becomes X;
* references to dropped definitions that are simple types are inlined.
"""

import json
import sys
import urllib.parse

# Definition name -> list of kept properties (None keeps every property).
MESSAGE_PROPERTIES = [
    "id", "channel_id", "author", "content", "timestamp",
    "edited_timestamp", "tts", "mention_everyone", "mentions", "type",
    "flags", "message_reference", "webhook_id", "application_id",
]

SELECTION = {
    "APIUser": [
        "id", "username", "discriminator", "global_name", "avatar", "bot",
        "system",
    ],
    "APIMessageReference": ["type", "message_id", "channel_id", "guild_id"],
    "RESTAPIMessageReference": [
        "type", "message_id", "channel_id", "guild_id", "fail_if_not_exists",
    ],
    "APIMessage": MESSAGE_PROPERTIES,
    "GatewayMessageCreateDispatchData": MESSAGE_PROPERTIES + ["guild_id"],
    "RESTPostAPIChannelMessageJSONBody": [
        "content", "tts", "flags", "message_reference",
    ],
    "APIUnavailableGuild": ["id", "unavailable"],
    "APIChannel": [
        "id", "type", "guild_id", "name", "topic", "position", "nsfw",
        "last_message_id", "parent_id", "owner_id", "rate_limit_per_user",
        "recipients", "flags",
    ],
    "RESTPostAPICurrentUserCreateDMChannelJSONBody": None,
    "GatewayHelloData": None,
    "GatewayIdentifyProperties": None,
    "GatewayIdentifyData": [
        "token", "properties", "intents", "compress", "large_threshold",
    ],
    "GatewayResumeData": None,
    "GatewayReadyDispatchData": [
        "v", "user", "guilds", "session_id", "resume_gateway_url",
    ],
}

# ts-json-schema-generator produces empty objects for some TypeScript helper
# types (_AddUndefinedToPossiblyUndefinedPropertiesOfInterface<...>), so
# these properties are replaced by hand.
SNOWFLAKE = {"$ref": "#/definitions/Snowflake"}

OVERRIDES = {
    "RESTAPIMessageReference": {
        "type": {"$ref": "#/definitions/MessageReferenceType"},
        "message_id": SNOWFLAKE,
        "channel_id": SNOWFLAKE,
        "guild_id": SNOWFLAKE,
    },
    # APIUserWithMember is APIUser with an optional partial member object
    "GatewayMessageCreateDispatchData": {
        "mentions": {
            "description": "Users specifically mentioned in the message",
            "items": {"$ref": "#/definitions/APIUser"},
            "type": "array",
        },
    },
}

# Unions of objects distinguished by a numeric "type" are not supported by
# gen_json, so they are flattened into one object with all properties of all
# variants (like the Channel object in the Discord documentation).
FLATTENED = {
    "APIChannel": {
        "required": ["id", "type"],
        "properties": {
            "type": {
                "description": "The type of the channel",
                "type": "integer",
            },
        },
    },
}

DROPPED_KEYS = {"deprecated", "title"}


def is_simple(schema):
    """Definition that can be inlined instead of a reference."""
    return "properties" not in schema and "anyOf" not in schema \
        and schema.get("type") in ("string", "number", "integer", "boolean")


def collect_properties(schema, definitions):
    """Properties of all variants of anyOf/allOf schema."""
    if "$ref" in schema:
        name = urllib.parse.unquote(schema["$ref"].split("/")[-1])
        return collect_properties(definitions[name], definitions)

    result = {}

    for key in ("allOf", "anyOf"):
        for item in schema.get(key, []):
            result.update(collect_properties(item, definitions))

    result.update(schema.get("properties", {}))
    return result


def flatten(name, definitions):
    flattened = FLATTENED[name]
    properties = collect_properties(definitions[name], definitions)
    properties.update(flattened["properties"])

    return {
        "additionalProperties": False,
        "properties": properties,
        "required": flattened["required"],
        "type": "object",
    }


def simplify(schema, definitions):
    if isinstance(schema, list):
        return [simplify(item, definitions) for item in schema]

    if not isinstance(schema, dict):
        return schema

    if "$ref" in schema:
        name = urllib.parse.unquote(schema["$ref"].split("/")[-1])

        if name not in SELECTION:
            target = definitions[name]

            if not is_simple(target):
                raise SystemExit(f"Reference to dropped definition {name}")

            result = {key: value for key, value in schema.items()
                      if key != "$ref"}
            result.update(simplify(target, definitions))
            return result

    if "anyOf" in schema:
        variants = [item for item in schema["anyOf"]
                    if item != {"type": "null"}]

        if len(variants) == 1:
            result = {key: value for key, value in schema.items()
                      if key != "anyOf"}
            result.update(variants[0])
            return simplify(result, definitions)

    result = {}

    for key, value in schema.items():
        if key in DROPPED_KEYS:
            continue
        elif key == "type":
            if value == "number":
                value = "integer"
            elif isinstance(value, list):
                value = ["integer" if item == "number" else item
                         for item in value]
        elif key == "enum" and all(isinstance(item, (int, float))
                                   for item in value):
            continue
        elif key == "const" and isinstance(value, (int, float)):
            continue
        elif key in ("properties", "definitions"):
            value = {name: simplify(item, definitions)
                     for name, item in value.items()}
        elif isinstance(value, (dict, list)):
            value = simplify(value, definitions)

        result[key] = value

    return result


def main():
    output, inputs = sys.argv[1], sys.argv[2:]
    definitions = {}

    for name in inputs:
        with open(name, encoding="utf-8") as file:
            definitions.update(json.load(file)["definitions"])

    selected = {}

    for name, properties in SELECTION.items():
        if name in FLATTENED:
            schema = flatten(name, definitions)
        else:
            schema = dict(definitions[name])

        if name in OVERRIDES:
            schema["properties"] = dict(schema["properties"])
            schema["properties"].update(OVERRIDES[name])

        if properties is not None:
            missing = set(properties) - set(schema["properties"])

            if missing:
                raise SystemExit(f"{name}: unknown properties {missing}")

            schema["properties"] = {
                key: schema["properties"][key] for key in properties}

            if "required" in schema:
                schema["required"] = [
                    key for key in schema["required"] if key in properties]

        selected[name] = simplify(schema, definitions)

    result = {
        "$schema": "http://json-schema.org/draft-07/schema#",
        "definitions": dict(sorted(selected.items())),
    }

    with open(output, "w", encoding="utf-8") as file:
        json.dump(result, file, indent=2)
        file.write("\n")


if __name__ == "__main__":
    main()
