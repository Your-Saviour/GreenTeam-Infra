# Production Termix

Termix 26.11.0 at `https://termix.blueteam.au`, behind the existing Traefik
`proxy` network and Let's Encrypt resolver. The standard image bundles SSO
1.0.5 and enables it on a fresh volume when `OIDC_CLIENT_ID` is configured.
No separate plugin download, database, Redis, or guacd is required for this
single-instance deployment. The remote desktop plugin uses its built-in engine.

## Live deployment

Deployed on `root@blueteam.au` in `/opt/GreenTeam-Infra/termix`. The Authentik
application is `termix`, with access bound to `GROUP-GreenTeam` (Termix admins)
or `GROUP-TermixUsers` (regular users). The latter group starts empty; add users
in Authentik when they need access. The provider uses the callback and scope
mapping documented below.

The server's `.env` contains the generated encryption keys and OIDC credentials
with mode `600`; it is excluded from Git. Use `docker compose` from that directory
to manage the deployment. The local ignored `termix/.env` has the same initial
credentials and must also be protected. Back up the secrets securely with the
data volume. Complete the first admin SSO login and provision a recovery account
as described below.

## Authentik prerequisites

Create a confidential OAuth2/OIDC provider and application in the existing
`https://auth.blueteam.au` admin interface:

| Setting | Value |
| --- | --- |
| Application slug | `termix` |
| Launch URL | `https://termix.blueteam.au` |
| Strict redirect URI | `https://termix.blueteam.au/plugin-api/sso/callback` |
| Issuer mode | Per-provider |
| Issuer | `https://auth.blueteam.au/application/o/termix/` |
| Scopes | `openid email profile groups` |
| Optional back-channel logout URI | `https://termix.blueteam.au/plugin-api/sso/backchannel-logout` |
| Application access bindings | `GROUP-GreenTeam` or `GROUP-TermixUsers` |

Create `GROUP-TermixUsers` for regular users. Bind the two groups with **ANY**
policy matching, so either group grants access. Configure these bindings before
starting Termix: an unbound Authentik application may admit every Authentik user.
Keep the usual `openid`, `email`, and `profile` scope mappings and attach a
`groups` scope mapping returning:

```python
return {"groups": [group.name for group in request.user.ak_groups.all()]}
```

Members of `GROUP-GreenTeam` receive Termix admin rights; other admitted users
receive normal accounts. Ensure `preferred_username` is stable and unique.
Copy the provider's client ID and secret into the stack environment. No
Authentik API token is needed by Termix.

For host sharing, create a custom role with name `greenteam` and display name
`GreenTeam` in Settings, Roles. The deployment sets
`OIDC_ROLE_MAP=GROUP-GreenTeam:greenteam`, assigning that role to GreenTeam
members on their next SSO login. System roles such as Admin are hidden from
the sharing picker. Share hosts or folders with the custom GreenTeam role;
the mapping itself does not share hosts automatically.

## Deploy

Point DNS for `termix.blueteam.au` at the production Traefik host. Start the root
core stack first to create `proxy`. Termix needs outbound access to Authentik
and the SSH targets; no Termix ports are published on the host.

```sh
cd termix
cp .env.example .env
chmod 600 .env
# Fill in the Authentik credentials and generate each of the four secrets:
openssl rand -hex 32
docker compose config --quiet
docker compose pull
docker compose up -d --wait
```

For Dockhand, deploy `termix/docker-compose.yml` as a separate production stack
and enter every variable from `.env.example` in its environment editor. It
needs no relative bind mounts or startup scripts. Keep the Compose project
name `termix-production` stable so it reuses the same data volume.

Open the site and sign in through SSO as a `GROUP-GreenTeam` member first.
Confirm **Single sign-on** stays enabled in the initial plugin picker. Public
password registration and password resets are disabled; SSO account creation
is enabled and admission is controlled by the Authentik bindings above.

As an admin, provision a local recovery administrator in Settings, Users and
store its credentials securely. Password login stays enabled and automatic
SSO redirection stays off so that account remains accessible during an IdP
outage. This Compose file does not create a recovery account automatically.

The testing stack and its volume are separate. This is a fresh deployment;
do not copy its legacy salt or attach its database without following upstream
upgrade instructions. Environment configuration enables SSO on first boot;
if someone later disables or removes the plugin, restore it in Plugins.

## Acceptance checks

```sh
docker compose ps
docker compose logs --tail=100 termix
curl --fail --silent --show-error https://termix.blueteam.au/ > /dev/null
curl --fail --silent --show-error https://termix.blueteam.au/plugin-api/sso/config
```

The SSO config should report the expected client ID and issuer, without a
client secret. Complete an interactive SSO login and verify the redirect URI
uses HTTPS and `/plugin-api/sso/callback`. Check admin login, regular-user
login, denial for a user outside both bound groups, and local recovery login.
Add an SSH host and open a terminal to verify outbound reachability and
WebSocket forwarding. Recreate the container and confirm hosts persist.

Group and role changes take effect on subsequent logins. Removing access
does not guarantee immediate termination of existing Termix or SSH sessions.

## Backups and upgrades

Back up the complete `termix-production_termix_data` volume and all four
secrets together, encrypted and off-host. The volume holds the encrypted
SQLite database, plugins, uploads, and any recordings. For a consistent
filesystem backup, stop Termix, snapshot/archive the volume using your host
backup tooling, and start it again. Test restoration with the same secrets.
Never use `docker compose down -v` on the production stack.

Before an upgrade, take a backup and review upstream release notes. Change
`TERMIX_VERSION` deliberately, then pull and run `docker compose up -d --wait`.
Repeat the acceptance checks. Roll back by restoring both the previous image
and its pre-upgrade volume backup, since database migrations may prevent
image-only rollback.

Upstream references: [release](https://github.com/Termix-SSH/Termix/releases/tag/v26.11.0),
[bundled plugins](https://github.com/Termix-SSH/Termix/blob/v26.11.0/docker/bundled-plugins.json),
[SSO](https://docs.termix.site/plugins/sso/),
[environment variables](https://docs.termix.site/configure/environment-variables/).
