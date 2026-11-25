#!/bin/bash
# Copies the Homepage config into $CONFIG/homepage and fills in every placeholder
# listed in .homepage.env.example with its value from the environment (Task loads .homepage.env).
set -euo pipefail

: "${CONFIG:?CONFIG is not set (see .env)}"
dest="$CONFIG/homepage"
mkdir -p "$dest"
cp homepage/* "$dest/"

# Escape a value for the replacement side of a sed s@...@...@ expression.
escape() { printf '%s' "$1" | sed -e 's/[\\&@]/\\&/g'; }

missing=()
while IFS='=' read -r name _; do
  name="${name%$'\r'}"
  [ -n "$name" ] || continue
  if [ -z "${!name:-}" ]; then missing+=("$name"); continue; fi
  # \b keeps SONARR_HREF from matching inside SONARR_ANIME_HREF.
  sed -i "s@\b$name\b@$(escape "${!name}")@g" "$dest/settings.yaml" "$dest/services.yaml"
done < ../.homepage.env.example

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Not set in .homepage.env, left as placeholders: ${missing[*]}" >&2
fi
