#!/bin/bash
# CloudBeaver CE 25.2.3 -> 26.2.5
# No CE release notes were found for this range. DBeaver's Docker update guide says
# to back up the workspace first and that switching the tag back is NOT a supported
# rollback: restoring the backup is the only way back.
source "$(dirname "$0")/lib.sh"

SVC=cloudbeaver
CONTAINER=cloudbeaver
IMAGE=dbeaver/cloudbeaver
TARGET=26.2.5
APP_DIR="$CONFIG/cloudbeaver"
PORT=8978

current="$(current_image $SVC $IMAGE)"; current_tag="${current#*:}"
[ -n "$current" ] || die "could not find $IMAGE in $(compose_file $SVC)"
if [ "$current_tag" = "$TARGET" ]; then ok "already on $IMAGE:$TARGET"; exit 0; fi

step "Preflight: CloudBeaver $current_tag -> $TARGET"
[ -d "$APP_DIR" ] || die "$APP_DIR does not exist"
require_running $CONTAINER
warn "no release notes available for $current_tag -> $TARGET; rollback = restoring the backup"

end_of_checks

step "Stopping CloudBeaver"
compose $SVC stop $CONTAINER

step "Backing up $APP_DIR"
backup $SVC "$APP_DIR"

step "Upgrading image"
set_image $SVC $IMAGE $TARGET
compose $SVC pull -q $CONTAINER
compose $SVC up -d $CONTAINER
wait_healthy $CONTAINER 600 curl -fs -o /dev/null "http://localhost:$PORT/"

print_rollback $SVC "$APP_DIR" $IMAGE "$current_tag"
cat <<MSG

    Log in and open one saved connection to confirm the workspace migrated.
MSG
