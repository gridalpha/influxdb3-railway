#!/bin/sh
# Renders the Caddyfile, derives the basic-auth bcrypt hash, then execs Caddy.
set -eu

: "${PORT:=8080}"
export PORT

: "${GATEWAY_USERNAME:=admin}"
export GATEWAY_USERNAME

# A ${{explorer.RAILWAY_PRIVATE_DOMAIN}} reference renders empty until that
# service owns a deployment, so a proxy created in the same batch would
# otherwise bake `http://:8080` and 502 until something restarted it.
: "${EXPLORER_UPSTREAM:=}"
case "$EXPLORER_UPSTREAM" in
  ""|":"*) EXPLORER_UPSTREAM="explorer.railway.internal:8080" ;;
esac
export EXPLORER_UPSTREAM

if [ -n "${GATEWAY_PASSWORD_HASH:-}" ]; then
  :
elif [ -n "${GATEWAY_PASSWORD:-}" ]; then
  GATEWAY_PASSWORD_HASH=$(/usr/bin/caddy.real hash-password --plaintext "$GATEWAY_PASSWORD")
else
  echo "gateway: set GATEWAY_PASSWORD (or GATEWAY_PASSWORD_HASH) — refusing to serve Explorer unauthenticated" >&2
  exit 1
fi
export GATEWAY_PASSWORD_HASH
unset GATEWAY_PASSWORD

cp /etc/caddy/Caddyfile.template /etc/caddy/Caddyfile
/usr/bin/caddy.real validate --config /etc/caddy/Caddyfile --adapter caddyfile

echo "gateway: port=$PORT upstream=$EXPLORER_UPSTREAM user=$GATEWAY_USERNAME"

exec /usr/bin/caddy.real "$@"
