#!/bin/bash
set -euo pipefail

: "${CONFIG:?CONFIG is not set (see .env)}"
mkdir -p "$CONFIG/home-assistant"
cp home-assistant/* "$CONFIG/home-assistant/"
