#!/bin/bash
# n8n 1.123.x -> 2.49.1 -> 3.3.0 (two hops, with a pause in between)
# Breaking changes: https://docs.n8n.io/2-0-breaking-changes/ and the n8n@3.0.0 release notes.
# Re-running the script resumes: if you are already on 2.x it only does the second hop.
source "$(dirname "$0")/lib.sh"

SVC=n8n
IMAGE=n8nio/n8n
HOP1=2.49.1
HOP2=3.3.0
APP_DIR="$CONFIG/n8n"
DB=database.sqlite

current="$(current_image $SVC $IMAGE)"; current_tag="${current#*:}"
[ -n "$current" ] || die "could not find $IMAGE in $(compose_file $SVC)"
if [ "$current_tag" = "$HOP2" ]; then ok "already on $IMAGE:$HOP2"; exit 0; fi

step "Preflight: n8n $current_tag -> $HOP1 -> $HOP2"

case "$current_tag" in
  1.*) ok "starting from 1.x: both hops will run" ;;
  2.*) ok "already on 2.x: only the $HOP2 hop will run" ;;
  *)   die "unexpected current version $current_tag" ;;
esac

[ -f "$APP_DIR/$DB" ] || die "$APP_DIR/$DB not found (this script assumes the default SQLite database)"
[ -f "$APP_DIR/config" ] && ok "encryption key file present ($APP_DIR/config); it goes into the backup" \
  || warn "$APP_DIR/config not found: make sure you know where N8N_ENCRYPTION_KEY is kept"

# Scan stored workflows for things the 2.0 / 3.0 releases changed or removed.
scan() { # scan <message> <sql LIKE pattern>...
  local msg="$1"; shift
  local where="" p
  for p in "$@"; do where+="${where:+ OR }nodes LIKE '$p'"; done
  local hits
  hits="$(sqlite_query "$APP_DIR" "$DB" "SELECT name FROM workflow_entity WHERE $where ORDER BY name;")" \
    || die "could not read $APP_DIR/$DB"
  if [ -n "$hits" ]; then
    warn "$msg"
    sed 's/^/        - /' <<< "$hits"
  fi
}

step "Scanning workflows"
scan "Execute Command / Local File Trigger nodes are disabled by default in 2.0 (re-enable with NODES_EXCLUDE='[]'):" \
  '%"n8n-nodes-base.executeCommand"%' '%"n8n-nodes-base.localFileTrigger"%'
scan "File nodes can only touch ~/.n8n-files by default in 2.0 (N8N_RESTRICT_FILE_ACCESS_TO):" \
  '%"n8n-nodes-base.readWriteFile"%' '%"n8n-nodes-base.readBinaryFile"%' \
  '%"n8n-nodes-base.readBinaryFiles"%' '%"n8n-nodes-base.writeBinaryFile"%'
scan "Uses \$env; env access in nodes is blocked by default in 2.0 (N8N_BLOCK_ENV_ACCESS_IN_NODE=false to allow):" \
  '%$env%'
scan "Uses \$evaluateExpression() in a Code node; it no longer works with task runners in 2.0:" \
  '%$evaluateExpression%'
scan "Python Code nodes; the Pyodide runtime is removed in 2.0 (native Python needs external runners):" \
  '%"language":"python%'
scan "Start node; removed in 2.0 (replace with Manual Trigger):" \
  '%"n8n-nodes-base.start"%'
scan "Nodes removed in 2.0 (Spontit, crowd.dev, Kitemaker, Automizy):" \
  '%"n8n-nodes-base.spontit"%' '%"n8n-nodes-base.crowdDev"%' \
  '%"n8n-nodes-base.kitemaker"%' '%"n8n-nodes-base.automizy"%'
scan "Execute Sub-workflow nodes; in 2.0 the caller receives the sub-workflow's output, not its input:" \
  '%"n8n-nodes-base.executeWorkflow"%'
scan "LangChain Code node; removed in 3.0:" \
  '%"@n8n/n8n-nodes-langchain.code"%'
scan "Edit Image nodes; versions 1-1.1 are removed in 3.0 (3.0 migrates them, check the result):" \
  '%"n8n-nodes-base.editImage"%'

end_of_checks

# hop <tag>: stop, back up, bump, start, wait
hop() {
  local tag="$1" from
  from="$(current_image $SVC $IMAGE)"; from="${from#*:}"

  step "Stopping n8n ($from)"
  compose $SVC stop $SVC

  step "Backing up $APP_DIR"
  backup "$SVC-$from" "$APP_DIR"

  step "Upgrading to $tag"
  set_image $SVC $IMAGE "$tag"
  compose $SVC pull -q $SVC
  compose $SVC up -d $SVC

  wait_healthy $SVC 900 docker exec $SVC node -e \
    "fetch('http://localhost:5678/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
  print_rollback $SVC "$APP_DIR" $IMAGE "$from"
}

case "$current_tag" in
  1.*)
    hop $HOP1
    cat <<EOF

    n8n is now on $HOP1. Before continuing:
      - Open n8n: the Active toggle is now Publish/Unpublish; check your workflows are still published
      - Open the v3 migration report in the n8n UI and fix what it flags
      - Run the workflows flagged in the preflight scan above
EOF
    if ! confirm "Continue with the $HOP2 hop now? (no = stop here, re-run later to resume)"; then
      info "stopped on $HOP1; re-run this script to do the $HOP2 hop"
      exit 0
    fi
    ;;
esac

hop $HOP2
cat <<EOF

    n8n is now on $HOP2.
      - Check recent executions for failures
      - Releases now use the stable/beta tags instead of latest/next; keep pinning exact versions
EOF
