"""Run from mailflow/: python3 verify-sso.py [https://mailflow.blueteam.au]."""
import json
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


base = (sys.argv[1] if len(sys.argv) > 1 else "https://mailflow.blueteam.au").rstrip("/")
opener = urllib.request.build_opener(NoRedirect)
with opener.open(base + "/api/auth/oidc/providers", timeout=20) as response:
    providers = json.load(response)["providers"]
assert any(p["slug"] == "authentik" for p in providers), "Authentik is missing"
try:
    opener.open(base + "/auth/oidc/authentik/start", timeout=20)
    raise AssertionError("SSO did not redirect")
except urllib.error.HTTPError as response:
    assert response.code == 302, response.code
    url = urllib.parse.urlparse(response.headers["Location"])
    params = urllib.parse.parse_qs(url.query)
    assert url.scheme == "https" and url.hostname == "auth.blueteam.au", "Wrong IdP"
    assert params["redirect_uri"] == [base + "/auth/oidc/authentik/callback"]
    assert params["code_challenge_method"] == ["S256"], "PKCE is missing"
    assert params["state"] and params["nonce"]
    assert "secure" in response.headers.get("Set-Cookie", "").lower(), "Insecure session cookie"

sql = """
SELECT
  (SELECT count(*) FROM oidc_providers WHERE slug = 'authentik' AND enabled
    AND client_secret LIKE 'enc:v1:%' AND NOT allow_insecure
    AND provisioning_mode = 'open' AND admin_group_claim = 'groups'
    AND admin_group_value = 'GROUP-GreenTeam') = 1
  AND (SELECT value FROM system_settings WHERE key = 'internal_auth_disabled') = 'true'
  AND (SELECT value FROM system_settings WHERE key = 'registration_open') = 'false'
  AND EXISTS (SELECT 1 FROM users);
"""
result = subprocess.check_output([
    "docker", "compose", "exec", "-T", "postgres", "psql", "-U", "mailflow",
    "-d", "mailflow", "-At", "-c", sql,
], text=True).strip()
assert result == "t", "SSO database configuration or registration protection is missing"
request = urllib.request.Request(
    base + "/api/auth/login", data=b'{"username":"sso-check","password":"invalid"}',
    headers={"Content-Type": "application/json"},
)
try:
    opener.open(request, timeout=20)
    raise AssertionError("Password login is enabled")
except urllib.error.HTTPError as response:
    assert response.code == 403, "Password login is not explicitly disabled"
print("SSO provider, HTTPS redirect, PKCE, secure cookie, encrypted secret, and login policy checks passed.")
