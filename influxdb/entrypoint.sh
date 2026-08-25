#!/bin/sh
# Runs as root, prepares state, then execs the image's own entrypoint as the
# unprivileged `influxdb3` user.
set -eu

RUN_USER=influxdb3
DATA_ROOT=${INFLUXDB3_RAILWAY_DATA_ROOT:-/var/lib/influxdb3}

RUN_UID=$(getent passwd "$RUN_USER" | cut -d: -f3)
RUN_GID=$(getent passwd "$RUN_USER" | cut -d: -f4)
RUN_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
[ -n "$RUN_UID" ] || { echo "railway-entrypoint: user $RUN_USER missing" >&2; exit 1; }

# Railway mounts volumes root-owned. Hand the mount to the runtime user before
# dropping privileges, or every write fails with EACCES.
mkdir -p "$DATA_ROOT"
chown "$RUN_UID:$RUN_GID" "$DATA_ROOT"
if [ -n "$RUN_HOME" ] && [ "$RUN_HOME" != "/" ]; then
  mkdir -p "$RUN_HOME/.influxdb3"
  chown -R "$RUN_UID:$RUN_GID" "$RUN_HOME"
fi

# A node id is a prefix inside the object store, so it must be stable across
# deploys. Railway gives each container a fresh hostname, which is exactly the
# wrong thing to derive it from.
: "${INFLUXDB3_NODE_ID:=node0}"
export INFLUXDB3_NODE_ID

# Reach the private network. The default 0.0.0.0 bind is unroutable from a peer
# service, and Railway's private network carries IPv6 between services.
: "${INFLUXDB3_HTTP_BIND_ADDR:=[::]:8181}"
export INFLUXDB3_HTTP_BIND_ADDR

# `--object-store s3` addresses a custom endpoint path-style, which is the only
# style Railway's managed bucket answers CORS on and the one it always accepts.
: "${INFLUXDB3_OBJECT_STORE:=s3}"
export INFLUXDB3_OBJECT_STORE

# Railway's bucket reports region `auto`; the endpoint ignores the signing
# region, but the S3 client refuses to start without one.
: "${AWS_DEFAULT_REGION:=us-east-1}"
export AWS_DEFAULT_REGION

# The health check and the uptime ping are the only two routes the anonymous
# Railway prober may reach; everything else stays token-authenticated.
: "${INFLUXDB3_DISABLE_AUTHZ:=health,ping}"
export INFLUXDB3_DISABLE_AUTHZ

# Materialise the offline admin token file. InfluxDB reads it only while no
# token exists, so this is idempotent — later boots ignore it.
if [ -n "${INFLUXDB3_ADMIN_TOKEN:-}" ]; then
  TOKEN_FILE=${INFLUXDB3_ADMIN_TOKEN_FILE:-$DATA_ROOT/admin-token.json}
  case "$INFLUXDB3_ADMIN_TOKEN" in
    apiv3_*) ;;
    *) echo "railway-entrypoint: INFLUXDB3_ADMIN_TOKEN must begin with apiv3_" >&2; exit 1 ;;
  esac
  mkdir -p "$(dirname "$TOKEN_FILE")"
  printf '{"token":"%s","name":"_admin"}\n' "$INFLUXDB3_ADMIN_TOKEN" > "$TOKEN_FILE"
  chmod 0600 "$TOKEN_FILE"
  chown "$RUN_UID:$RUN_GID" "$TOKEN_FILE"
  export INFLUXDB3_ADMIN_TOKEN_FILE="$TOKEN_FILE"
  # The server reads the file, not the variable. Keep the raw token out of the
  # server process environment so nothing can echo it into the deploy log.
  unset INFLUXDB3_ADMIN_TOKEN
  echo "railway-entrypoint: admin token file at $TOKEN_FILE"
else
  echo "railway-entrypoint: INFLUXDB3_ADMIN_TOKEN unset — server will start with no admin token" >&2
fi

echo "railway-entrypoint: node=$INFLUXDB3_NODE_ID bind=$INFLUXDB3_HTTP_BIND_ADDR store=$INFLUXDB3_OBJECT_STORE bucket=${INFLUXDB3_BUCKET:-unset}"

if [ -n "$RUN_HOME" ]; then
  export HOME="$RUN_HOME"
fi

exec setpriv --reuid="$RUN_UID" --regid="$RUN_GID" --init-groups /usr/bin/entrypoint.real.sh "$@"
