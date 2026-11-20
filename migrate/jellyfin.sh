#!/bin/bash
# Jellyfin 10.11.x -> 12.4
# Release notes: https://github.com/jellyfin/jellyfin/releases/tag/v12.0
#  - DB migration cannot be rolled back without restoring a backup
#  - third-party (repository) plugins must be removed before migrating
#  - a full library scan is REQUIRED afterwards (auto-resolved alternate versions are dropped)
#  - legacy authorization and /emby/* routes are removed (Seerr >= 3.5 and homepage already use the new header)
source "$(dirname "$0")/lib.sh"

SVC=jellyfin
IMAGE=linuxserver/jellyfin
TARGET=12.4ubu2604-ls60
APP_DIR="$CONFIG/jellyfin"

current="$(current_image $SVC $IMAGE)"; current_tag="${current#*:}"
[ -n "$current" ] || die "could not find $IMAGE in $(compose_file $SVC)"
if [ "$current_tag" = "$TARGET" ]; then ok "already on $IMAGE:$TARGET"; exit 0; fi

step "Preflight: Jellyfin $current_tag -> $TARGET"

case "$current_tag" in
  10.11.*|10.10.7) ok "direct upgrade from $current_tag is supported" ;;
  *) die "$current_tag is not supported for a direct upgrade; move to 10.11.x first" ;;
esac

[ -d "$APP_DIR" ] || die "$APP_DIR does not exist"
require_running $SVC

# Seerr must already speak the new Jellyfin auth headers (seerr v3.5.0, PR #3502).
seerr_image="$(docker inspect -f '{{.Config.Image}}' jellyseerr 2>/dev/null || true)"
seerr_tag="${seerr_image##*:v}"
if [ -z "$seerr_image" ]; then
  warn "jellyseerr container not found; if you use Seerr, deploy v3.5+ before this migration"
elif printf '%s\n%s\n' 3.5.0 "$seerr_tag" | sort -VC; then
  ok "Seerr is on $seerr_image"
else
  warn "Seerr is on $seerr_image; deploy v3.5.0+ first (task jellyseerr-up) or it loses access to Jellyfin 12"
fi

# Third-party plugins live in data/plugins (bundled ones ship inside the image).
mapfile -t plugins < <(docker run --rm -v "$APP_DIR:/d:ro" alpine:3 \
  sh -c '[ -d /d/data/plugins ] && find /d/data/plugins -mindepth 1 -maxdepth 1 -type d ! -name configurations -exec basename {} \;' || true)
if [ "${#plugins[@]}" -gt 0 ]; then
  warn "third-party plugins installed (they will be moved aside after the backup):"
  printf '      - %s\n' "${plugins[@]}"
else
  ok "no third-party plugins installed"
fi

# The plugin repository must be the stable one.
repo_urls="$(docker run --rm -v "$APP_DIR:/d:ro" alpine:3 sh -c '
  f=$(find /d -maxdepth 2 -name system.xml | head -1)
  [ -n "$f" ] && sed -n "/<PluginRepositories>/,/<\/PluginRepositories>/p" "$f" | grep -o "<Url>[^<]*" | cut -c6-')"
if grep -qi 'unstable' <<< "$repo_urls"; then
  warn "an unstable plugin repository is configured; switch it to https://repo.jellyfin.org/files/plugin/manifest.json"
  sed 's/^/        /' <<< "$repo_urls"
else
  ok "plugin repositories: $(tr '\n' ' ' <<< "$repo_urls")"
fi

need_kb=$(docker run --rm -v "$APP_DIR:/d:ro" alpine:3 sh -c 'du -sk --exclude=./cache /d 2>/dev/null || du -sk /d' | cut -f1)
mkdir -p "$BACKUP_DIR"
free_kb=$(df -Pk "$BACKUP_DIR" | awk 'NR==2 {print $4}')
if [ "$free_kb" -lt "$need_kb" ]; then
  warn "backup needs up to $((need_kb / 1024)) MB but only $((free_kb / 1024)) MB is free in $BACKUP_DIR"
else
  ok "enough space for the backup (~$((need_kb / 1024)) MB before compression)"
fi

end_of_checks

step "Stopping Jellyfin"
compose $SVC stop $SVC

step "Backing up $APP_DIR (cache excluded)"
backup $SVC "$APP_DIR" ./cache

if [ "${#plugins[@]}" -gt 0 ]; then
  step "Moving third-party plugins aside"
  aside="plugins-before-12-$STAMP"
  docker run --rm -v "$APP_DIR:/d" alpine:3 sh -c "
    mkdir -p /d/data/$aside &&
    for p in \"\$@\"; do mv \"/d/data/plugins/\$p\" /d/data/$aside/; done" _ "${plugins[@]}"
  ok "moved to $APP_DIR/data/$aside (reinstall compatible versions from the catalogue later)"
fi

step "Upgrading image"
set_image $SVC $IMAGE $TARGET
compose $SVC pull -q $SVC
compose $SVC up -d $SVC

step "Waiting for the database migration (can take a long time on big libraries)"
wait_healthy $SVC 600
waited=0
until docker exec $SVC curl -fs http://localhost:8096/health 2>/dev/null | grep -q Healthy; do
  [ "$waited" -ge 3600 ] && die "Jellyfin /health did not report Healthy within an hour; check: docker logs $SVC"
  sleep 15; waited=$((waited + 15))
done
ok "Jellyfin reports Healthy"

step "Triggering the required full library scan"
if [ -n "${JELLYFIN_KEY:-}" ]; then
  docker exec $SVC curl -fs -X POST \
    -H "Authorization: MediaBrowser Token=\"$JELLYFIN_KEY\"" \
    http://localhost:8096/Library/Refresh \
    && ok "library scan started (the first one is much slower than usual)" \
    || warn "could not start the scan via the API; run it from Dashboard -> Libraries -> Scan All Libraries"
else
  warn "JELLYFIN_KEY not set; run Dashboard -> Libraries -> Scan All Libraries manually"
fi

print_rollback $SVC "$APP_DIR" $IMAGE "$current_tag"
cat <<EOF

    After the scan finishes:
      - Reinstall the plugins you need from Dashboard -> Plugins -> Catalog
      - Subtitle settings are now per library: re-check them in each library's settings
      - Check the homepage widget and Seerr (Settings -> Jellyfin -> Sync Libraries)
      - Very old third-party clients using /emby/* routes stop working
EOF
