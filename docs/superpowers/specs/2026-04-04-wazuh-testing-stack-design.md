# Wazuh Testing Stack Design

## Context

We need a Wazuh SIEM/XDR testing environment integrated into the existing GreenTeam-Infra. Wazuh provides security monitoring, intrusion detection, vulnerability assessment, and compliance checking. This stack follows the same conventions as the existing `wikijs/` subfolder — isolated compose stack with Traefik integration.

## Components

- **Wazuh Indexer** (v4.14.4) — OpenSearch-based storage/search engine for security data
- **Wazuh Manager** (v4.14.4) — Core SIEM engine: agent management, rules, alerting
- **Wazuh Dashboard** (v4.14.4) — Web UI for visualization and management

## Directory Structure

```
wazuh/
├── docker-compose.yml
├── generate-certs.yml
├── .env.example
├── config/
│   ├── certs.yml
│   ├── wazuh_indexer/
│   │   ├── wazuh.indexer.yml
│   │   └── internal_users.yml       (if needed for custom passwords)
│   └── wazuh_dashboard/
│       ├── opensearch_dashboards.yml
│       └── wazuh.yml
└── config/wazuh_indexer_ssl_certs/   (generated, gitignored)
```

## Networking

| Network | Type | Members | Purpose |
|---------|------|---------|---------|
| `proxy` | external | wazuh-dashboard | Traefik routing |
| `wazuh-internal` | internal: true | all three services | Inter-component TLS communication |

## Published Ports

| Port | Protocol | Service | Purpose |
|------|----------|---------|---------|
| 1514 | TCP | wazuh-manager | Agent registration |
| 1515 | TCP | wazuh-manager | Agent communication |
| 514 | UDP | wazuh-manager | Syslog collection |

Dashboard is exposed only through Traefik (no host port).

## Traefik Integration

Dashboard routed at `wazuh.gt.blueteam.au` on the `websecure` entrypoint:

```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.wazuh-dashboard.rule=Host(`wazuh.gt.blueteam.au`)"
  - "traefik.http.routers.wazuh-dashboard.entrypoints=websecure"
  - "traefik.http.routers.wazuh-dashboard.tls.certresolver=letsencrypt"
  - "traefik.http.services.wazuh-dashboard.loadbalancer.server.port=5601"
  - "traefik.http.services.wazuh-dashboard.loadbalancer.server.scheme=https"
  - "traefik.http.routers.wazuh-dashboard.service=wazuh-dashboard"
```

The dashboard serves HTTPS on port 5601 internally, so we need `server.scheme=https` to tell Traefik to connect via HTTPS. Since the backend uses self-signed certs, we also add a `serversTransport` with `insecureSkipVerify=true` via Traefik labels:

```yaml
- "traefik.http.serversTransports.wazuh-transport.insecureSkipVerify=true"
- "traefik.http.services.wazuh-dashboard.loadbalancer.serverstransport=wazuh-transport"
```

## Certificate Generation

A one-time `generate-certs.yml` compose file uses `wazuh/wazuh-certs-generator:0.0.4`:

```yaml
services:
  generator:
    image: wazuh/wazuh-certs-generator:0.0.4
    hostname: wazuh-certs-generator
    environment:
      - CERT_TOOL_VERSION=4.14
    volumes:
      - ./config/wazuh_indexer_ssl_certs/:/certificates/
      - ./config/certs.yml:/config/certs.yml
```

Run once: `docker compose -f generate-certs.yml run --rm generator`

## Secrets (.env.example)

```bash
# Wazuh Indexer (OpenSearch) admin password
# IMPORTANT: Change from default before first start
INDEXER_PASSWORD=SecretPassword

# Wazuh API credentials (dashboard → manager communication)
API_PASSWORD=MyS3cr37P450r.*-

# Dashboard internal user password
DASHBOARD_PASSWORD=kibanaserver
```

## Configuration Files

### config/certs.yml
Defines hostnames for certificate generation (indexer, manager, dashboard nodes).

### config/wazuh_indexer/wazuh.indexer.yml
OpenSearch configuration: single-node discovery, TLS cert paths, security plugin settings, cipher suites.

### config/wazuh_dashboard/opensearch_dashboards.yml
Dashboard server config: TLS settings, OpenSearch connection, session timeouts.

### config/wazuh_dashboard/wazuh.yml
Dashboard → Manager API connection: URL, port 55000, credentials.

## Host Requirements

The Docker host must have `vm.max_map_count=262144` set for the indexer:
```bash
sudo sysctl -w vm.max_map_count=262144
# Persist: echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
```

## Startup Sequence

1. Generate certs: `docker compose -f generate-certs.yml run --rm generator`
2. Copy `.env.example` to `.env` and set passwords
3. Set `vm.max_map_count` on host
4. Start stack: `docker compose up -d`
5. Access dashboard at `https://wazuh.gt.blueteam.au`

## Verification

- Dashboard loads at `https://wazuh.gt.blueteam.au` with login page
- Login with admin / `$INDEXER_PASSWORD` shows the Wazuh overview
- Indexer health: `curl -k -u admin:$INDEXER_PASSWORD https://localhost:9200/_cluster/health` (from host if port exposed, or via docker exec)
- Manager API: `curl -k -u wazuh-wui:$API_PASSWORD https://localhost:55000/security/user/authenticate` (via docker exec)
