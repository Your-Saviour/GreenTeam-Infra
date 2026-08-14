# midPoint JIT access

This stack deploys midPoint 4.10.3 as the request, approval, validity, and audit plane for temporary Authentik group membership. Authentik remains authoritative for identities and login. The supplied catalogue groups are deliberately not bound to any application.

## Security contract

- Public UI: `https://access.gt.blueteam.au/midpoint`
- OIDC issuer: `https://auth.blueteam.au/application/o/midpoint/`
- Redirect URI: `https://access.gt.blueteam.au/midpoint/login/oauth2/code/authentik`
- SCIM base: `https://auth.blueteam.au/source/scim/midpoint-jit/v2`
- Correlation: exact, case-sensitive `preferred_username` to midPoint `name`
- Managed group namespace: `jit-*`; never correlate or manage `authentik Admins`
- Standard: self-service, at most four hours
- Sensitive: at most one hour, reason and ticket required, approval by a different approver
- Expired membership target: removal in Authentik within two minutes

The local administrator endpoint, `/midpoint/auth/gui-login-form`, is retained for break-glass use. Store that password offline and use OIDC for ordinary access. TLS verification is always enabled.

## Prerequisites and Authentik setup

Start the repository root stack first so the external `proxy` network exists. Point `access.gt.blueteam.au` at Traefik.

In Authentik:

1. Create `jit-requesters`, `jit-approvers`, `jit-access-standard`, and `jit-access-sensitive` as ordinary, non-superuser groups. Do not nest or correlate `authentik Admins`.
2. Create an OAuth2/OIDC provider and application with slug `midpoint`, redirect URI above, and scopes `openid profile email`. Ensure `preferred_username` is stable and unique.
3. Bind the application only to `jit-requesters` and `jit-approvers`.
4. Create a writable SCIM source with slug `midpoint-jit`, base URL above, and a dedicated high-trust bearer token. Its permission scope must cover user/group discovery and member PATCH for `jit-*`, but not user create/update/delete or non-JIT groups. Never reuse an Authentik user/API token.
5. Leave all four groups unbound to applications. They grant no downstream access until deliberate onboarding.

For a command-line deployment, create local configuration:

```bash
cd midpoint
cp .env.example .env
openssl rand -base64 36 | tr -d '\n' # database password
openssl rand -base64 36 | tr -d '\n' # independent break-glass password
openssl rand -base64 48 | tr -d '\n' # OIDC secret, if generated locally
chmod 600 .env
```

Fill every blank value. Compose `${VAR:?…}` guards fail closed. The populated `.env` is ignored by Git.

For Dockhand, create a stack from this directory's `docker-compose.yml` and enter the same variables in Dockhand's stack environment editor instead of creating `.env`. All five secrets (`MIDPOINT_PG_PASSWORD`, `MIDPOINT_ADMIN_PASSWORD`, `MIDPOINT_OIDC_CLIENT_ID`, `MIDPOINT_OIDC_CLIENT_SECRET`, and `MIDPOINT_SCIM_TOKEN`) must be present before deployment. Keep secret values in Dockhand's protected environment storage where available.

## First deployment

```bash
docker compose config --quiet
docker compose up -d
docker compose logs -f midpoint-connector-init midpoint-db-init midpoint-server
```

Dockhand users deploy the complete stack once after entering its environment variables. The one-shot bootstrap service starts automatically after `midpoint-server` is healthy; no separate console command is required. An exited `midpoint-bootstrap` container with exit code zero means bootstrap completed successfully. Redeploying the stack safely reruns it.

Connector initialization downloads only SCIM connector 1.2.9 and verifies SHA-256 `c13d51188510f16a53379f3f7e640711aa9bc08c9eb31378417080298207db7a`. Database initialization uses `init-native` followed by Ninja repository and audit schemas. Bootstrap validates public OIDC discovery and authenticated SCIM discovery before rendering tracked objects into a temporary directory. Fixed OIDs and REST replacement make it idempotent; the temporary plaintext rendering is deleted when it exits, while protected values are encrypted by the midPoint repository.

After bootstrap, test the resource and inspect its generated schema in midPoint. Connector configuration-property names can vary by connector build; a failed resource test must be resolved before enabling either catalogue role. Confirm that the two reconciliation tasks run every five minutes and the validity scanner every minute.

## Production acceptance tests

Do not bind a JIT group to an application until all checks pass in a non-production Authentik tenant:

- OIDC is the default flow; a non-requester is denied; local break-glass still works.
- Only exact-username users and `jit-*` groups import. Ordinary users, non-JIT groups, and `authentik Admins` cannot be changed.
- The resource exposes no user/group create or delete operation. Capture SCIM traffic and prove grants and removals use group-member PATCH only.
- Standard requests default to and cannot exceed four hours.
- Sensitive requests reject a missing reason/ticket, duration over one hour, requester approval, and self-approval; an independent `jit-approvers` member can approve or reject.
- Relinquishment needs no approval. Expiry produces a removal within two minutes.
- Request, decision, grant, relinquishment, expiry, resource-stage operation, and provisioning failure appear in audit history.
- With Authentik unavailable, grant/removal failures remain operational errors and retry/reconcile successfully after recovery; no request is shown as successfully expired before removal succeeds.

The tracked roles include machine-readable policy metadata. Validate and finish the approval/validity enforcement in the midPoint GUI against the generated connector schema before production: midPoint connector schemas and approval GUI definitions are runtime-generated and cannot be safely guessed offline. Export the accepted objects back into `objects/` so subsequent bootstrap runs reproduce them.

## Onboard an application role

1. Clone the nearest catalogue role and retain its maximum duration/approval policy.
2. Create a narrowly named `jit-access-<application>-<role>` Authentik group.
3. Restrict the resource entitlement filter/mapping to the `jit-*` namespace and associate the cloned role with exactly that group.
4. Test grant, rejection, relinquishment, expiry, Authentik outage, and audit behavior.
5. Only then bind the group to one Authentik application or downstream OIDC claim/role mapping. Record the application owner and rollback procedure.

Removing Authentik membership is authoritative only for newly issued OIDC claims. Existing Homarr, Wiki.js, Vaultwarden, or other application sessions can survive until token refresh, session expiry, or login. Immediate downstream session revocation is outside this stack's v1 guarantee.

## Backup, restore, and upgrade

Back up both state components together:

```bash
docker compose exec -T midpoint-postgresql pg_dump -U midpoint -d midpoint -Fc > midpoint.dump
docker run --rm -v midpoint_midpoint_home:/source:ro -v "$PWD":/backup alpine:3.21 tar czf /backup/midpoint-home.tgz -C /source .
```

Use the configured database/user values when they differ. Restore into stopped, empty replacement volumes, restore PostgreSQL with `pg_restore`, restore `midpoint_home`, then start and run resource, reconciliation, expiry, and audit tests. Test restores regularly; an untested backup is not production-ready.

For upgrades, read Evolveum release and sequential-upgrade notes, back up, pin the new server and init images to the same maintenance version, download and checksum the matching connector, run Ninja pre-upgrade/verify and required repository plus audit migrations, then repeat acceptance tests. Never skip required intermediate versions.

## Troubleshooting

- `proxy` missing: start the root Compose stack.
- Bootstrap remains running or exits non-zero: inspect the `midpoint-bootstrap` logs in Dockhand. It should run once and exit zero after the server becomes healthy.
- Connector init fails: do not bypass checksum verification; verify the pinned artifact URL/version.
- OIDC redirect mismatch: compare Authentik's exact URI with the URI above, including `/midpoint`.
- Login correlation fails: inspect `preferred_username`; do not fall back to email or mutable display name.
- Bootstrap fails before import: check public DNS, certificate chain, issuer discovery, SCIM URL, and token permissions. TLS verification must stay enabled.
- Removal is late: inspect the validity task, resource-stage audit, pending operation, and SCIM response. Do not manually mark the request successful.
- A user retains application access: force a fresh login/token refresh; downstream sessions are outside the two-minute membership guarantee.
