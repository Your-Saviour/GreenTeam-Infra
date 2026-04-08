# DFIR-IRIS Testing Stack

Open-source collaborative incident response platform for managing and analyzing security investigations. Provides case management, alert triage, timeline reconstruction, and forensic analysis with real-time collaboration.

## Architecture

```
                        Internet
                           │
                    ┌──────┴──────┐
                    │   Traefik   │  iris.testing.blueteam.au
                    └──────┬──────┘
                           │
                  testing-proxy network
                           │
                    ┌──────┴──────┐
                    │  iris-app   │  Gunicorn :8000
                    └──────┬──────┘
                           │
                  iris-internal network
               ┌───────────┼───────────┐
               │           │           │
        ┌──────┴──────┐ ┌──┴───┐ ┌─────┴──────┐
        │  rabbitmq   │ │  db  │ │   worker   │
        │  :5672      │ │:5432 │ │  (celery)  │
        └─────────────┘ └──────┘ └────────────┘
```

## Containers

| Container | Image | Purpose | Network |
|-----------|-------|---------|---------|
| `iris-postgres` | `postgres:16-alpine` | PostgreSQL database | iris-internal |
| `iris-rabbitmq` | `rabbitmq:3-management-alpine` | Message queue for async jobs | iris-internal |
| `iris-app` | `ghcr.io/dfir-iris/iriswebapp_app:v2.4.20` | Web application (Gunicorn) | iris-internal, testing-proxy |
| `iris-worker` | `ghcr.io/dfir-iris/iriswebapp_app:v2.4.20` | Celery worker for background tasks | iris-internal |

## Prerequisites

1. Core testing stack running (`testing-proxy` network must exist)
2. Copy `.env.example` to `.env` and generate secrets per the instructions inside it

## Setup

```bash
cd testing/iris
cp .env.example .env
# Edit .env — generate secrets with: openssl rand -base64 32
# Set IRIS_ADM_PASSWORD to a strong password (12+ chars, mixed case, digit, special)
docker compose up -d
```

First start runs database migrations automatically (~30-60 seconds).

## Access

- **URL:** `https://iris.testing.blueteam.au`
- **Default login:** `administrator` / (password set via `IRIS_ADM_PASSWORD` in `.env`)
- **API:** Use bearer token from user settings page — `Authorization: Bearer <token>`

## Useful Commands

```bash
# Check container status
docker compose ps

# Watch app startup logs
docker compose logs -f app

# Access IRIS shell
docker exec -it iris-app /bin/bash

# List registered modules
docker exec iris-app /opt/venv/bin/python -c "from app import app; print('Modules loaded')"

# Restart worker (e.g. after module config change)
docker compose restart worker

# View worker task processing
docker compose logs -f worker
```

## File Layout

```
testing/iris/
├── docker-compose.yml    # Stack definition (4 services)
├── .env.example          # Secret template with generation commands
└── README.md             # This file
```

## Notes

- The upstream nginx container is **not used** — Traefik handles TLS termination and proxying directly to the app on port 8000.
- Shared volumes (`iris_downloads`, `iris_user_templates`, `iris_server_data`) are mounted on both app and worker for file processing.
- The worker runs as root inside the container (upstream default) — the Celery superuser warning in logs is cosmetic.
- IRIS supports OIDC authentication (`IRIS_AUTHENTICATION_TYPE=oidc`) for future authentik integration.
- No changes to the core testing stack (Traefik config, shared volumes) were required.
