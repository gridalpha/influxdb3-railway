# InfluxDB 3 Core for Railway.
#
# The published image runs as the unprivileged `influxdb3` user and provides no
# hook for preparing a mounted volume or for materialising the offline admin
# token file that `--admin-token-file` wants. This layer adds one wrapper that
# does both and then drops straight back to `influxdb3`.
#
# The wrapper replaces the *launcher* the image's CMD resolves through rather
# than declaring an ENTRYPOINT: declaring one would reset the inherited
# CMD ["serve"] to empty.
FROM quay.io/influxdb/influxdb3-core:latest

USER root

COPY influxdb/entrypoint.sh /usr/bin/railway-entrypoint.sh

RUN set -eux; \
    sh -n /usr/bin/railway-entrypoint.sh; \
    command -v setpriv; \
    mv /usr/bin/entrypoint.sh /usr/bin/entrypoint.real.sh; \
    mv /usr/bin/railway-entrypoint.sh /usr/bin/entrypoint.sh; \
    chmod 0755 /usr/bin/entrypoint.sh /usr/bin/entrypoint.real.sh
