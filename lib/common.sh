#!/usr/bin/env bash

REALM=${KEEPER_REALM:-keeper}
CONTAINER=${KEEPER_CONTAINER:-keeper}
SERVER=${KEEPER_SERVER:-http://localhost:8081}
ADMIN_USER=${KC_ADMIN_USER:-admin}
ADMIN_PASSWORD=${KC_ADMIN_PASSWORD:-admin}

require_container() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    echo "Container '$CONTAINER' is not running. Start it with: docker compose up -d" >&2
    exit 1
  fi
}

kc() {
  MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' \
    docker exec "$CONTAINER" /opt/keycloak/bin/kcadm.sh "$@"
}

kc_login() {
  require_container

  local attempts=${KEEPER_LOGIN_ATTEMPTS:-30}
  local delay=${KEEPER_LOGIN_DELAY:-2}
  local attempt=1

  while [ "$attempt" -le "$attempts" ]; do
    if kc config credentials --server "$SERVER" --realm master \
         --user "$ADMIN_USER" --password "$ADMIN_PASSWORD" >/dev/null 2>&1; then
      return 0
    fi

    if [ "$attempt" -eq 1 ]; then
      echo "Waiting for '$CONTAINER' to accept connections on $SERVER ..." >&2
    fi

    sleep "$delay"
    attempt=$((attempt + 1))
  done

  echo >&2
  echo "Gave up after $attempts attempts. Last error:" >&2
  kc config credentials --server "$SERVER" --realm master \
    --user "$ADMIN_USER" --password "$ADMIN_PASSWORD" >&2 || true
  echo >&2
  echo "Check: docker ps  |  docker logs $CONTAINER --tail 30" >&2
  exit 1
}

client_uuid() {
  kc get clients -r "$REALM" -q clientId="$1" --fields id --format csv --noquotes | tr -d '\r\n'
}

scope_uuid() {
  kc get client-scopes -r "$REALM" --fields id,name --format csv --noquotes \
    | tr -d '\r' | grep ",$1\$" | cut -d, -f1
}

require_args() {
  local expected=$1 actual=$2 usage=$3
  if [ "$actual" -lt "$expected" ]; then
    echo "Usage: $usage" >&2
    exit 1
  fi
}

split_list() {
  echo "$1" | tr ',' '\n' | sed '/^[[:space:]]*$/d' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}
