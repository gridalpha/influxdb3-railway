# InfluxDB 3 Core on Railway

Deployment sources for a production-shaped [InfluxDB 3 Core](https://github.com/influxdata/influxdb)
stack on [Railway](https://railway.com): the database itself, the official
[InfluxDB 3 Explorer](https://docs.influxdata.com/influxdb3/explorer/) web UI, and a Caddy gateway
that authenticates access to Explorer.

Three services build from this one repository. Each selects its Dockerfile with the
`RAILWAY_DOCKERFILE_PATH` environment variable, and the build context is the repository root — so
every `COPY` is written from the root, not from beside the Dockerfile.

| Directory | Service | Base image | Public |
|---|---|---|---|
| `influxdb/` | time-series database, HTTP API on 8181 | `quay.io/influxdb/influxdb3-core:latest` | yes — token-authenticated API |
| `explorer/` | web UI, HTTP on 8080 | `influxdata/influxdb3-ui:latest` | no |
| `gateway/` | Caddy, HTTP basic auth in front of Explorer | `caddy:2-alpine` | yes |

## Why each layer exists

**`influxdb/`** — the published image runs as the unprivileged `influxdb3` user and offers no hook
for preparing a mounted volume or for materialising the JSON file that `--admin-token-file` reads.
The wrapper does both as root, then drops back to `influxdb3` with `setpriv`. It also defaults the
node id, the listen address (`[::]:8181`, so peer services on Railway's IPv6 private network can
reach it), the object store and `--disable-authz health,ping`, which is what lets Railway's
anonymous health prober through while every data route stays token-authenticated.

**`explorer/`** — Explorer reads a pre-configured connection from `/app-root/config/config.json`.
Writing it at boot from Railway variables means a deployer never has to paste a server URL or an API
token to get a working UI. The wrapper also hands the mounted `/db` volume to the `influxui` user.

**`gateway/`** — Explorer ships no login of its own; upstream expects it to sit on a trusted
network. On Railway it stays private and this service takes the public domain. Basic auth is
deliberate: the browser replays it on Explorer's own same-origin requests, which a bearer token
would not. The bcrypt hash is derived here at boot, because no Railway variable expression can
compute one.

Each wrapper replaces the *launcher* its base image's `CMD` resolves through rather than declaring a
new `ENTRYPOINT` — declaring one would reset the inherited `CMD` to empty.

## Environment variables

### `influxdb`

| Variable | Default | Purpose |
|---|---|---|
| `INFLUXDB3_ADMIN_TOKEN` | — | operator token, must begin with `apiv3_`. Written to the offline admin token file and adopted on first boot only |
| `INFLUXDB3_BUCKET` | — | object storage bucket name |
| `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_ENDPOINT` | — | object storage credentials and endpoint |
| `INFLUXDB3_NODE_ID` | `node0` | prefix for every object store path — must stay stable |
| `INFLUXDB3_HTTP_BIND_ADDR` | `[::]:8181` | dual-stack bind |
| `INFLUXDB3_OBJECT_STORE` | `s3` | `s3`, `file`, `memory`, `google`, `azure` |
| `AWS_DEFAULT_REGION` | `us-east-1` | signing region only; the endpoint ignores it |
| `INFLUXDB3_DISABLE_AUTHZ` | `health,ping` | routes the anonymous health prober may reach |
| `INFLUXDB3_RAILWAY_DATA_ROOT` | `/var/lib/influxdb3` | volume mount prepared for the runtime user |

### `explorer`

| Variable | Default | Purpose |
|---|---|---|
| `INFLUXDB3_HOST` | `http://influxdb.railway.internal:8181` | server URL; a bare `host:port` gets an `http://` prefix |
| `INFLUXDB3_ADMIN_TOKEN` | — | token written into the pre-configured connection |
| `INFLUXDB3_DATABASE` | `mydb` | database pre-selected in the UI |
| `INFLUXDB3_SERVER_NAME` | `InfluxDB 3 Core` | connection label |
| `SESSION_SECRET_KEY` | — | set it, or sessions reset on every restart |

### `gateway`

| Variable | Default | Purpose |
|---|---|---|
| `GATEWAY_USERNAME` | `admin` | basic-auth user |
| `GATEWAY_PASSWORD` | — | plaintext password; hashed at boot. Required |
| `GATEWAY_PASSWORD_HASH` | — | supply a bcrypt hash directly instead |
| `EXPLORER_UPSTREAM` | `explorer.railway.internal:8080` | Explorer's private address |
| `PORT` | `8080` | injected by Railway |

The gateway refuses to start with neither password variable set, rather than serving Explorer —
and through it an admin token — unauthenticated.

## Licence

The wrappers in this repository are MIT. InfluxDB 3 Core is licensed by InfluxData under MIT and
Apache 2.0; InfluxDB 3 Explorer and Caddy carry their own upstream licences.
