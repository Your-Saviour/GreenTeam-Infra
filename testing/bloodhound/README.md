# BloodHound Community Edition — Testing Stack

Graph-based Active Directory attack path mapping tool. Discovers hidden privilege relationships and lateral movement opportunities using SharpHound/AzureHound collectors, with a Neo4j graph database backend and web-based exploration UI.

## Architecture

```
                    Internet
                       │
                ┌──────┴──────┐
                │   Traefik   │  ← bloodhound.testing.blueteam.au
                └──────┬──────┘
                       │
              testing-proxy network
                       │
               ┌───────┴───────┐
               │  bloodhound   │  ← API + Web UI (:8080)
               │   (app)       │
               └───┬───────┬───┘
                   │       │
          bloodhound-internal network (isolated)
                   │       │
            ┌──────┴──┐ ┌──┴──────┐
            │ postgres │ │  neo4j  │
            │  (data)  │ │ (graph) │
            └─────────┘ └─────────┘
```

## Containers

| Container | Image | Purpose | Network |
|-----------|-------|---------|---------|
| `bloodhound-app` | `specterops/bloodhound:latest` | API server + web UI | `bloodhound-internal`, `testing-proxy` |
| `bloodhound-postgres` | `postgres:16-alpine` | Application state/config | `bloodhound-internal` |
| `bloodhound-neo4j` | `neo4j:4.4` | Graph database for AD relationships | `bloodhound-internal` |

## Prerequisites

1. Core testing stack running (`testing-proxy` network must exist)
2. Copy `.env.example` to `.env` and generate secrets

## Setup

```bash
# Generate .env from template
cp .env.example .env

# Generate secrets
sed -i "s/POSTGRES_PASSWORD=replace_me/POSTGRES_PASSWORD=$(openssl rand -base64 32)/" .env
sed -i "s/NEO4J_PASSWORD=replace_me/NEO4J_PASSWORD=$(openssl rand -base64 32)/" .env

# Start the stack
docker compose up -d
```

## Access

- **URL:** `https://bloodhound.testing.blueteam.au`
- **Default user:** `admin`
- **Default password:** Randomly generated on first start. Retrieve it from logs:
  ```bash
  docker compose logs bloodhound 2>&1 | grep "Initial Password"
  ```

## Useful Commands

```bash
# View admin password from first start
docker compose logs bloodhound 2>&1 | grep "Initial Password"

# Reset admin password (if lost)
docker compose exec bloodhound ./bloodhound-cli resetpwd

# Watch startup progress
docker compose logs -f

# Check container health
docker compose ps

# Clear all data and start fresh
docker compose down --volumes
docker compose up -d
```

## File Layout

```
testing/bloodhound/
├── docker-compose.yml    # Stack definition
├── .env.example          # Secret template
└── README.md             # This file
```

## Notes

- Graph analysis runs on startup (~1 minute). Avoid heavy API calls during this period.
- Sessions are ephemeral — users must re-login after container restart.
- Neo4j 4.4 is required (BloodHound CE does not support Neo4j 5.x yet).
- No changes to the core testing stack (Traefik config) are required.
- The BloodHound image is a scratch/distroless Go binary — no shell, no curl, no wget. Docker healthchecks via `CMD-SHELL` are not possible. Liveness is inferred from Traefik routing and the `restart: unless-stopped` policy.
- Tested with BloodHound CE v8.9.1 (community edition).
