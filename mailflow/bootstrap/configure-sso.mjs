// Uses the pinned backend image's database driver and credential encryption.
import pg from '/app/node_modules/pg/lib/index.js';
import { encrypt } from '/app/src/services/encryption.js';

const issuer = process.env.MAILFLOW_OIDC_ISSUER;
const clientId = process.env.MAILFLOW_OIDC_CLIENT_ID;
const clientSecret = process.env.MAILFLOW_OIDC_CLIENT_SECRET;
const adminEmail = process.env.MAILFLOW_BOOTSTRAP_ADMIN_EMAIL?.trim().toLowerCase();
if (!clientId || !clientSecret || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail || '')) {
  throw new Error('OIDC credentials and a valid bootstrap administrator email are required');
}
if (!/^[a-f0-9]{64}$/i.test(process.env.ENCRYPTION_KEY || '')) {
  throw new Error('ENCRYPTION_KEY must be 64 hexadecimal characters');
}
if (new URL(issuer).protocol !== 'https:') throw new Error('OIDC requires HTTPS');
const response = await fetch(`${issuer.replace(/\/$/, '')}/.well-known/openid-configuration`, {
  signal: AbortSignal.timeout(15000),
});
if (!response.ok) throw new Error('Authentik discovery failed');
const discovery = await response.json();
if (discovery.issuer !== issuer || !discovery.jwks_uri || !discovery.authorization_endpoint) {
  throw new Error('Authentik discovery does not match the configured issuer');
}

const client = new pg.Client({
  host: process.env.DB_HOST,
  database: 'mailflow',
  user: 'mailflow',
  password: process.env.DB_PASSWORD,
  connectionTimeoutMillis: 10000,
  statement_timeout: 30000,
});
try {
  await client.connect();
  await client.query('BEGIN');
  // Same lock as upstream registration: no race with first-user creation.
  await client.query('SELECT pg_advisory_xact_lock(7936352)');
  await client.query(`
    INSERT INTO oidc_providers
      (name, slug, issuer_url, client_id, client_secret, scopes, provisioning_mode,
       enabled, require_email_verified, allow_insecure, admin_group_claim,
       admin_group_value, rp_initiated_logout, login_match_claim)
    VALUES ('Authentik', 'authentik', $1, $2, $3, 'openid email profile groups',
            'open', true, false, false, 'groups', 'GROUP-GreenTeam', true, 'email')
    ON CONFLICT (slug) DO UPDATE SET
      name = EXCLUDED.name, issuer_url = EXCLUDED.issuer_url,
      client_id = EXCLUDED.client_id, client_secret = EXCLUDED.client_secret,
      scopes = EXCLUDED.scopes, provisioning_mode = EXCLUDED.provisioning_mode,
      enabled = true, require_email_verified = false, allow_insecure = false,
      admin_group_claim = EXCLUDED.admin_group_claim,
      admin_group_value = EXCLUDED.admin_group_value,
      rp_initiated_logout = true, login_match_claim = 'email', updated_at = NOW()
  `, [issuer, clientId, encrypt(clientSecret)]);
  // Upstream bypasses registration settings when users is empty. Seed a
  // passwordless admin so public first-user registration cannot claim the app.
  // First SSO login links this account and re-evaluates admin status from groups.
  await client.query(`
    INSERT INTO users (username, password_hash, is_admin)
    SELECT $1, NULL, true WHERE NOT EXISTS (SELECT 1 FROM users)
  `, [adminEmail]);
  await client.query(`
    INSERT INTO system_settings (key, value, updated_at)
    VALUES ('registration_open', 'false', NOW()), ('internal_auth_disabled', 'true', NOW())
    ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
  `);
  await client.query('COMMIT');
  console.log('Authentik SSO configured; password login and public registration disabled.');
} catch (error) {
  await client.query('ROLLBACK').catch(() => {});
  console.error('SSO bootstrap failed:', error.code || 'configuration error');
  process.exitCode = 1;
} finally {
  await client.end();
}
