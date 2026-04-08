# Testing Stack — Design Guide

How to build a new testing stack that fits into the existing infrastructure.

## Overview

The testing environment runs on a single host behind a shared Traefik reverse proxy. Each tool gets its own Docker Compose stack in a subdirectory of `testing/`. Traefik discovers services via Docker labels — no manual routing config needed.

```
                    Internet
                       │
                ┌──────┴──────┐
                │   Traefik   │  ← *.testing.blueteam.au
                │  (testing)  │     Ports 80/443
                └──────┬──────┘
                       │
              testing-proxy network
               ┌───┬───┼───┬───┐
               │   │   │   │   │
             Your stack joins here
               │
               ▼
        [your-internal network]
          DB, workers, etc.
```

The core stack (`testing/docker-compose.yml`) must be running first — it creates the `testing-proxy` network and runs Traefik + Dockhand.

## Directory Layout

Create a new directory under `testing/` named after your tool:

```
testing/<tool>/
├── docker-compose.yml      # Required — stack definition
├── .env.example            # Required if secrets are needed
└── config/                 # Optional — mounted config files
```

## Compose File Structure

### Skeleton

Use this as a starting point. Replace `<tool>` with your service name throughout:

```yaml
# <Tool Name> Testing Stack
# Prerequisites:
#   1. Copy .env.example to .env and generate secrets per the instructions inside it
#   2. Ensure testing-proxy network exists (start testing core stack first)
#   3. Start: docker compose up -d
#
# Resource requirements: ~<N>MB RAM minimum (<brief breakdown>)
#
# Notes:
#   - <anything non-obvious about first start, default creds, etc.>

services:

  # ─── One-shot init (if needed) ──────────────────────────────────────────────
  # Use for DB migrations, cert generation, schema bootstrapping, etc.
  # Remove this block if the tool doesn't need initialization.
  init:
    image: <image>
    container_name: <tool>-init
    restart: "no"
    # ... init logic ...
    networks:
      - <tool>-internal

  # ─── Database (if needed) ───────────────────────────────────────────────────
  # Use postgres:16-alpine unless the tool requires a specific version or DB.
  postgres:
    image: postgres:16-alpine
    container_name: <tool>-postgres
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
      start_period: 15s
      interval: 30s
      retries: 5
      timeout: 5s
    volumes:
      - <tool>_postgres_data:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-<tool>}
      POSTGRES_USER: ${POSTGRES_USER:-<tool>}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Please set POSTGRES_PASSWORD in your .env file}
    networks:
      - <tool>-internal

  # ─── Application ────────────────────────────────────────────────────────────
  <tool>:
    image: <image>
    container_name: <tool>-app
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.<tool>.rule=Host(`<tool>.testing.blueteam.au`)"
      - "traefik.http.routers.<tool>.entrypoints=websecure"
      - "traefik.http.routers.<tool>.tls.certresolver=letsencrypt"
      - "traefik.http.services.<tool>.loadbalancer.server.port=<container-port>"
    networks:
      - <tool>-internal
      - testing-proxy

networks:
  <tool>-internal:
    internal: true
  testing-proxy:
    external: true

volumes:
  <tool>_postgres_data:
```

### Rules

**Networks:**
- The web-facing container(s) must join both `testing-proxy` and `<tool>-internal`.
- Backend services (databases, workers, daemons) join only `<tool>-internal`.
- Mark `<tool>-internal` as `internal: true` so backends can't reach the internet.
- `testing-proxy` is always `external: true` — it's created by the core stack.

**Traefik labels — only on the web-facing container(s):**
- `traefik.enable=true`
- `traefik.http.routers.<name>.rule=Host(`<name>.testing.blueteam.au`)`
- `traefik.http.routers.<name>.entrypoints=websecure`
- `traefik.http.routers.<name>.tls.certresolver=letsencrypt`
- `traefik.http.services.<name>.loadbalancer.server.port=<port>`

**Do not publish host ports** unless the protocol can't be reverse-proxied (agent enrollment, SSH, syslog, etc.). If you must expose a port, document why in the compose header comments.

**Container naming:** Prefix all container names with the tool name to avoid collisions (e.g. `<tool>-postgres`, `<tool>-redis`, `<tool>-app`).

**Volume naming:** Prefix volumes the same way (e.g. `<tool>_postgres_data`).

## Init Containers

If the tool needs one-time setup (DB migrations, cert generation, schema bootstrapping):

1. Create the init container with `restart: "no"`.
2. Make downstream services depend on it:
   ```yaml
   depends_on:
     init:
       condition: service_completed_successfully
   ```

For databases, add a healthcheck and have the app depend on it with `condition: service_healthy`.

## Secrets and Environment

### .env.example

Every stack that uses secrets needs a `.env.example`. Format it like this:

```bash
# <Tool Name> Testing Environment
# Copy this file to .env and fill in the values below before starting.

# ─── Database ────────────────────────────────────────────────────────────────

# PostgreSQL credentials
# Generate password: openssl rand -base64 32
POSTGRES_DB=<tool>
POSTGRES_USER=<tool>
POSTGRES_PASSWORD=replace_me

# ─── Application ─────────────────────────────────────────────────────────────

# <Description of what this secret is for>
# Generate: openssl rand -base64 32
SECRET_KEY=replace_me
```

### In the compose file

Use `${VAR:?error message}` for required secrets so the stack fails fast with a clear message instead of starting with empty values:

```yaml
POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?Please set POSTGRES_PASSWORD in your .env file}
```

Use `${VAR:-default}` for non-secret config with sensible defaults:

```yaml
POSTGRES_DB: ${POSTGRES_DB:-mytool}
```

Never put actual secrets in the compose file or `.env.example`.

## Production-Like Design

The testing stack exists to validate tools before production. Design each stack as close to a real deployment as practical — if it works differently here than it will in prod, the testing is less useful.

### Multi-Container Architecture

Don't collapse everything into a single container. If the tool's production deployment separates the web frontend, background workers, and database, your testing stack should too:

```yaml
services:
  app:        # API / web frontend
  worker:     # Background job processor
  scheduler:  # Cron / periodic tasks
  postgres:   # Database
  redis:      # Queue / cache
```

This catches issues that a single all-in-one container hides — networking between components, shared volume permissions, startup ordering, and resource contention.

### Databases

Use external databases rather than embedded/bundled ones wherever the tool supports it:

- **PostgreSQL** — Default choice. Use `postgres:16-alpine` unless the tool requires an older version. Run as its own container, not bundled inside the app image.
- **Redis** — Use `redis:7-alpine` when the tool needs a queue or cache. Separate container, not embedded.
- **MongoDB / OpenSearch / etc.** — Use official images matching the tool's requirements.

Keep database data in named volumes so it survives container recreation. This also means you're testing against the same persistence model prod will use.

### Scaling Workers

If the tool supports horizontal scaling of workers or processing nodes, use `deploy.replicas` rather than running a single instance:

```yaml
worker:
  image: <image>
  deploy:
    replicas: 2
  # ...
```

This validates that the tool handles multiple workers correctly — shared state, job locking, cache coherence. Start with 2 replicas; that's enough to surface concurrency issues without wasting resources.

### Clustering

For tools where production means a cluster (Elasticsearch, databases, message brokers), deploy multiple nodes. The Elastic stack runs a 3-node ES cluster for this reason — it validates shard distribution, quorum behaviour, and inter-node TLS that a single node would never exercise.

Only cluster components where it adds testing value. A 3-node PostgreSQL cluster is overkill for most tools — single-node Postgres with a volume is fine unless you're specifically testing HA failover.

### Resource Limits

Set JVM heap sizes, memory limits, and worker counts explicitly via environment variables rather than letting tools use defaults. This mirrors production tuning and prevents a single stack from consuming all host resources:

```yaml
environment:
  - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
  - PUMA_WORKERS=2
```

Expose these as variables in `.env.example` where they're likely to need tuning per host:

```bash
# JVM heap for PuppetDB (default 256m, increase if managing many nodes)
PUPPETDB_JAVA_ARGS=-Xms256m -Xmx256m
```

### External Config Over Embedded

Mount configuration files from the `config/` directory rather than relying on built-in defaults or environment variable hacks. This tests the same config management approach you'll use in production and makes the config auditable in version control:

```yaml
volumes:
  - ./config/app.conf:/etc/app/app.conf:ro
```

Mount config as `:ro` (read-only) where possible.

### TLS Between Components

If the production deployment uses TLS between internal components (e.g. app-to-database, node-to-node), set it up in the testing stack too. Use init containers to generate certificates — see the Elastic and Wazuh stacks for working examples. Skipping internal TLS in testing means you won't catch cert issues until production.

## Handling Special Cases

### Backend serves HTTPS internally

If the upstream container serves HTTPS and can't be configured to use HTTP, you need a custom `serversTransport` in Traefik's dynamic config.

1. Add to `traefik/dynamic.yml`:
   ```yaml
   http:
     serversTransports:
       <tool>-transport:
         insecureSkipVerify: true
   ```

2. Reference it in the service labels:
   ```yaml
   - "traefik.http.services.<tool>.loadbalancer.server.scheme=https"
   - "traefik.http.services.<tool>.loadbalancer.serverstransport=<tool>-transport@file"
   ```

### App requires a URL path prefix

Some apps (e.g. Guacamole) expect to be served from a subpath. Use Traefik's `addprefix` middleware:

```yaml
- "traefik.http.routers.<tool>.middlewares=<tool>-prefix"
- "traefik.http.middlewares.<tool>-prefix.addprefix.prefix=/<path>"
```

### Multiple web UIs or endpoints

Define separate routers and services for each. Use distinct router/service names:

```yaml
# Primary UI
- "traefik.http.routers.<tool>.rule=Host(`<tool>.testing.blueteam.au`)"
- "traefik.http.services.<tool>.loadbalancer.server.port=8080"
# API or secondary UI
- "traefik.http.routers.<tool>-api.rule=Host(`<tool>-api.testing.blueteam.au`)"
- "traefik.http.services.<tool>-api.loadbalancer.server.port=9090"
```

### Host prerequisites

If the tool needs host-level config (e.g. `vm.max_map_count` for OpenSearch/Elasticsearch), document it in the compose file header comments and include both temporary and permanent commands:

```yaml
# Host requirement (must be set on the OS before deploying):
#   vm.max_map_count=262144
#   Temporary: sudo sysctl -w vm.max_map_count=262144
#   Permanent: add "vm.max_map_count=262144" to /etc/sysctl.conf
```

### Docker socket access

Avoid mounting `/var/run/docker.sock` unless the tool genuinely needs it (container management, job execution). If required, document the security implication in the compose header.

## Healthchecks

Every long-running service (`restart: unless-stopped`) **must** have a healthcheck. This is not optional — without it, `depends_on` with `condition: service_healthy` won't work, and Dockhand/`docker compose ps` will show misleading status. The only exception is one-shot init containers (`restart: "no"`), which use `service_completed_successfully` instead.

Common patterns:

```yaml
# HTTP endpoint
healthcheck:
  test: ["CMD-SHELL", "curl -fsS http://localhost:<port>/health || exit 1"]
  start_period: 30s
  interval: 30s
  retries: 5
  timeout: 5s

# PostgreSQL
healthcheck:
  test: ["CMD-SHELL", "pg_isready -d $${POSTGRES_DB} -U $${POSTGRES_USER}"]
  start_period: 15s
  interval: 30s
  retries: 5
  timeout: 5s

# Redis
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 5s
  retries: 5

# wget (for containers without curl)
healthcheck:
  test: ["CMD-SHELL", "wget --spider -q http://localhost:<port>/healthz || exit 1"]
  start_period: 30s
  interval: 30s
  retries: 5
  timeout: 5s
```

Set `start_period` generously for tools that are slow to initialise (JVM apps, tools that run migrations on first boot). Check existing stacks for examples — Puppet Server uses 180s, GitLab uses 300s.

## Compose Header Comments

Every compose file starts with a comment block describing:

1. What the stack is
2. Prerequisites (numbered steps)
3. Resource requirements
4. Anything non-obvious (default credentials, slow first start, manual post-deploy steps)

See any existing stack for the format.

## Checklist

Before considering a new stack done:

- [ ] Directory created at `testing/<tool>/`
- [ ] `docker-compose.yml` follows the skeleton above
- [ ] Header comments include prerequisites, resource requirements, and notes
- [ ] `.env.example` exists with generation commands for every secret
- [ ] Container names and volumes are prefixed with the tool name
- [ ] Web-facing container has correct Traefik labels
- [ ] Web-facing container joins both `testing-proxy` and `<tool>-internal`
- [ ] Backend containers join only `<tool>-internal` (marked `internal: true`)
- [ ] No unnecessary host port mappings
- [ ] Databases have healthchecks; services depend on healthy databases
- [ ] Init containers use `restart: "no"` with `service_completed_successfully` dependency
- [ ] Required secrets use `${VAR:?error message}` syntax
- [ ] Host prerequisites (if any) are documented in the compose header
- [ ] Stack starts cleanly with `docker compose up -d` after setting up `.env`
