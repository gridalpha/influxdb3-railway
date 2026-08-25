# Authenticating gateway for InfluxDB 3 Explorer.
#
# Explorer has no login of its own, so it never gets a public domain. This
# service does, and puts HTTP basic auth in front of it. Basic auth (rather than
# a bearer token) is what the browser replays on Explorer's own same-origin
# XHRs, so the whole UI works behind one prompt.
#
# The bcrypt hash cannot be expressed as a Railway variable — no `${{…}}`
# expression computes one — so it is derived here at boot from the operator's
# plaintext password.
FROM caddy:2-alpine

COPY gateway/Caddyfile /etc/caddy/Caddyfile.template
COPY gateway/entrypoint.sh /usr/local/bin/railway-entrypoint.sh

RUN set -eux; \
    sh -n /usr/local/bin/railway-entrypoint.sh; \
    mv /usr/bin/caddy /usr/bin/caddy.real; \
    mv /usr/local/bin/railway-entrypoint.sh /usr/bin/caddy; \
    chmod 0755 /usr/bin/caddy /usr/bin/caddy.real
