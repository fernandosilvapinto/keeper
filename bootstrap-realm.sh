#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

SMTP_HOST=${KEEPER_SMTP_HOST:-host.docker.internal}
SMTP_PORT=${KEEPER_SMTP_PORT:-1025}
SMTP_FROM=${KEEPER_SMTP_FROM:-keeper@keeper.local}

kc_login

echo "==> Realm $REALM"
kc create realms \
  -s realm="$REALM" \
  -s enabled=true \
  -s displayName="Keeper" \
  -s sslRequired=NONE \
  -s loginWithEmailAllowed=true \
  -s duplicateEmailsAllowed=false \
  -s resetPasswordAllowed=true \
  -s verifyEmail=false \
  -s registrationAllowed=false \
  -s bruteForceProtected=true \
  -s accessTokenLifespan=300 \
  -s accessCodeLifespan=60 \
  -s ssoSessionIdleTimeout=1800 \
  -s ssoSessionMaxLifespan=36000

echo "==> Mail provider"
kc update "realms/$REALM" \
  -s "smtpServer={\"host\":\"$SMTP_HOST\",\"port\":\"$SMTP_PORT\",\"from\":\"$SMTP_FROM\",\"fromDisplayName\":\"Keeper\",\"ssl\":\"false\",\"starttls\":\"false\",\"auth\":\"false\"}"

echo "==> Auditing"
kc update "realms/$REALM/events/config" \
  -s eventsEnabled=true \
  -s adminEventsEnabled=true \
  -s adminEventsDetailsEnabled=true \
  -s 'enabledEventTypes=["LOGIN","LOGIN_ERROR","LOGOUT","CODE_TO_TOKEN","CODE_TO_TOKEN_ERROR","REFRESH_TOKEN","REFRESH_TOKEN_ERROR","CLIENT_LOGIN","CLIENT_LOGIN_ERROR","UPDATE_PASSWORD","RESET_PASSWORD","SEND_RESET_PASSWORD"]'

echo
echo "Realm $REALM created."
echo "Console:   http://keeper.localtest.me:8081/admin"
echo "Discovery: http://keeper.localtest.me:8081/realms/$REALM/.well-known/openid-configuration"
echo
echo "Next: ./register-api.sh, ./register-spa.sh, ./register-role.sh"
