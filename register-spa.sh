#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_args 3 $# "./register-spa.sh <client-id> <origin> <api-id,api-id,...>"

CLIENT_ID=$1
ORIGIN=${2%/}
APIS=$3

kc_login

echo "==> Application $CLIENT_ID at $ORIGIN"
if [ -z "$(client_uuid "$CLIENT_ID")" ]; then
  kc create clients -r "$REALM" \
    -s clientId="$CLIENT_ID" \
    -s name="$CLIENT_ID" \
    -s enabled=true \
    -s publicClient=true \
    -s standardFlowEnabled=true \
    -s implicitFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s frontchannelLogout=true \
    -s "redirectUris=[\"$ORIGIN/*\"]" \
    -s "webOrigins=[\"$ORIGIN\"]" \
    -s "attributes={\"pkce.code.challenge.method\":\"S256\",\"post.logout.redirect.uris\":\"$ORIGIN/*\"}"
else
  echo "    already exists, updating origins"
  CLIENT_UUID=$(client_uuid "$CLIENT_ID")
  kc update "clients/$CLIENT_UUID" -r "$REALM" \
    -s "redirectUris=[\"$ORIGIN/*\"]" \
    -s "webOrigins=[\"$ORIGIN\"]" \
    -s "attributes={\"pkce.code.challenge.method\":\"S256\",\"post.logout.redirect.uris\":\"$ORIGIN/*\"}"
fi

CLIENT_UUID=$(client_uuid "$CLIENT_ID")

echo "==> Audiences"
while read -r api; do
  SCOPE_UUID=$(scope_uuid "$api")
  if [ -z "$SCOPE_UUID" ]; then
    echo "    $api does not exist. Run ./register-api.sh $api first" >&2
    exit 1
  fi
  kc update "clients/$CLIENT_UUID/default-client-scopes/$SCOPE_UUID" -r "$REALM"
  echo "    $api"
done < <(split_list "$APIS")

echo "Application $CLIENT_ID ready."
