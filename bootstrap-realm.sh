#!/usr/bin/env bash
set -euo pipefail

REALM=keeper
CONTAINER=keeper
ADMIN_USER=${KC_ADMIN_USER:-admin}
ADMIN_PASSWORD=${KC_ADMIN_PASSWORD:-admin}
DEMO_PASSWORD='Lab123!'

PISTACHIO_ADMIN_ORIGIN=http://localhost:5173
PISTACHIO_CLIENT_ORIGIN=http://localhost:5174
CARGA_WEB_ORIGIN=http://localhost:5273

kc() { docker exec "$CONTAINER" /opt/keycloak/bin/kcadm.sh "$@"; }
client_id() { kc get clients -r "$REALM" -q clientId="$1" --fields id --format csv --noquotes | tr -d '\r\n'; }
scope_id() { kc get client-scopes -r "$REALM" --fields id,name --format csv --noquotes | tr -d '\r' | grep ",$1\$" | cut -d, -f1; }

echo "==> Autenticar na consola de administracao"
kc config credentials --server http://localhost:8081 --realm master \
  --user "$ADMIN_USER" --password "$ADMIN_PASSWORD"

echo "==> Criar realm $REALM"
kc create realms \
  -s realm="$REALM" \
  -s enabled=true \
  -s displayName="Keeper" \
  -s sslRequired=NONE \
  -s loginWithEmailAllowed=true \
  -s duplicateEmailsAllowed=false \
  -s resetPasswordAllowed=true \
  -s verifyEmail=false \
  -s accessTokenLifespan=300 \
  -s ssoSessionIdleTimeout=1800 \
  -s ssoSessionMaxLifespan=36000

echo "==> Ligar o realm ao fornecedor de email externo"
kc update "realms/$REALM" \
  -s 'smtpServer={"host":"host.docker.internal","port":"1025","from":"keeper@keeper.local","fromDisplayName":"Keeper","ssl":"false","starttls":"false","auth":"false"}'

echo "==> Criar os resource servers (APIs)"
for api in pistachio-api carga-api; do
  kc create clients -r "$REALM" \
    -s clientId="$api" \
    -s enabled=true \
    -s publicClient=false \
    -s standardFlowEnabled=false \
    -s directAccessGrantsEnabled=false \
    -s serviceAccountsEnabled=false \
    -s secret="$api-secret"
done

PISTACHIO_API_ID=$(client_id pistachio-api)
CARGA_API_ID=$(client_id carga-api)

echo "==> Criar as permissoes como client roles"
for perm in services:read services:write scheduling:read scheduling:write scheduling:approve payments:read users:manage; do
  kc create "clients/$PISTACHIO_API_ID/roles" -r "$REALM" -s name="$perm"
done

for perm in voyages:read voyages:write surveys:write trim:calculate reports:read users:manage; do
  kc create "clients/$CARGA_API_ID/roles" -r "$REALM" -s name="$perm"
done

echo "==> Criar os papeis de negocio como realm roles compostos"
for role in pistachio-customer pistachio-mechanic pistachio-manager carga-operador carga-administrador; do
  kc create roles -r "$REALM" -s name="$role"
done

kc add-roles -r "$REALM" --rname pistachio-customer --cclientid pistachio-api \
  --rolename services:read --rolename scheduling:read --rolename scheduling:write

kc add-roles -r "$REALM" --rname pistachio-mechanic --cclientid pistachio-api \
  --rolename services:read --rolename scheduling:read --rolename scheduling:write

kc add-roles -r "$REALM" --rname pistachio-manager --cclientid pistachio-api \
  --rolename services:read --rolename services:write \
  --rolename scheduling:read --rolename scheduling:write --rolename scheduling:approve \
  --rolename payments:read --rolename users:manage

kc add-roles -r "$REALM" --rname carga-operador --cclientid carga-api \
  --rolename voyages:read --rolename surveys:write --rolename trim:calculate

kc add-roles -r "$REALM" --rname carga-administrador --cclientid carga-api \
  --rolename voyages:read --rolename voyages:write --rolename surveys:write \
  --rolename trim:calculate --rolename reports:read --rolename users:manage

echo "==> Criar os client scopes com audience mapper"
for api in pistachio-api carga-api; do
  kc create client-scopes -r "$REALM" \
    -s name="$api" \
    -s protocol=openid-connect \
    -s 'attributes={"include.in.token.scope":"true","display.on.consent.screen":"false"}'

  SCOPE_ID=$(scope_id "$api")

  kc create "client-scopes/$SCOPE_ID/protocol-mappers/models" -r "$REALM" \
    -s name="$api-audience" \
    -s protocol=openid-connect \
    -s protocolMapper=oidc-audience-mapper \
    -s "config={\"included.client.audience\":\"$api\",\"access.token.claim\":\"true\",\"id.token.claim\":\"false\"}"
done

echo "==> Criar as aplicacoes front-end"
kc create clients -r "$REALM" \
  -s clientId=pistachio-admin \
  -s name="Pistachio Admin" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=false \
  -s frontchannelLogout=true \
  -s "redirectUris=[\"$PISTACHIO_ADMIN_ORIGIN/*\"]" \
  -s "webOrigins=[\"$PISTACHIO_ADMIN_ORIGIN\"]" \
  -s "attributes={\"pkce.code.challenge.method\":\"S256\",\"post.logout.redirect.uris\":\"$PISTACHIO_ADMIN_ORIGIN/*\"}"

kc create clients -r "$REALM" \
  -s clientId=pistachio-client \
  -s name="Pistachio Client" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=false \
  -s frontchannelLogout=true \
  -s "redirectUris=[\"$PISTACHIO_CLIENT_ORIGIN/*\"]" \
  -s "webOrigins=[\"$PISTACHIO_CLIENT_ORIGIN\"]" \
  -s "attributes={\"pkce.code.challenge.method\":\"S256\",\"post.logout.redirect.uris\":\"$PISTACHIO_CLIENT_ORIGIN/*\"}"

kc create clients -r "$REALM" \
  -s clientId=carga-web \
  -s name="CARGA Web" \
  -s enabled=true \
  -s publicClient=true \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=false \
  -s frontchannelLogout=true \
  -s "redirectUris=[\"$CARGA_WEB_ORIGIN/*\"]" \
  -s "webOrigins=[\"$CARGA_WEB_ORIGIN\"]" \
  -s "attributes={\"pkce.code.challenge.method\":\"S256\",\"post.logout.redirect.uris\":\"$CARGA_WEB_ORIGIN/*\"}"

echo "==> Criar o cliente maquina-a-maquina"
kc create clients -r "$REALM" \
  -s clientId=jobs-runner \
  -s name="Jobs Runner" \
  -s enabled=true \
  -s publicClient=false \
  -s standardFlowEnabled=false \
  -s directAccessGrantsEnabled=false \
  -s serviceAccountsEnabled=true \
  -s secret=jobs-runner-secret

echo "==> Associar os audiences a cada front-end"
PISTACHIO_SCOPE=$(scope_id pistachio-api)
CARGA_SCOPE=$(scope_id carga-api)

for app in pistachio-admin pistachio-client; do
  APP_ID=$(client_id "$app")
  kc update "clients/$APP_ID/default-client-scopes/$PISTACHIO_SCOPE" -r "$REALM"
done

CARGA_WEB_ID=$(client_id carga-web)
kc update "clients/$CARGA_WEB_ID/default-client-scopes/$CARGA_SCOPE" -r "$REALM"

JOBS_ID=$(client_id jobs-runner)
kc update "clients/$JOBS_ID/default-client-scopes/$PISTACHIO_SCOPE" -r "$REALM"
kc add-roles -r "$REALM" --uusername service-account-jobs-runner \
  --cclientid pistachio-api --rolename scheduling:read

echo "==> Criar utilizadores de demonstracao"
create_user() {
  local username=$1 first=$2 last=$3 role=$4
  kc create users -r "$REALM" \
    -s username="$username" \
    -s email="$username@keeper.local" \
    -s emailVerified=true \
    -s firstName="$first" \
    -s lastName="$last" \
    -s enabled=true
  kc set-password -r "$REALM" --username "$username" --new-password "$DEMO_PASSWORD"
  kc add-roles -r "$REALM" --uusername "$username" --rolename "$role"
}

create_user gestor Ana Gestora pistachio-manager
create_user mecanico Bruno Mecanico pistachio-mechanic
create_user cliente Carla Cliente pistachio-customer
create_user operador Diogo Operador carga-operador

kc add-roles -r "$REALM" --uusername gestor --rolename carga-administrador

echo
echo "Realm $REALM criado."
echo "Consola:   http://keeper.localtest.me:8081/admin"
echo "Discovery: http://keeper.localtest.me:8081/realms/keeper/.well-known/openid-configuration"
echo "Utilizadores: gestor / mecanico / cliente / operador  --  password $DEMO_PASSWORD"
