#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_args 2 $# "./set-realm-theme.sh <realm> <login-theme> [account-theme] [email-theme]"

TARGET_REALM=$1
LOGIN_THEME=$2
ACCOUNT_THEME=${3:-}
EMAIL_THEME=${4:-}

kc_login

ARGS=(-s "loginTheme=$LOGIN_THEME")
[ -n "$ACCOUNT_THEME" ] && ARGS+=(-s "accountTheme=$ACCOUNT_THEME")
[ -n "$EMAIL_THEME" ] && ARGS+=(-s "emailTheme=$EMAIL_THEME")

echo "==> Themes for realm $TARGET_REALM"
kc update "realms/$TARGET_REALM" "${ARGS[@]}"

echo "    login: $LOGIN_THEME"
[ -n "$ACCOUNT_THEME" ] && echo "    account: $ACCOUNT_THEME"
[ -n "$EMAIL_THEME" ] && echo "    email: $EMAIL_THEME"

echo
echo "The theme must exist under the provider's themes directory."
