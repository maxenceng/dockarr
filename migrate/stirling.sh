#!/bin/bash
# Stirling-PDF 1.5.0 -> 3.3.0
# v2: full UI rewrite, "back up your config directory before deploying".
#     Free for up to 5 users; existing installs are grandfathered.
# v3: new Processor/automation system, free OAuth SSO.
# The env vars used in the compose file and the `pgrep -f app.jar` healthcheck still work in 3.3.0.
source "$(dirname "$0")/lib.sh"

SVC=stirling
CONTAINER=stirlingpdf   # compose service key is "stirling" ($SVC)
IMAGE=frooodle/s-pdf
TARGET=3.3.0
APP_DIR="$CONFIG/stirling"

current="$(current_image $SVC $IMAGE)"; current_tag="${current#*:}"
[ -n "$current" ] || die "could not find $IMAGE in $(compose_file $SVC)"
if [ "$current_tag" = "$TARGET" ]; then ok "already on $IMAGE:$TARGET"; exit 0; fi

step "Preflight: Stirling-PDF $current_tag -> $TARGET"
[ -d "$APP_DIR" ] || die "$APP_DIR does not exist"
require_running $CONTAINER
ok "no breaking config changes apply to this compose file"

end_of_checks

step "Stopping Stirling-PDF"
compose $SVC stop $SVC

step "Backing up $APP_DIR"
backup $SVC "$APP_DIR"

step "Upgrading image"
set_image $SVC $IMAGE $TARGET
compose $SVC pull -q $SVC
compose $SVC up -d $SVC
wait_healthy $CONTAINER 600

print_rollback $SVC "$APP_DIR" $IMAGE "$current_tag"
cat <<MSG

    Check the new UI loads through the tailnet URL and run one tool (e.g. merge)
    to confirm conversions work. The French UI language (LANGS=fr_FR) should still apply.
MSG
