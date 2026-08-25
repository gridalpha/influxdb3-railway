#!/bin/sh
# Runs as root, writes the connection config, then execs Explorer's own
# entrypoint as the unprivileged `influxui` user.
set -eu

RUN_USER=influxui
CONFIG_DIR=/app-root/config
DB_DIR=$(dirname "${DATABASE_URL:-/db/sqlite.db}")

RUN_UID=$(getent passwd "$RUN_USER" | cut -d: -f3)
RUN_GID=$(getent passwd "$RUN_USER" | cut -d: -f4)
RUN_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
[ -n "$RUN_UID" ] || { echo "railway-entrypoint: user $RUN_USER missing" >&2; exit 1; }

# A ${{influxdb.RAILWAY_PRIVATE_DOMAIN}} reference renders empty until that
# service owns a deployment, so a first boot in a fresh project would otherwise
# bake `http://:8181`. Default on the value's shape, not on it being unset.
: "${INFLUXDB3_HOST:=}"
case "$INFLUXDB3_HOST" in
  ""|":"*|"http://:"*|"https://:"*) INFLUXDB3_HOST="http://influxdb.railway.internal:8181" ;;
  http://*|https://*) ;;
  *) INFLUXDB3_HOST="http://$INFLUXDB3_HOST" ;;
esac

: "${INFLUXDB3_DATABASE:=mydb}"
: "${INFLUXDB3_SERVER_NAME:=InfluxDB 3 Core}"

mkdir -p "$CONFIG_DIR" "$DB_DIR"
export INFLUXDB3_HOST INFLUXDB3_DATABASE INFLUXDB3_SERVER_NAME

# Explorer reads this once at startup to pre-fill the connection, so a deployer
# never has to paste a token to get a working UI. Written with node rather than
# printf so a quote in any value cannot produce invalid JSON.
node -e '
const fs = require("fs");
fs.writeFileSync(process.argv[1], JSON.stringify({
  DEFAULT_INFLUX_SERVER: process.env.INFLUXDB3_HOST,
  DEFAULT_INFLUX_DATABASE: process.env.INFLUXDB3_DATABASE,
  DEFAULT_API_TOKEN: process.env.INFLUXDB3_ADMIN_TOKEN || "",
  DEFAULT_SERVER_NAME: process.env.INFLUXDB3_SERVER_NAME,
}, null, 2) + "\n");
' "$CONFIG_DIR/config.json"

chmod 0600 "$CONFIG_DIR/config.json"
chown -R "$RUN_UID:$RUN_GID" "$CONFIG_DIR" "$DB_DIR"
if [ -n "$RUN_HOME" ] && [ "$RUN_HOME" != "/" ]; then
  mkdir -p "$RUN_HOME"
  chown -R "$RUN_UID:$RUN_GID" "$RUN_HOME"
fi

echo "railway-entrypoint: explorer -> $INFLUXDB3_HOST db=$INFLUXDB3_DATABASE args=$*"

if [ -n "$RUN_HOME" ]; then
  export HOME="$RUN_HOME"
fi

exec su-exec "$RUN_UID:$RUN_GID" /app-root/entrypoint.real.sh "$@"
