# Testing Stack — Development Workflow

How to take a tool from `to_test.md`, build a testing stack, validate it on a throwaway VM, and land it in the repo.

## Overview

```
 to_test.md          design.md           CloudLab VM            Repo
 ──────────          ─────────           ───────────            ────
 Pick a tool    →    Build stack    →    Deploy & test    →    Commit
                     locally              on VM                 working stack
```

Every new stack goes through four phases: **research, build, test, land**. The VM is disposable — it exists only to validate the stack before committing. Don't skip the VM step; catching problems locally on a clean host is the whole point.

---

## Phase 1 — Research

**Goal:** Understand the tool well enough to write the compose file.

1. **Read the tool entry in `to_test.md`.** Note the setup difficulty, Docker images, special requirements (host network, socket mounts, init steps), and which team values it serves.

2. **Check the tool's official docs and Docker setup.** Look for:
   - Official `docker-compose.yml` in their repo (most have one)
   - Required environment variables and secrets
   - Database requirements (PostgreSQL, MongoDB, Redis, etc.)
   - Port numbers — which port serves the web UI
   - Healthcheck endpoints (`/health`, `/api/health`, CLI commands)
   - Init/migration steps needed on first start
   - Any deprecated components (e.g. CrowdSec's Metabase dashboard was deprecated in favour of Grafana + Prometheus)

3. **Check for Traefik integration concerns:**
   - Does the app serve HTTPS internally? (needs `serversTransport` with `insecureSkipVerify`)
   - Does it expect a URL path prefix? (needs `addprefix` middleware)
   - Does it need multiple routers? (admin UI + API on different ports)
   - Does it need non-HTTP ports exposed? (agent enrollment, syslog, DNS)

4. **Review `design.md`** for the stack skeleton, rules, and checklist. Every stack follows the same pattern.

---

## Phase 2 — Build

**Goal:** Create all stack files locally, ready to deploy.

### Directory structure

```
testing/<tool>/
├── docker-compose.yml
├── .env.example
├── README.md
└── config/
    └── <mounted config files>
```

### Build order

1. **`docker-compose.yml`** — Start from the skeleton in `design.md`. Follow the rules:
   - Web-facing containers join both `<tool>-internal` and `testing-proxy`
   - Backend containers join only `<tool>-internal` (marked `internal: true`)
   - Every long-running service has a healthcheck
   - Container names and volumes prefixed with the tool name
   - No unnecessary host port mappings
   - Required secrets use `${VAR:?error message}` syntax
   - Production-like architecture (separate DB, workers, etc.)

2. **`.env.example`** — Template with generation commands for every secret. Group by component (database, application, etc.).

3. **Config files** — Mount external config rather than relying on embedded defaults. Use `:ro` where possible.

4. **Traefik changes** (if needed) — Some tools require changes to the core testing stack:
   - `testing/traefik/traefik.yml` — plugins, access logging, entrypoint config
   - `testing/traefik/dynamic.yml` — middleware, serversTransports
   - `testing/docker-compose.yml` — shared volumes, environment variables

   Keep core stack changes minimal. Document what you changed and why in the tool's README.

### Pre-flight check

Before moving to the VM, review against the checklist in `design.md`. Common mistakes:
- Forgetting to mark `testing-proxy` as `external: true`
- Missing healthchecks on database containers
- Hardcoded secrets in the compose file
- Volume names without the tool prefix (causes collisions)

---

## Phase 3 — Test

**Goal:** Validate the stack on a clean VM that has nothing pre-installed.

### Provision a VM

Spin up a CloudLab VM. Use `personal-linux-vm` with Ubuntu 24.04 and enough resources for the stack (2c/4GB is a safe default for most stacks):

- **Region:** `syd` (or `mel`)
- **Plan:** `vc2-2c-4gb` for multi-container stacks, `vc2-1c-1gb` for simple ones
- **TTL:** 4-8 hours (auto-destroyed after expiry)

### Install Docker

```bash
apt-get update && apt-get install -y docker.io docker-compose-v2
```

### Deploy

1. **Copy files to the VM.** Mirror the repo structure under `/opt/testing/`:
   ```
   /opt/testing/
   ├── docker-compose.yml        # Core stack
   ├── traefik/                   # Traefik config
   ├── <tool>/                    # Your stack
   ```

2. **Generate `.env` from `.env.example`.** Use `openssl rand -base64 32` for each secret. If the tool shares secrets with the core stack (e.g. a bouncer key), set it in both `.env` files.

3. **Start the core stack first:**
   ```bash
   cd /opt/testing && docker compose up -d
   ```
   This creates the `testing-proxy` network and starts Traefik.

4. **Start the tool stack:**
   ```bash
   cd /opt/testing/<tool> && docker compose up -d
   ```

### Validate

Run through this checklist on the VM:

- [ ] All containers are running and healthy (`docker ps`)
- [ ] No restart loops (`docker ps` shows stable uptime, not `Restarting`)
- [ ] Application responds through Traefik (`curl -sk -H "Host: <tool>.testing.blueteam.au" https://localhost`)
- [ ] Database is populated / migrations ran (check logs)
- [ ] Healthcheck endpoints return OK
- [ ] Default login works (if applicable)
- [ ] Dashboards, data sources, or provisioned content loads correctly
- [ ] Tool-specific functionality works (e.g. CrowdSec detects traffic, scanners scan, etc.)
- [ ] Logs are clean — no errors or warnings that indicate misconfiguration

### Fix issues

When something breaks (it will), fix it on the VM first to get fast feedback, then port the fix back to the local files. Common issues:

- **Container restart loops** — Check `docker logs <container>`. Usually a config error, missing secret, or failed DB connection.
- **Traefik not routing** — Verify the container is on `testing-proxy` and labels are correct. Check `docker network inspect testing-proxy`.
- **Healthcheck failures** — The check command might not exist in the container. Try `wget` instead of `curl`, or use a CLI tool the app provides.
- **Database auth failures** — Environment variable not being passed correctly. Check with `docker exec <container> env | grep POSTGRES`.
- **Plugin/extension not loading** — Check the main application logs. Paths, versions, or download URLs may have changed.

### Copy artifacts back

If you generated or downloaded files on the VM that belong in the repo (dashboard JSON, generated configs, etc.), copy them back to your local checkout.

---

## Phase 4 — Land

**Goal:** Commit the tested, working stack to the repo.

1. **Update local files** with any fixes from the VM testing phase.

2. **Write `README.md`** in the tool's directory. Cover:
   - What the tool does (1-2 sentences)
   - Architecture diagram showing containers and network topology
   - Container table (name, image, purpose, network)
   - Prerequisites and setup steps
   - How to access the UI (URL, default credentials)
   - Useful commands for interacting with the tool
   - File layout
   - Any changes made to the core testing stack

3. **Run the `design.md` checklist** one final time against the local files.

4. **Commit.** Include the tool directory and any core stack changes (traefik config, core compose modifications).

5. **Destroy the VM** (or let the TTL expire). It served its purpose.

---

## Quick Reference

| Phase | Input | Output | Where |
|-------|-------|--------|-------|
| Research | `to_test.md` entry + tool docs | Understanding of requirements | Local |
| Build | `design.md` skeleton | `docker-compose.yml`, `.env.example`, config files | Local |
| Test | Stack files | Validated, working deployment | CloudLab VM |
| Land | Tested files + fixes | Committed stack with README | Local repo |

## Tips

- **Start the core stack before your tool stack.** The `testing-proxy` network and shared volumes must exist first.
- **Use `docker compose logs -f <service>`** on the VM to watch startup in real time.
- **Check `docker compose ps`** — if a container shows `Restarting`, it's crash-looping. Read its logs before anything else.
- **Don't skip the README.** The next person to deploy this stack (including future you) needs to know what the prerequisites are, how to access it, and what commands are available.
- **Keep core stack changes minimal.** If your tool needs a shared volume, environment variable, or Traefik plugin, document the change clearly in your README under a "Traefik Config Changes" section.
- **Prefer official images.** Community images break without warning. If only community images exist, note it in the README as a risk.
- **Test the unhappy path.** Don't just check that containers start — verify the tool actually does its job. Feed it data, trigger a detection, run a scan, log in and click around.
