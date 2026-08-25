# InfluxDB 3 Explorer for Railway.
#
# Explorer ships no login of its own — upstream expects it to be reachable only
# from a trusted network — so on Railway it stays private and the `gateway`
# service authenticates in front of it.
#
# This layer adds a wrapper that writes the pre-configured connection file the
# image reads from /app-root/config and hands the mounted /db volume to the
# runtime user. It replaces the launcher rather than declaring an ENTRYPOINT.
FROM influxdata/influxdb3-ui:latest

USER root

COPY explorer/entrypoint.sh /app-root/railway-entrypoint.sh

# The base is Alpine, whose BusyBox `setpriv` is capabilities-only and rejects
# --reuid. su-exec is the Alpine equivalent of gosu.
RUN set -eux; \
    sh -n /app-root/railway-entrypoint.sh; \
    apk add --no-cache su-exec; \
    command -v su-exec; \
    mv /app-root/entrypoint.sh /app-root/entrypoint.real.sh; \
    mv /app-root/railway-entrypoint.sh /app-root/entrypoint.sh; \
    chmod 0755 /app-root/entrypoint.sh /app-root/entrypoint.real.sh

CMD ["--mode=admin"]
