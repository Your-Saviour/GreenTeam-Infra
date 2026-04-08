# Testing Method

Standardised verification procedure for every testing stack. Run through this on the CloudLab VM before considering a stack done.

---

## 1 — Infrastructure Health

Verify every container is running, stable, and passing its healthcheck.

```bash
# All containers running and healthy (no "Restarting" or "unhealthy")
docker compose ps

# No restart loops — uptime should be stable, not resetting
docker ps --format "table {{.Names}}\t{{.Status}}"

# No error-level log entries on any container
docker compose logs --tail=50 | grep -iE "error|fatal|panic|exception"
```

**Pass criteria:**
- [ ] Every container shows `Up` with `(healthy)` status
- [ ] No container has restarted in the last 60 seconds
- [ ] No error/fatal/panic messages in startup logs

---

## 2 — Network & Routing

Verify the stack is reachable through Traefik and network topology is correct.

```bash
# Web-facing container is on both networks
docker inspect <tool>-app --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
# Expected: crowdsec-internal testing-proxy (or equivalent)

# Backend containers are only on the internal network
docker inspect <tool>-postgres --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}'
# Expected: crowdsec-internal (only)

# Traefik routes to the service
curl -sk -H "Host: <tool>.testing.blueteam.au" https://localhost
# Expected: 200 OK or redirect to login — NOT 404

# Traefik has registered the router
curl -sk -H "Host: traefik.testing.blueteam.au" -u <user>:<pass> \
  "https://localhost/api/http/routers" | python3 -m json.tool | grep <tool>

# No host ports are published (unless documented and justified)
docker compose ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "testing-traefik"
# Expected: internal ports only (e.g. "3000/tcp"), no 0.0.0.0 bindings
```

**Pass criteria:**
- [ ] Web container is on both `<tool>-internal` and `testing-proxy`
- [ ] Backend containers are only on `<tool>-internal`
- [ ] Service responds through Traefik with correct Host header
- [ ] No unexpected host port bindings

---

## 3 — Database & Persistence

Verify database connectivity and data persistence across restarts.

```bash
# Database healthcheck passes
docker exec <tool>-postgres pg_isready -d <db> -U <user>

# Application can reach the database (check app logs for connection success)
docker logs <tool>-app 2>&1 | grep -iE "database|postgres|connected|migration"

# Data survives a restart
docker compose restart <service>
# After restart, verify data/config is still present
```

**Pass criteria:**
- [ ] Database healthcheck returns ready
- [ ] Application logs confirm successful database connection
- [ ] No "connection refused" or auth errors between app and database
- [ ] Data persists after `docker compose restart`

---

## 4 — Authentication & Access

Verify login works and default credentials are documented.

```bash
# Web UI login page loads
curl -sk -H "Host: <tool>.testing.blueteam.au" https://localhost -o /dev/null -w "%{http_code}"
# Expected: 200 or 302 redirect to /login

# API health endpoint (if available)
curl -sk -H "Host: <tool>.testing.blueteam.au" https://localhost/api/health
```

**Pass criteria:**
- [ ] Login page renders correctly
- [ ] Default credentials from `.env` / README work on first login
- [ ] API endpoints respond (if the tool has an API)

---

## 5 — Provisioned Content

Verify dashboards, data sources, plugins, and other auto-provisioned content loaded correctly.

This is the step that catches the "empty UI" problem. Don't just check that the app starts — check that it has content.

```bash
# Example: Grafana dashboards
curl -sk -u admin:<pass> -H "Host: <tool>.testing.blueteam.au" \
  https://localhost/api/search | python3 -m json.tool
# Expected: at least one dashboard listed

# Example: Grafana data sources
curl -sk -u admin:<pass> -H "Host: <tool>.testing.blueteam.au" \
  https://localhost/api/datasources | python3 -m json.tool
# Expected: data source configured and reachable
```

**Pass criteria:**
- [ ] Dashboards / saved views / default content are present (not a blank UI)
- [ ] Data sources / integrations are connected and showing data
- [ ] Plugins / extensions required by the tool are installed

---

## 6 — Functional Validation

Verify the tool actually does what it's supposed to do. This is tool-specific — the goal is to exercise the core function, not just confirm the container starts.

### Detection tools (CrowdSec, Suricata, Wazuh)
```bash
# Generate test traffic and check for alerts
curl -sk "https://localhost/.env"
curl -sk "https://localhost/wp-admin"
# Wait 30 seconds for log parsing
docker exec <tool>-app <cli> alerts list
```
- [ ] Tool detects and alerts on known-bad patterns
- [ ] Alerts appear in the dashboard

### Scanning tools (Nuclei, ZAP, OpenVAS)
```bash
# Run a basic scan against a test target
docker exec <tool>-app <scan-command> --target <url>
```
- [ ] Scan completes without errors
- [ ] Results are stored / viewable

### Management platforms (DFIR-IRIS, BloodHound, VECTR)
```bash
# Create a test object via UI or API
curl -sk -X POST -H "Content-Type: application/json" \
  -d '{"name": "test"}' \
  https://localhost/api/<endpoint>
```
- [ ] Can create, read, update, delete core objects
- [ ] Data appears in the UI

### SOAR / automation (Shuffle, Tracecat)
- [ ] Can create a basic workflow / playbook
- [ ] Workflow executes successfully

### Infrastructure tools (ClamAV, Pi-hole, Smallstep)
```bash
# Test the core function
docker exec <tool>-app <test-command>
```
- [ ] Core function works (scan a file, resolve a DNS query, issue a cert)

---

## 7 — Secrets & Security

Verify secrets are handled correctly and nothing sensitive is exposed.

```bash
# No secrets in the compose file
grep -iE "password|secret|key|token" docker-compose.yml
# Expected: only ${VAR:?...} or ${VAR:-...} references, never literal values

# Required secrets fail fast if missing
grep -c ':?' docker-compose.yml
# Should match the number of required secrets in .env.example

# .env.example has no real secrets
grep "replace_me" .env.example
# All secret values should be "replace_me"

# Docker socket is not mounted (unless documented and justified)
grep "docker.sock" docker-compose.yml
# Expected: no results (or documented justification in compose header)
```

**Pass criteria:**
- [ ] No hardcoded secrets in compose file or config
- [ ] Stack fails with a clear error if `.env` is missing required secrets
- [ ] `.env.example` contains only placeholder values
- [ ] Docker socket is not mounted unless required and documented

---

## 8 — Documentation

Verify the stack is documented well enough for someone else to deploy it.

- [ ] `README.md` exists in the tool directory
- [ ] README covers: what it is, architecture, setup steps, access URL, default credentials, useful commands, file layout
- [ ] `.env.example` has generation commands for every secret
- [ ] `docker-compose.yml` header comments list prerequisites, resource requirements, and non-obvious notes
- [ ] Any core stack changes (traefik config, shared volumes) are documented in the README

---

## Summary Checklist

Copy this into your PR or commit message when landing a new stack:

```
Testing validation for <tool>:
- [ ] 1. Infrastructure health — all containers up and healthy
- [ ] 2. Network & routing — Traefik routes correctly, no leaked ports
- [ ] 3. Database & persistence — connected, migrations ran, data survives restart
- [ ] 4. Authentication — login works with documented credentials
- [ ] 5. Provisioned content — dashboards/data sources/plugins loaded
- [ ] 6. Functional validation — tool performs its core function
- [ ] 7. Secrets & security — no hardcoded secrets, fail-fast on missing .env
- [ ] 8. Documentation — README, .env.example, compose header comments
```
