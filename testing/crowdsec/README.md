# CrowdSec Testing Stack

Behavior detection engine that analyzes Traefik access logs to detect and ban malicious IPs. Includes a Traefik bouncer plugin for active enforcement and a Grafana dashboard for visibility.

## Architecture

```
                        Internet
                           │
                    ┌──────┴──────┐
                    │   Traefik   │─── access.log ───┐
                    │  + bouncer  │                   │
                    │   plugin    │◄─ ban decisions ──┤
                    └──────┬──────┘                   │
                           │                    ┌─────┴─────┐
                  testing-proxy network         │  CrowdSec │
                     ┌─────┼─────┐              │   Engine  │
                     │           │              │  (LAPI)   │
              ┌──────┴──┐  ┌────┴─────┐        └─────┬─────┘
              │ Grafana  │  │ services │              │ :6060
              │ :3000    │  │  ...     │        ┌─────┴──────┐
              └──────┬───┘  └──────────┘        │ Prometheus │
                     │                          │  :9090     │
              crowdsec-internal network         └────────────┘
                     │
              ┌──────┴──────┐
              │  PostgreSQL  │
              │  (Grafana)   │
              └──────────────┘
```

## Containers

| Container | Image | Purpose | Network |
|-----------|-------|---------|---------|
| `crowdsec-app` | `crowdsecurity/crowdsec` | LAPI + agent — parses logs, issues ban decisions, serves bouncer API | internal + proxy |
| `crowdsec-prometheus` | `prom/prometheus` | Scrapes CrowdSec metrics on `:6060` | internal |
| `crowdsec-postgres` | `postgres:16-alpine` | Grafana database backend | internal |
| `crowdsec-grafana` | `grafana/grafana` | Dashboard UI at `crowdsec.testing.blueteam.au` | internal + proxy |

## Prerequisites

1. The core testing stack must be running (`testing/docker-compose.yml`) — it creates the `testing-proxy` network and the shared `testing-traefik-accesslog` volume.

2. Traefik must have access logging and the bouncer plugin enabled. The required changes are already in:
   - `testing/traefik/traefik.yml` — `accessLog` section and `experimental.plugins.crowdsec-bouncer`
   - `testing/traefik/dynamic.yml` — `crowdsec-bouncer` middleware definition
   - `testing/docker-compose.yml` — `CROWDSEC_BOUNCER_KEY` env var and `testing-traefik-accesslog` volume

3. The `CROWDSEC_BOUNCER_KEY` must be set in **both**:
   - `testing/.env` (read by Traefik via Go template in `dynamic.yml`)
   - `testing/crowdsec/.env` (read by the CrowdSec container)

   Both values must match. Generate once with `openssl rand -base64 32` and use it in both files.

## Setup

```bash
# 1. Generate secrets
cd testing/crowdsec
cp .env.example .env
# Edit .env — generate each secret with: openssl rand -base64 32

# 2. Set the same bouncer key in the core stack
echo "CROWDSEC_BOUNCER_KEY=<same key as in crowdsec/.env>" >> ../. env

# 3. Restart Traefik to pick up the bouncer plugin and access logging
cd .. && docker compose up -d

# 4. Start CrowdSec
cd crowdsec && docker compose up -d
```

## Accessing the Dashboard

- **URL:** `https://crowdsec.testing.blueteam.au`
- **Username:** `admin`
- **Password:** `<GRAFANA_ADMIN_PASSWORD from .env>`

The "CrowdSec Metrics" dashboard is auto-provisioned with 17 panels covering alerts, decisions, parsed lines, acquisition stats, and bouncer activity.

## Collections

CrowdSec auto-installs these collections on first start:

| Collection | Purpose |
|------------|---------|
| `crowdsecurity/traefik` | Traefik access log parser + scenarios |
| `crowdsecurity/http-cve` | Detection rules for known HTTP CVEs |
| `crowdsecurity/linux` | SSH brute-force, system log scenarios |

Additional collections are pulled as dependencies (e.g. `base-http-scenarios`, `sshd`, `whitelist-good-actors`).

## Traefik Bouncer

The bouncer plugin is defined as a middleware called `crowdsec-bouncer@file` in the Traefik dynamic config. It operates in **stream mode** — CrowdSec pushes decisions to the bouncer rather than the bouncer querying per-request.

To apply the bouncer to a specific service, add this label:

```yaml
labels:
  - "traefik.http.routers.<name>.middlewares=crowdsec-bouncer@file"
```

To apply it to all services on the `websecure` entrypoint, add to `traefik.yml`:

```yaml
entryPoints:
  websecure:
    address: ":443"
    http:
      middlewares:
        - crowdsec-bouncer@file
```

## Useful Commands

```bash
# Check LAPI status
docker exec crowdsec-app cscli lapi status

# List registered bouncers
docker exec crowdsec-app cscli bouncers list

# View active alerts
docker exec crowdsec-app cscli alerts list

# View active ban decisions
docker exec crowdsec-app cscli decisions list

# Manually ban an IP (for testing)
docker exec crowdsec-app cscli decisions add --ip 1.2.3.4 --reason "manual test" --type ban

# Remove a ban
docker exec crowdsec-app cscli decisions delete --ip 1.2.3.4

# List installed collections
docker exec crowdsec-app cscli collections list

# View parsed log metrics
docker exec crowdsec-app cscli metrics
```

## File Layout

```
testing/crowdsec/
├── docker-compose.yml                  # Stack definition
├── .env.example                        # Secret template
├── README.md                           # This file
└── config/
    ├── acquis.yaml                     # Log acquisition — tells CrowdSec to parse Traefik logs
    ├── prometheus.yml                  # Prometheus scrape config targeting CrowdSec :6060
    ├── grafana-datasource.yml          # Auto-provisions Prometheus as Grafana data source
    ├── grafana-dashboards.yml          # Auto-provisions dashboard directory
    └── dashboards/
        └── crowdsec-metrics.json       # Official CrowdSec Grafana dashboard (17 panels)
```

## Traefik Config Changes

This stack requires the following additions to the core testing Traefik config (already applied):

**`testing/traefik/traefik.yml`** — access logging + plugin:
```yaml
accessLog:
  filePath: /var/log/traefik/access.log
  bufferingSize: 100

experimental:
  plugins:
    crowdsec-bouncer:
      moduleName: github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin
      version: v1.4.7
```

**`testing/traefik/dynamic.yml`** — bouncer middleware:
```yaml
http:
  middlewares:
    crowdsec-bouncer:
      plugin:
        crowdsec-bouncer:
          enabled: true
          crowdsecMode: stream
          crowdsecLapiScheme: http
          crowdsecLapiHost: crowdsec-app:8080
          crowdsecLapiKey: '{{ env "CROWDSEC_BOUNCER_KEY" }}'
          logLevel: INFO
```

**`testing/docker-compose.yml`** — env var + shared volume on Traefik container:
```yaml
environment:
  CROWDSEC_BOUNCER_KEY: ${CROWDSEC_BOUNCER_KEY:-}
volumes:
  - testing-traefik-accesslog:/var/log/traefik
```
