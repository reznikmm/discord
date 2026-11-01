#!/bin/bash
# SPDX-FileCopyrightText: 2026 Max Reznik <reznikmm@gmail.com>
#
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

# Regenerate source/schema/ from discord-api-types.
#
# USAGE:
#   GEN_JSON=/path/to/gen_json tools/schema/generate.sh
#
# Requires npm/npx, python3, gnatchop and gen_json from
# https://github.com/AdaCore/vss-extra (tools/json_schema).

set -e

TOOLS=$(realpath $(dirname "$0"))
ROOT=$(realpath "$TOOLS/../..")
WORK=${WORK:-$ROOT/.obj/schema}
GEN_JSON=${GEN_JSON:-gen_json}

# Root types to take from discord-api-types. Each of them is converted
# separately, because `--type "*"` fails on some types.
TYPES="
APIChannel
GatewayHelloData
GatewayIdentifyData
GatewayMessageCreateDispatchData
GatewayReadyDispatchData
GatewayResumeData
RESTPostAPIChannelMessageJSONBody
RESTPostAPICurrentUserCreateDMChannelJSONBody
"

mkdir -p "$WORK"
cd "$WORK"

if [ ! -d node_modules/discord-api-types ]; then
    npm init -y > /dev/null
    npm install --silent discord-api-types ts-json-schema-generator
fi

for TYPE in $TYPES; do
    npx ts-json-schema-generator \
        --path node_modules/discord-api-types/v10.d.ts \
        --type "$TYPE" --out "full-$TYPE.json"
done

python3 "$TOOLS/filter_schema.py" "$TOOLS/discord.json" full-*.json

"$GEN_JSON" \
    --root-package Discord.Schema \
    --header-file "$TOOLS/header.txt" \
    "$TOOLS/discord.json" > generated.ada

# Use own key lookup package instead of Minimal_Perfect_Hash. Drop
# Style_Checks pragma, because it enables style checks back.
sed -i \
    -e '/^pragma Style_Checks ("M[0-9]*");/d' \
    -e 's/^with Minimal_Perfect_Hash;/with Discord.Implementation.Key_Lookups;/' \
    -e 's/is new Minimal_Perfect_Hash (/is new Discord.Implementation.Key_Lookups (/' \
    generated.ada

rm -rf "$ROOT/source/schema"
mkdir -p "$ROOT/source/schema"
gnatchop -q -w generated.ada "$ROOT/source/schema" > /dev/null
