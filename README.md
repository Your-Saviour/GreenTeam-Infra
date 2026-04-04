# GreenTeam-Infra

Docker infrastructure for the GreenTeam project. All services sit behind a Traefik reverse proxy with automatic HTTPS via Let's Encrypt.

## Containers

### Core Stack (`docker-compose.yml`)

| Container | Image | Domain | Description |
|-----------|-------|--------|-------------|
| **traefik** | `traefik:latest` | `traefik.gt.blueteam.au` | Reverse proxy and TLS termination. Routes all incoming traffic to backend services via Docker label discovery. Dashboard is protected with basic auth. |
| **dockhand** | `fnsys/dockhand:latest` | `dockhand.gt.blueteam.au` | Web UI for managing Docker Compose stacks. Provides a GUI to deploy, restart, and monitor containers on the host. |

### Wiki.js Stack (`wikijs/docker-compose.yml`)

| Container | Image | Domain | Description |
|-----------|-------|--------|-------------|
| **wikijs** | `ghcr.io/requarks/wiki:2` | `wiki.blueteam.au` | Modern wiki engine with WYSIWYG and Markdown editing. Authenticates via OIDC through authentik (configured in Wiki.js admin UI). |
| **wikijs-postgresql** | `postgres:16-alpine` | — | Dedicated PostgreSQL database for Wiki.js. Only accessible on the isolated internal network. |

### Dockhand Services Stack (`docker-compose.dockhand.yml`)

| Container | Image | Domain | Description |
|-----------|-------|--------|-------------|
| **authentik-server** | `ghcr.io/goauthentik/server:2026.2.1` | `auth.blueteam.au` | Identity provider handling SSO, OIDC, SAML, and LDAP. Serves the admin UI and all authentication flows. |
| **authentik-worker** | `ghcr.io/goauthentik/server:2026.2.1` | — | Background worker for authentik. Handles emails, LDAP sync, and outpost management. Not exposed to the web. |
| **authentik-postgresql** | `postgres:16-alpine` | — | PostgreSQL database for all authentik data, caching, and task queuing. Only accessible on the isolated internal network. |
| **homarr** | `ghcr.io/homarr-labs/homarr:latest` | `home.blueteam.au` | Homepage dashboard with per-user boards. Authenticates via OIDC through authentik. Groups synced from authentik control which board each user sees. |
| **vaultwarden** | `vaultwarden/server:latest` | `vault.gt.blueteam.au` | Lightweight Bitwarden-compatible password manager. Authenticates via OIDC through authentik. Signups and invitations are disabled — accounts must exist before SSO login. |

## Quick Start

### 1. Core Stack (Traefik + Dockhand)

```bash
docker compose up -d
```

This creates the `proxy` network and starts the reverse proxy and Dockhand container manager.

### 2. Dockhand Services Stack (authentik + Homarr + Vaultwarden)

```bash
# Create your .env from the template
cp .env.example.dockhand .env

# Generate required secrets
echo "PG_PASS=$(openssl rand -base64 36 | tr -d '\n')" >> .env
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 60 | tr -d '\n')" >> .env
echo "HOMARR_ENCRYPTION_KEY=$(openssl rand -hex 32)" >> .env

# Start the stack
docker compose -f docker-compose.dockhand.yml up -d
```

### 3. First-Time Setup

1. Complete authentik initial setup at `https://auth.blueteam.au/if/flow/initial-setup/`
2. In authentik, create an OAuth2/OIDC application for Homarr:
   - Set redirect URI to `https://home.blueteam.au/api/auth/callback/oidc`
   - Note the Client ID, Client Secret, and application slug
3. Add the OIDC credentials to your `.env`:
   ```
   HOMARR_OIDC_CLIENT_ID=<client-id>
   HOMARR_OIDC_CLIENT_SECRET=<client-secret>
   HOMARR_OIDC_SLUG=homarr
   ```
4. Restart Homarr: `docker compose -f docker-compose.dockhand.yml restart homarr`

### Testing Core Stack (`testing/docker-compose.yml`)

| Container | Image | Domain | Description |
|-----------|-------|--------|-------------|
| **testing-traefik** | `traefik:latest` | `traefik.testing.blueteam.au` | Reverse proxy for the testing environment. Dashboard protected with basic auth. |
| **testing-dockhand** | `fnsys/dockhand:latest` | `dockhand.testing.blueteam.au` | Docker Compose management UI for the testing host. |

### Testing: Wazuh Stack (`testing/wazuh/docker-compose.yml`)

| Container | Image | Domain | Description |
|-----------|-------|--------|-------------|
| **wazuh-indexer** | `wazuh/wazuh-indexer:4.14.4` | — | OpenSearch-based storage and search engine for security data. Only accessible on the isolated internal network. |
| **wazuh-manager** | `wazuh/wazuh-manager:4.14.4` | — | Core SIEM engine handling agent management, rules, and alerting. Publishes ports 1514/1515 (agents) and 514/udp (syslog). |
| **wazuh-dashboard** | `wazuh/wazuh-dashboard:4.14.4` | `wazuh.testing.blueteam.au` | Web UI for Wazuh visualization and management. |

**Setup:**
```bash
# 1. Start the testing core stack first (creates testing-proxy network)
cd testing
docker compose up -d

# 2. Set up Wazuh
cd wazuh
cp .env.example .env
# Ensure host has: sudo sysctl -w vm.max_map_count=262144
docker compose up -d
# Certs are auto-generated on first start via init container
```

**Firewall:** The Wazuh manager publishes agent ports directly on the host (not through Traefik). Ensure these are open in your firewall:

| Port | Protocol | Purpose |
|------|----------|---------|
| 1514 | TCP | Agent registration |
| 1515 | TCP | Agent communication |
| 514 | UDP | Syslog collection |

### Testing: AWX Stack (`testing/awx/docker-compose.yml`)

| Container | Image | Domain | Description |
|-----------|-------|--------|-------------|
| **awx-web** | `quay.io/ansible/awx:24.6.1` | `awx.testing.blueteam.au` | AWX web UI and REST API for managing Ansible automation. |
| **awx-task** | `quay.io/ansible/awx:24.6.1` | — | Background task runner that executes Ansible playbooks and jobs. |
| **awx-postgres** | `postgres:16-alpine` | — | PostgreSQL database for AWX. Only accessible on the isolated internal network. |
| **awx-redis** | `redis:7-alpine` | — | Redis message broker for AWX task coordination. Only accessible on the isolated internal network. |

**Setup:**
```bash
cd testing/awx
cp .env.example .env
# Edit .env — set passwords and generate SECRET_KEY: openssl rand -hex 32
docker compose up -d
# Database migration and admin user are created automatically on first start via init container
```

## Architecture

```
Internet (80/443)
       |
    Traefik ──── proxy network ────┬── Dockhand
       |                           ├── authentik server
       |                           ├── Homarr
       |                           ├── Vaultwarden
       |                           └── Wiki.js
       |
  HTTP → HTTPS redirect
  Let's Encrypt TLS (auto)

authentik-internal network (isolated)
  ├── authentik server
  ├── authentik worker
  └── PostgreSQL

wikijs-internal network (isolated)
  ├── Wiki.js
  └── PostgreSQL

wazuh-internal network (isolated)
  ├── Wazuh Indexer
  ├── Wazuh Manager
  └── Wazuh Dashboard

awx-internal network (isolated)
  ├── AWX Web
  ├── AWX Task
  ├── PostgreSQL
  └── Redis
```

- **`proxy`** — Shared network for Traefik service discovery. All web-facing containers join this.
- **`authentik-internal`** — Isolated network for database traffic. Not reachable from outside.

Traefik discovers services via Docker labels. No service publishes host ports — all ingress flows through Traefik on 80/443.

## Adding a New Service

Add it to `docker-compose.dockhand.yml` on the `proxy` network with Traefik labels:

```yaml
my-service:
  image: example/service:latest
  container_name: my-service
  restart: unless-stopped
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.my-service.rule=Host(`my-service.blueteam.au`)"
    - "traefik.http.routers.my-service.entrypoints=websecure"
    - "traefik.http.routers.my-service.tls.certresolver=letsencrypt"
    - "traefik.http.services.my-service.loadbalancer.server.port=8080"
  networks:
    - proxy
```

## File Structure

```
docker-compose.yml              # Core: Traefik + Dockhand
docker-compose.dockhand.yml     # Services: authentik, Homarr, Vaultwarden
wikijs/docker-compose.yml       # Wiki.js + dedicated PostgreSQL
testing/docker-compose.yml       # Testing core: Traefik + Dockhand (*.testing.blueteam.au)
testing/wazuh/docker-compose.yml # Wazuh SIEM testing stack
testing/awx/docker-compose.yml  # AWX (Ansible) testing stack
traefik/traefik.yml             # Traefik static configuration
.env.example.dockhand           # Environment variable template
```

## Upgrading authentik

Do **not** skip major versions. Always upgrade outposts at the same time as the server. See the [authentik upgrade docs](https://docs.goauthentik.io/install-config/upgrade/).
