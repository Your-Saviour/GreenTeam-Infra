# MailFlow

Standalone MailFlow stack using the [upstream prebuilt images](https://github.com/maathimself/mailflow/blob/v4.1.1/docker-compose.ghcr.yml), pinned to 4.1.1. Traefik terminates HTTPS at `https://mailflow.blueteam.au` and forwards to MailFlow's nginx frontend. Authentik provides SSO. The backend has outbound access for IMAP, SMTP, and OAuth; PostgreSQL and Redis use an isolated internal network. No host ports are published.

## Deploy

Start the repository's core stack first so Traefik and the external `proxy` network exist. Point DNS for `mailflow.blueteam.au` at that host (or change `MAILFLOW_DOMAIN`).

From the repository root:

```bash
cd mailflow
cp .env.example .env
```

Generate three separate secrets with `openssl rand -hex 32` and fill in `SESSION_SECRET`, `DB_PASSWORD`, and `ENCRYPTION_KEY` in `.env`. Set the Authentik client ID/secret and the bootstrap administrator's Authentik email as described below.

```bash
docker compose config --quiet
docker compose up -d
docker compose ps
```

For Dockhand, deploy the entire `mailflow/` directory, including `bootstrap/configure-sso.mjs`, and enter the values from `.env.example` in its environment editor. Pasting only the Compose YAML is insufficient because the startup job requires the bootstrap bind mount.

Open `https://mailflow.blueteam.au` and choose Authentik. Authorized users are provisioned on first SSO login. Connect existing mailboxes in the UI; MailFlow is an email client and requires existing IMAP/SMTP accounts. Signing into MailFlow does not grant it access to a mailbox automatically.

Optional Microsoft/Google mailbox OAuth applications can be configured in Settings → Email providers.

## Authentik SSO

The live Authentik application is `mailflow`, with a confidential OAuth2 provider and these settings:

| Setting | Value |
| --- | --- |
| Launch URL | `https://mailflow.blueteam.au` |
| Strict redirect URI | `https://mailflow.blueteam.au/auth/oidc/authentik/callback` |
| Issuer | `https://auth.blueteam.au/application/o/mailflow/` |
| Scopes | `openid email profile groups` |
| Subject | Stable user UUID |
| Claims in ID token | Enabled |
| Signing key | Existing Authentik signing certificate |
| Authorization flow | Default explicit consent |
| Application policy mode | Any |
| Access bindings | `GROUP-GreenTeam` or `GROUP-MailFlowUsers` |

Standard `openid`, `email`, and `profile` mappings are attached. The dedicated **MailFlow groups** scope mapping returns a claim object:

```python
return {"groups": [group.name for group in request.user.ak_groups.all()]}
```

Set `MAILFLOW_OIDC_CLIENT_ID` and `MAILFLOW_OIDC_CLIENT_SECRET` from this provider. Set `MAILFLOW_BOOTSTRAP_ADMIN_EMAIL` to an existing `GROUP-GreenTeam` member's email. Changing the public hostname also requires updating Authentik's strict redirect URI and launch URL.

The `sso-bootstrap` job waits for backend migrations, validates HTTPS issuer discovery, encrypts the client secret with MailFlow's own encryption helper, and upserts the provider. It disables local password login and registration. On an empty database it seeds a passwordless admin account to prevent MailFlow's first-user registration bypass; the account is linked and its admin role re-evaluated on SSO login. The frontend waits until bootstrap succeeds before it starts.

Members of `GROUP-GreenTeam` become MailFlow admins; other admitted users become regular users. Add regular users to `GROUP-MailFlowUsers` in Authentik. Admin status is re-evaluated at each SSO login. Group removal blocks future logins but does not terminate existing MailFlow sessions immediately. RP-initiated logout is enabled.

Authentik's standard email mapping reports `email_verified=false`. MailFlow therefore accepts email claims from this trusted provider without requiring that flag; TLS, issuer, token signature, audience, state, nonce, and PKCE verification remain enabled. Treat Authentik email addresses as administrator-managed identities: provision unique addresses and prevent users from claiming another user's address. Local public signup remains disabled.

Bootstrap reapplies the provider and login policy whenever it runs; `.env` and this script are the source of truth for these fields. To reapply after changing credentials:

```bash
docker compose run --rm --no-deps sso-bootstrap
```

Verify routing, PKCE, secure cookies, encrypted configuration, and login policy from the deployment directory:

```bash
python3 verify-sso.py
```

This smoke check does not complete an interactive Authentik login. Also sign in as a GreenTeam administrator and as an allowed regular user, and verify that a user outside both access groups is denied.

## Data and updates

PostgreSQL and Redis persist in named volumes. Back up the database and `.env`, especially `ENCRYPTION_KEY`, which is needed to decrypt stored mail credentials and the OIDC client secret. The admin Settings → Backup export does not include `.env`. `docker compose down` preserves volumes; `docker compose down -v` deletes them.

To upgrade, back up first, review the [upstream release notes](https://github.com/maathimself/mailflow/releases), change `MAILFLOW_VERSION`, then run `docker compose pull && docker compose up -d`. Database migrations run automatically on startup.
