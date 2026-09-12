#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_args 1 $# "./export-realm.sh <realm> [output-dir]"

REALM=$1
OUT_DIR=${2:-"$(dirname "$0")/realms"}
OUT_FILE="$OUT_DIR/$REALM.json"

kc_login

if ! kc get "realms/$REALM" >/dev/null 2>&1; then
  echo "Realm '$REALM' does not exist." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

# Partial export runs against the live server, so the provider stays up. It
# deliberately leaves out users and masks client secrets, which is exactly what
# belongs in version control: the configuration, not the population.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

kc create "realms/$REALM/partial-export?exportClients=true&exportGroupsAndRoles=true" \
  -s realm="$REALM" -o > "$TMP"

if ! head -c 1 "$TMP" | grep -q '{'; then
  echo "The provider did not return a realm representation:" >&2
  head -5 "$TMP" >&2
  exit 1
fi

# Sort keys so that two exports of the same configuration produce the same file
# and a diff shows the change instead of the serialisation order.
python -c 'import json,sys; json.dump(json.load(sys.stdin), sys.stdout, indent=2, sort_keys=True); print()' \
  < "$TMP" > "$OUT_FILE" 2>/dev/null || cp "$TMP" "$OUT_FILE"

echo "Exported $REALM -> $OUT_FILE"
