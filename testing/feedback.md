# Testing Stack — Process Feedback

Issues and improvements noted during stack deployments.

---

## DFIR-IRIS (2026-04-08)

### Issues encountered

1. **Image entrypoint not set in Dockerfile.** The `ghcr.io/dfir-iris/iriswebapp_app` image has `CMD [python3]` as its default — the upstream compose overrides it with `command: ["./iris-entrypoint.sh", "iriswebapp"]`. Without this, the container exits immediately with code 0 and no logs, making it hard to diagnose. The worker similarly needs its command set explicitly via `./wait-for-iriswebapp.sh` + `./iris-entrypoint.sh iris-worker`.

   **Suggestion for design.md or workflow.md:** Add a note under common issues — "Container exits immediately with code 0 and no logs: the image likely expects a command override. Check the upstream compose for `command:` or `entrypoint:` directives."

2. **Celery healthcheck too heavy.** The obvious worker healthcheck (`celery -A app.celery inspect ping`) bootstraps the full IRIS application on every invocation, making it too slow and resource-heavy for a 30s interval check. Had to fall back to `pgrep -f celery` which only verifies the process is running, not that it's responsive. This is a general risk with Python/Celery apps.

   **Suggestion for design.md:** Add `pgrep -f <process>` as a healthcheck pattern for workers where the native CLI check is too expensive.

3. **Network label mismatch when pre-creating `testing-proxy`.** The workflow says to create the network with `docker network create proxy` OR start the main compose first. If you run `docker network create testing-proxy` manually and then `docker compose up -d`, compose warns about incorrect labels. Not harmful, but noisy.

   **Suggestion for workflow.md:** Remove the `docker network create` step — just say "start the core stack first" since compose creates the network with correct labels.

4. **No DNS for throwaway VMs.** The Traefik labels use `*.testing.blueteam.au` hostnames, but throwaway CloudLab VMs don't have DNS records for those subdomains. Testing requires either `/etc/hosts` entries, `curl -H "Host: ..."` overrides, or temporarily changing the Traefik host rule on the VM to use the CloudLab DNS name.

   **Suggestion for workflow.md:** Add a note under the "Deploy" section about how to access services on the VM — either edit `/etc/hosts` locally, use curl with Host headers, or temporarily swap the Traefik host rule to the VM's CloudLab hostname.

### Things that worked well

- The skeleton in `design.md` made the compose file straightforward to build — just fill in the blanks.
- The `.env.example` pattern with `${VAR:?error}` caught missing secrets immediately on startup.
- The `depends_on` + `condition: service_healthy` chain (postgres → app → worker) ensured clean startup ordering.
- Skipping the upstream nginx container in favour of Traefik was a clean simplification with no issues.

---

## BloodHound CE (2026-04-08)

### Issues encountered

1. **Scratch/distroless container image — no shell.** The `specterops/bloodhound` image is built from scratch with only the Go binary (`/bloodhound`). There is no `/bin/sh`, no `curl`, no `wget`. This means `CMD-SHELL` healthchecks are impossible. The `/bloodhound` binary only supports `-configfile` and `-version` flags — no health subcommand. Had to remove the healthcheck entirely and document the limitation.

   **Suggestion for design.md:** Add a note under Healthchecks — "If the container is scratch/distroless with no shell, CMD-SHELL healthchecks won't work. Check if the binary has a health subcommand. If not, do NOT define a healthcheck at all — Traefik's Docker provider filters out containers with 'starting' or 'unhealthy' health status, so a broken healthcheck prevents routing entirely. Omit the healthcheck and rely on restart policy + Traefik routing for liveness."

2. **No `/api/health` endpoint.** The obvious healthcheck URL doesn't exist. The closest alternative is `/api/version` which returns 401 (Unauthorized) when the API is up — confirms liveness but requires no auth. This would work if the container had a shell to run curl/wget.

3. **Initial admin password only shown on first start.** The randomly generated password is printed to stdout only when the database is first initialised. If the postgres volume persists across container recreations, the password won't appear in logs again. Use `docker compose exec bloodhound ./bloodhound-cli resetpwd` to reset it — but note this also requires the container to have been started at least once.

### Things that worked well

- The three-container architecture (Postgres + Neo4j + app) started cleanly with `depends_on` + `service_healthy` on both databases.
- Neo4j 4.4 healthcheck via `wget` on port 7474 worked reliably.
- Traefik labels worked correctly — routing was confirmed by inspecting labels and testing via container IP.
- The app responded on port 8080 with clean 301 redirect to `/ui` and functional API login.
- 4GB VM was sufficient despite the 8GB recommendation — Neo4j + Postgres + app ran without OOM issues.

---

## Caldera (2026-04-09)

### Issues encountered

1. **Docker Hub image is abandoned.** The `mitre/caldera` image on Docker Hub is from July 2021 (Python 3.8, Caldera ~4.x). It appeared to start but never actually bound port 8888. The actively maintained image is `ghcr.io/mitre/caldera` on GitHub Container Registry (March 2025, Python 3.11, Caldera 5.2.0).

   **Suggestion for design.md:** Add a note under "Prefer official images" — always verify Docker Hub images are actively maintained. Check the `Created` date with `docker image inspect --format '{{.Created}}'`. For MITRE projects, prefer GHCR (`ghcr.io/mitre/*`) over Docker Hub.

2. **No curl/wget in container image.** The GHCR Caldera image doesn't include curl or wget. Healthchecks must use `python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8888')"` instead. This is a variant of the distroless healthcheck issue from BloodHound, but with Python available as a fallback.

   **Suggestion for design.md:** Add Python urllib as a healthcheck pattern alongside curl and wget.

3. **`local.yml` is the main config, not a merge overlay.** When Caldera is started with `conf/local.yml` present, it uses it as the **sole** config file — it does NOT merge with `default.yml`. Missing keys become `None` and cause startup errors (NoneType exceptions for contacts, requirements, etc.). The `local.yml` must contain ALL keys from `default.yml`.

   **Suggestion for design.md or workflow.md:** Add a note about config file behaviour — "Check whether the tool merges config files or uses one as the sole source. If it replaces entirely, the config template must include ALL required keys, not just overrides."

4. **Slow first start due to atomic plugin.** The `atomic` plugin downloads the full Atomic Red Team test repository on first start. This adds 30-60 seconds to initial startup and consumes significant CPU. The `start_period` for the healthcheck needs to account for this.

5. **Deploy testing on the VM must use the actual `testing/docker-compose.yml` from the repo** — not a simplified stand-in. The core stack includes Dockhand, access logging, dashboard auth, and CrowdSec bouncer config. Deploying a stripped-down version defeats the purpose of integration testing.

   **Update to workflow.md:** The "Deploy" section should explicitly state to use the real `testing/docker-compose.yml` and `testing/traefik/` configs, not write custom ones.

### Things that worked well

- Single-container architecture (no external DB) made the compose file simple.
- Agent communication ports (TCP, UDP, WebSocket, SSH, FTP, DNS) published correctly alongside Traefik-proxied web UI.
- API responded through Traefik with key-based auth — 29 adversaries and 1,838 abilities loaded from ATT&CK + Atomic Red Team.
- 4GB VM was more than sufficient for a single-container stack.
