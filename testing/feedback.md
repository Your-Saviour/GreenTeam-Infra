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
