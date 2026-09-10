#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_args 2 $# "./register-api.sh <api-id> <permission,permission,...>"

API_ID=$1
PERMISSIONS=$2

kc_login

echo "==> Resource server $API_ID"
if [ -z "$(client_uuid "$API_ID")" ]; then
  kc create clients -r "$REALM" \
    -s clientId="$API_ID" \
    -s name="$API_ID" \
    -s enabled=true \
    -s publicClient=false \
    -s standardFlowEnabled=false \
    -s implicitFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s serviceAccountsEnabled=false
else
  echo "    already exists, kept"
fi

API_UUID=$(client_uuid "$API_ID")

echo "==> Permissions"
while read -r permission; do
  if kc create "clients/$API_UUID/roles" -r "$REALM" -s name="$permission" 2>/dev/null; then
    echo "    $permission"
  else
    echo "    $permission (already exists)"
  fi
done < <(split_list "$PERMISSIONS")

echo "==> Client scope $API_ID with audience mapper"
if [ -z "$(scope_uuid "$API_ID")" ]; then
  kc create client-scopes -r "$REALM" \
    -s name="$API_ID" \
    -s protocol=openid-connect \
    -s 'attributes={"include.in.token.scope":"true","display.on.consent.screen":"false"}'

  SCOPE_UUID=$(scope_uuid "$API_ID")

  kc create "client-scopes/$SCOPE_UUID/protocol-mappers/models" -r "$REALM" \
    -s name="$API_ID-audience" \
    -s protocol=openid-connect \
    -s protocolMapper=oidc-audience-mapper \
    -s "config={\"included.client.audience\":\"$API_ID\",\"access.token.claim\":\"true\",\"id.token.claim\":\"false\"}"
else
  echo "    already exists, kept"
fi

echo "Resource server $API_ID ready."
