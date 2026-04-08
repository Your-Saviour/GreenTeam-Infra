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

   **Suggestion for design.md:** Add a note under Healthchecks — "If the container is scratch/distroless with no shell, CMD-SHELL healthchecks won't work. Check if the binary has a health subcommand. If not, document the limitation and rely on restart policy + Traefik routing for liveness."

2. **No `/api/health` endpoint.** The obvious healthcheck URL doesn't exist. The closest alternative is `/api/version` which returns 401 (Unauthorized) when the API is up — confirms liveness but requires no auth. This would work if the container had a shell to run curl/wget.

3. **Initial admin password only shown on first start.** The randomly generated password is printed to stdout only when the database is first initialised. If the postgres volume persists across container recreations, the password won't appear in logs again. Use `docker compose exec bloodhound ./bloodhound-cli resetpwd` to reset it — but note this also requires the container to have been started at least once.

### Things that worked well

- The three-container architecture (Postgres + Neo4j + app) started cleanly with `depends_on` + `service_healthy` on both databases.
- Neo4j 4.4 healthcheck via `wget` on port 7474 worked reliably.
- Traefik labels worked correctly — routing was confirmed by inspecting labels and testing via container IP.
- The app responded on port 8080 with clean 301 redirect to `/ui` and functional API login.
- 4GB VM was sufficient despite the 8GB recommendation — Neo4j + Postgres + app ran without OOM issues.
