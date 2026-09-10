#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage:"
  echo "  $0 --world-dir <path> --host <hostname>          # Valheim 1.0+ world"
  echo "  $0 --db <path> --fwl <path> --host <hostname>    # pre-1.0 world"
  echo ""
  echo "Upload world files to the Valheim server volume."
  echo ""
  echo "  --world-dir  Path to a world's save directory (Valheim 1.0+ format:"
  echo "               contains _main.<n>.db2/.fwl2/.chunks/.ok plus *.chunk files)"
  echo "  --db         Path to the .db world save file (pre-1.0 format)"
  echo "  --fwl        Path to the .fwl world metadata file (pre-1.0 format)"
  echo "  --host       Server hostname or IP"
  exit 1
}

WORLD_DIR_PATH=""
DB_PATH=""
FWL_PATH=""
HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --world-dir) WORLD_DIR_PATH="$2"; shift 2 ;;
    --db)  DB_PATH="$2"; shift 2 ;;
    --fwl) FWL_PATH="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$HOST" ]]; then
  echo "Error: --host is required."
  usage
fi

if [[ -n "$WORLD_DIR_PATH" && ( -n "$DB_PATH" || -n "$FWL_PATH" ) ]]; then
  echo "Error: Use either --world-dir (1.0+ format) or --db/--fwl (pre-1.0 format), not both."
  usage
fi

DEST="/mnt/valheim-world/worlds_local"

if [[ -n "$WORLD_DIR_PATH" ]]; then
  # Valheim 1.0+ format: a directory of chunked save files
  if [[ ! -d "$WORLD_DIR_PATH" ]]; then
    echo "Error: World directory not found: $WORLD_DIR_PATH"
    exit 1
  fi

  # Sanity-check it actually looks like a world save, not an arbitrary folder
  if ! find "$WORLD_DIR_PATH" -maxdepth 1 -name "_main.*.fwl2" -print -quit | grep -q .; then
    echo "Error: No _main.*.fwl2 file found in $WORLD_DIR_PATH — doesn't look like a Valheim world directory."
    exit 1
  fi

  WORLD_NAME=$(basename "$WORLD_DIR_PATH")

  # Refuse to merge into an existing remote world — a partial overwrite would
  # leave stale chunks from whatever's already there mixed in with the upload.
  if ssh "root@${HOST}" "[ -e '${DEST}/${WORLD_NAME}' ]" 2>/dev/null; then
    echo "Error: '${DEST}/${WORLD_NAME}' already exists on $HOST."
    echo "Remove it on the server first, or upload under a different world name."
    exit 1
  fi

  echo "Uploading world '$WORLD_NAME' (1.0+ format) to $HOST..."
  scp -r "$WORLD_DIR_PATH" "root@${HOST}:${DEST}/"
elif [[ -n "$DB_PATH" && -n "$FWL_PATH" ]]; then
  # Pre-1.0 format: flat .db/.fwl pair
  if [[ ! -f "$DB_PATH" ]]; then
    echo "Error: DB file not found: $DB_PATH"
    exit 1
  fi
  if [[ ! -f "$FWL_PATH" ]]; then
    echo "Error: FWL file not found: $FWL_PATH"
    exit 1
  fi

  if [[ "$DB_PATH" != *.db ]]; then
    echo "Error: DB file must have .db extension: $DB_PATH"
    exit 1
  fi
  if [[ "$FWL_PATH" != *.fwl ]]; then
    echo "Error: FWL file must have .fwl extension: $FWL_PATH"
    exit 1
  fi

  DB_NAME=$(basename "$DB_PATH" .db)
  FWL_NAME=$(basename "$FWL_PATH" .fwl)
  if [[ "$DB_NAME" != "$FWL_NAME" ]]; then
    echo "Error: World names don't match: '$DB_NAME' (.db) vs '$FWL_NAME' (.fwl)"
    exit 1
  fi
  WORLD_NAME="$DB_NAME"

  echo "Uploading world '$WORLD_NAME' (pre-1.0 format) to $HOST..."
  scp "$DB_PATH" "$FWL_PATH" "root@${HOST}:${DEST}/"
else
  echo "Error: Provide either --world-dir, or both --db and --fwl."
  usage
fi

echo "Upload complete."
echo ""
echo "Next steps:"
echo "  1. Set valheim_world_name to '$WORLD_NAME' in terraform/main.tf (if different from current)"
echo "  2. Open a PR to trigger a deploy (or use Manual Deploy)"
echo "  3. Merge to activate the world"
