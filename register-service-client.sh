#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_args 2 $# "./register-service-client.sh <client-id> <realm-management-role,...> [secret]"

CLIENT_ID=$1
ROLES=$2
SECRET=${3:-}

kc_login

echo "==> Service client $CLIENT_ID"
if [ -z "$(client_uuid "$CLIENT_ID")" ]; then
  ARGS=(-s clientId="$CLIENT_ID" -s name="$CLIENT_ID" -s enabled=true
        -s publicClient=false -s standardFlowEnabled=false
        -s implicitFlowEnabled=false -s directAccessGrantsEnabled=false
        -s serviceAccountsEnabled=true)
  if [ -n "$SECRET" ]; then
    ARGS+=(-s secret="$SECRET")
  fi
  kc create clients -r "$REALM" "${ARGS[@]}"
else
  echo "    already exists, kept"
fi

echo "==> Realm management roles"
ARGS=()
while read -r role; do
  ARGS+=(--rolename "$role")
  echo "    $role"
done < <(split_list "$ROLES")

kc add-roles -r "$REALM" \
  --uusername "service-account-$CLIENT_ID" \
  --cclientid realm-management \
  "${ARGS[@]}"

CLIENT_UUID=$(client_uuid "$CLIENT_ID")
VALUE=$(kc get "clients/$CLIENT_UUID/client-secret" -r "$REALM" --fields value --format csv --noquotes | tr -d '\r\n')

echo
echo "Service client $CLIENT_ID ready."
echo "Client secret: $VALUE"
echo
echo "This client can act on the realm without a user. Grant it the narrowest"
echo "set of roles the task needs and keep the secret out of source control."
