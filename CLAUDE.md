# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

Docker infrastructure for the GreenTeam project. Two compose stacks manage all services behind a shared Traefik reverse proxy with automatic HTTPS via Let's Encrypt.

## Compose Stacks

**`docker-compose.yml`** — Core infrastructure (Traefik + Dockhand)
```bash
docker compose up -d
```

**`docker-compose.dockhand.yml`** — Services managed via Dockhand (authentik, Homarr, and future additions)
```bash
docker compose -f docker-compose.dockhand.yml up -d
```

The dockhand stack requires a `.env` file — copy `.env.example.dockhand` and generate secrets per the instructions inside it.

## Architecture

All web-facing services route through a single Traefik instance on the `proxy` network. Traefik discovers services via Docker labels (`traefik.enable=true`). No ports are published on service containers — only Traefik exposes 80/443.

**Network topology:**
- `proxy` — Shared external network defined in the main compose. Every Traefik-routed service joins this network. Traefik's Docker provider is pinned to it.
- `authentik-internal` — Isolated (`internal: true`) network for authentik ↔ PostgreSQL communication. Not reachable from Traefik or the host.

**Domain conventions:**
- Core infra uses `*.gt.blueteam.au` (e.g. `traefik.gt.blueteam.au`, `dockhand.gt.blueteam.au`)
- User-facing services use `*.blueteam.au` (e.g. `auth.blueteam.au`, `home.blueteam.au`)

## Adding a New Service

Add it to `docker-compose.dockhand.yml` with these Traefik labels:
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.<name>.rule=Host(`<name>.blueteam.au`)"
  - "traefik.http.routers.<name>.entrypoints=websecure"
  - "traefik.http.routers.<name>.tls.certresolver=letsencrypt"
  - "traefik.http.services.<name>.loadbalancer.server.port=<container-port>"
```
Attach it to the `proxy` network. No host port mapping needed.

## Traefik Configuration

Static config lives in `traefik/traefik.yml`. Entrypoints: `web` (80, redirects to HTTPS) and `websecure` (443). Certificate resolver: `letsencrypt` with TLS challenge, email `admin@blueteam.au`.

The dashboard is protected with basic auth (bcrypt hash in compose labels). When editing basic auth hashes in compose files, escape `$` as `$$`.

## Key Constraints

- Use `traefik:latest` — don't pin old versions (older tags have Docker API compat issues).
- authentik containers must NOT mount `/etc/timezone` or `/etc/localtime` — it breaks OAuth/SAML.
- `AUTHENTIK_REDIS__HOST` is intentionally set to empty string (Redis removed in authentik v2025.10).
- The `proxy` network must exist before starting the dockhand stack (`docker network create proxy` or start the main compose first).
