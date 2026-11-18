#!/bin/bash
# Home Assistant 2025.8.x -> 2026.11.2
# Breaking changes come from the "Backward-incompatible changes" sections of the
# monthly release posts 2025.9 through 2026.11 (https://www.home-assistant.io/blog/categories/core/).
source "$(dirname "$0")/lib.sh"

SVC=home-assistant
CONTAINER=home-assistant
IMAGE=linuxserver/homeassistant
TARGET=2026.11.2
DATA="$CONFIG/home-assistant"

current="$(current_image $SVC $IMAGE)"; current_tag="${current#*:}"
[ -n "$current" ] || die "could not find $IMAGE in $(compose_file $SVC)"
if [ "$current_tag" = "$TARGET" ]; then ok "already on $IMAGE:$TARGET"; exit 0; fi

step "Preflight: Home Assistant $current_tag -> $TARGET"
[ -d "$DATA" ] || die "$DATA does not exist"
require_running $CONTAINER

# 2025.12: 32-bit architectures dropped. 2026.3: images use zstd layers (Docker 23+).
arch="$(uname -m)"
case "$arch" in
  x86_64|aarch64) ok "architecture $arch is supported" ;;
  *) die "architecture $arch is no longer supported by Home Assistant (2025.12)" ;;
esac
docker_version="$(docker version -f '{{.Server.Version}}')"
if printf '%s\n%s\n' 23.0.0 "$docker_version" | sort -VC; then
  ok "Docker $docker_version (23.0+ needed for zstd image layers)"
else
  die "Docker $docker_version is too old; 23.0+ is needed to pull 2026.3+ images"
fi

# Scan the YAML config (UI-made automations are stored in automations.yaml too).
yaml_files=$(docker run --rm -v "$DATA:/d:ro" alpine:3 \
  find /d -maxdepth 3 -name '*.yaml' ! -path '*/.storage/*' ! -path '*/custom_components/*' ! -path '*/deps/*' ! -path '*/themes/*')
check_yaml() { # check_yaml <message> <grep -E pattern>
  local hits
  hits="$(docker run --rm -v "$DATA:/d:ro" alpine:3 grep -nE "$2" $yaml_files 2>/dev/null | sed 's#^/d/##' || true)"
  if [ -n "$hits" ]; then
    warn "$1"
    sed 's/^/        /' <<< "$hits"
  fi
}

step "Scanning YAML configuration"
check_yaml "2026.5 removed the entered_home / left_home triggers and is_home / is_not_home conditions:" \
  'entered_home|left_home|is_home|is_not_home'
check_yaml "2026.11: sun/calendar offsets without offset_type now use the sign of offset (negative = before). Check these:" \
  '^\s*offset:'
check_yaml "2026.3 removed mired colour temperatures; use color_temp_kelvin / min_color_temp_kelvin / max_color_temp_kelvin:" \
  '(^|\s)(color_temp|min_mireds|max_mireds):'
check_yaml "2026.6 removed the legacy per-platform template syntax; move these to the template: block:" \
  'platform:\s*template'
check_yaml "2026.11 removed the legacy Telegram notify platform from YAML:" \
  'platform:\s*telegram'
check_yaml "2026.6/2026.7 renamed purpose-specific trigger/condition keys and behavior any->each, last->all. Re-check these:" \
  '^\s*-?\s*(trigger|condition):\s*[a-z_]+\.[a-z_]+'

# 2026.10: usernames are forced to lowercase with no surrounding spaces.
users="$(cat_as_root "$DATA" .storage/auth_provider.homeassistant 2>/dev/null \
  | grep -oE '"username": *"[^"]*"' | sed -E 's/.*: *"(.*)"/\1/' || true)"
bad_users="$(grep -E '[A-Z]|^ | $' <<< "$users" || true)"
if [ -n "$bad_users" ]; then
  warn "2026.10 lowercases usernames; these will change (log in with the lowercase form afterwards):"
  sed 's/^/        - /' <<< "$bad_users"
else
  ok "usernames are already lowercase"
fi

if docker run --rm -v "$DATA:/d:ro" alpine:3 test -d /d/custom_components/hacs; then
  info "HACS is installed; 2026.11 migrates it to the built-in Marketplace on first start"
fi

end_of_checks

step "Stopping Home Assistant"
compose $SVC stop $CONTAINER

step "Backing up $DATA"
backup $SVC "$DATA" ./deps ./tts

step "Upgrading image"
set_image $SVC $IMAGE $TARGET
compose $SVC pull -q $CONTAINER
compose $SVC up -d $CONTAINER

step "Waiting for Home Assistant (database migrations run on first start)"
wait_healthy $CONTAINER 1800

print_rollback $SVC "$DATA" $IMAGE "$current_tag"
cat <<EOF

    Now, before anything else:
      - Log in through the tailnet URL. 2026.11 rejects logins from non-local
        addresses ("Invalid client id") when the scheme/host/port the browser uses
        doesn't match what HA sees. If it fails, check the Tailscale serve config.
      - Settings -> Repairs: fix anything flagged (2026.8 also imports the http:
        settings into the UI and may raise a repair; that's expected)
      - Settings -> Automations: look for automations marked unavailable/invalid
      - Settings -> Marketplace: check HACS integrations migrated, if you had HACS
EOF
