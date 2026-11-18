#!/bin/bash
# Shared helpers for the migrate/*.sh scripts.
# Each migration script: runs preflight checks, backs up the service's data,
# bumps the image tag in its compose file, restarts it and waits for health.
#
# Usage: bash migrate/<service>.sh [--check]
#   --check   run the preflight checks only, change nothing

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Taskfile loads these already; load them too when the script is run directly.
for envfile in .env .homepage.env; do
  if [ -f "$envfile" ]; then
    set -a
    # shellcheck disable=SC1090
    . "./$envfile"
    set +a
  fi
done

CHECK_ONLY=false
[ "${1:-}" = "--check" ] && CHECK_ONLY=true

: "${CONFIG:?CONFIG is not set (see .env)}"
BACKUP_DIR="${BACKUP_DIR:-$CONFIG/backups/migrations}"
STAMP="$(date +%Y%m%d-%H%M%S)"
WARNINGS=0

c_red=$'\e[31m'; c_yel=$'\e[33m'; c_grn=$'\e[32m'; c_bld=$'\e[1m'; c_off=$'\e[0m'

step()  { echo; echo "${c_bld}==> $*${c_off}"; }
info()  { echo "    $*"; }
ok()    { echo "    ${c_grn}ok${c_off}  $*"; }
warn()  { echo "    ${c_yel}WARN${c_off} $*"; WARNINGS=$((WARNINGS + 1)); }
die()   { echo "${c_red}ERROR${c_off} $*" >&2; exit 1; }

# Any unexpected failure: say where, and remind that the service may be left stopped.
BACKUP_FILE=""
on_error() {
  echo "${c_red}ERROR${c_off} '${BASH_COMMAND}' failed (line $1). The service may be stopped." >&2
  [ -n "$BACKUP_FILE" ] && echo "      Backup taken before the failure: $BACKUP_FILE" >&2
}
trap 'on_error $LINENO' ERR

confirm() {
  local answer
  read -r -p "    $* [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# compose_file <service-dir>
compose_file() { echo "services/$1/docker-compose.yml"; }

# current_image <service-dir> <image-repo>  -> prints the full "repo:tag" currently in the compose file
current_image() {
  tr -d '\r' < "$(compose_file "$1")" | grep -oE "image: $2:[^ ]+" | head -1 | sed 's/^image: //'
}

# set_image <service-dir> <image-repo> <new-tag>   (keeps CRLF line endings intact)
set_image() {
  local file; file="$(compose_file "$1")"
  sed -i -E "s#(image: $2):[^ \r]+(\r?)\$#\1:$3\2#" "$file"
  grep -q "image: $2:$3" "$file" || die "failed to set $2:$3 in $file"
  ok "$file -> $2:$3"
}

# end_of_checks: stop here in --check mode, otherwise ask before continuing if anything warned
end_of_checks() {
  echo
  if [ "$WARNINGS" -gt 0 ]; then
    echo "${c_yel}$WARNINGS warning(s) above. Review them before migrating.${c_off}"
  else
    echo "${c_grn}Preflight checks passed.${c_off}"
  fi
  if $CHECK_ONLY; then exit 0; fi
  confirm "Proceed with the migration?" || die "aborted"
}

# backup <name> <host-dir> [tar --exclude patterns...]
# Archives the directory through a throwaway container so root-owned files are included.
# Stop the service first so its databases are consistent.
backup() {
  local name="$1" src="$2"; shift 2
  local excludes=() pattern
  for pattern in "$@"; do excludes+=("--exclude=$pattern"); done
  [ -d "$src" ] || die "backup source $src does not exist"
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="$BACKUP_DIR/$name-$STAMP.tar.gz"
  info "archiving $src -> $BACKUP_FILE"
  docker run --rm \
    -v "$src:/src:ro" \
    -v "$BACKUP_DIR:/dest" \
    alpine:3 tar czf "/dest/$(basename "$BACKUP_FILE")" "${excludes[@]}" -C /src .
  ok "backup written ($(du -h "$BACKUP_FILE" | cut -f1))"
}

# print_rollback <service-dir> <host-dir> <image-repo> <old-tag>
print_rollback() {
  cat <<EOF

    To roll back:
      docker compose -f $(compose_file "$1") down
      docker run --rm -v "$2:/dst" -v "$BACKUP_DIR:/b:ro" alpine:3 \\
        sh -c 'rm -rf /dst/* /dst/.[!.]* 2>/dev/null; tar xzf /b/$(basename "$BACKUP_FILE") -C /dst'
      sed -i -E 's#(image: $3):[^ \\r]+#\1:$4#' $(compose_file "$1")
      docker compose -f $(compose_file "$1") up -d
EOF
}

# compose <service-dir> <args...>
compose() { local d="$1"; shift; docker compose -f "$(compose_file "$d")" "$@"; }

# wait_healthy <container> [timeout-seconds] [probe-command...]
# Uses the container's Docker healthcheck when it has one, else the given probe command.
wait_healthy() {
  local container="$1" timeout="${2:-600}"; shift 2 || true
  local waited=0 status
  info "waiting for $container to become healthy (timeout ${timeout}s)"
  while [ "$waited" -lt "$timeout" ]; do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$container" 2>/dev/null || echo missing)"
    case "$status" in
      healthy) ok "$container is healthy"; return 0 ;;
      none)
        if [ $# -gt 0 ] && "$@" >/dev/null 2>&1; then ok "$container is responding"; return 0; fi ;;
      missing) ;;
    esac
    if [ "$(docker inspect -f '{{.State.Restarting}}' "$container" 2>/dev/null)" = "true" ]; then
      warn "$container is restart-looping"
    fi
    sleep 10; waited=$((waited + 10))
  done
  docker logs --tail 50 "$container" 2>&1 | sed 's/^/      /'
  die "$container did not become healthy within ${timeout}s (last logs above)"
}

# require_running <container>
require_running() {
  [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ] \
    || die "container $1 is not running; start it on the current version first"
}

# sqlite_query <host-dir> <db-file-in-dir> <sql>
# Read-only, via a throwaway container. immutable=1 lets it read a database
# that the running app holds open (WAL mode) from a read-only mount.
sqlite_query() {
  docker run --rm -v "$1:/data:ro" alpine:3 \
    sh -c 'apk add -q --no-cache sqlite >/dev/null && sqlite3 "file:/data/$1?immutable=1" "$2"' _ "$2" "$3"
}

# cat_as_root <host-dir> <file-in-dir>   (reads files the current user may not own)
cat_as_root() {
  docker run --rm -v "$1:/d:ro" alpine:3 cat "/d/$2"
}
