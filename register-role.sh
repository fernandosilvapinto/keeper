#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_args 2 $# "./register-role.sh <role> <api-id>:<permission>,... [default]"

ROLE=$1
GRANTS=$2
AS_DEFAULT=${3:-}

kc_login

echo "==> Role $ROLE"
if kc create roles -r "$REALM" -s name="$ROLE" 2>/dev/null; then
  echo "    created"
else
  echo "    already exists, kept"
fi

echo "==> Associated permissions"
APIS=$(split_list "$GRANTS" | cut -d: -f1 | sort -u)

for api in $APIS; do
  ARGS=()
  while read -r grant; do
    case "$grant" in
      "$api":*) ARGS+=(--rolename "${grant#*:}") ;;
    esac
  done < <(split_list "$GRANTS")

  if [ ${#ARGS[@]} -gt 0 ]; then
    kc add-roles -r "$REALM" --rname "$ROLE" --cclientid "$api" "${ARGS[@]}"
    echo "    $api -> ${#ARGS[@]} permissions"
  fi
done

if [ "$AS_DEFAULT" = "default" ]; then
  echo "==> Granting it to every new user in the realm"
  kc add-roles -r "$REALM" --rname "default-roles-$REALM" --rolename "$ROLE"
fi

echo "Role $ROLE ready."
