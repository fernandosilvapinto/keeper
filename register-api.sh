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

SCOPE_UUID=$(scope_uuid "$API_ID")

# The client scope also carries this API's permissions in its own scope.
#
# This is what makes the audience mean anything. Keycloak has a built-in
# "audience resolve" mapper that puts into `aud` every client the user holds
# roles for, and a client with full scope allowed receives every role the user
# has — so a token issued to one application arrives at another application's
# API already carrying that API's permissions and its name in `aud`.
#
# Closing each client's scope (see register-spa.sh) stops that, and then a
# client only sees the permissions of the APIs whose scope it was given. Those
# permissions are attached here, next to the audience mapper, so that one
# object grants both and the two can never drift apart.
echo "==> Permissions carried by the client scope"
if kc get "clients/$API_UUID/roles" -r "$REALM" --fields id,name --format json \
     | kc_in create "client-scopes/$SCOPE_UUID/scope-mappings/clients/$API_UUID" \
         -r "$REALM" -f - >/dev/null 2>&1
then
  echo "    attached"
else
  echo "    WARNING: could not attach the permissions to the client scope." >&2
  echo "    Applications using $API_ID will authorize as if they had none." >&2
fi

echo "Resource server $API_ID ready."
