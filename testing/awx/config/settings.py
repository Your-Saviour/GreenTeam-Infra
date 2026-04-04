# AWX custom settings
# Mounted into /etc/tower/conf.d/custom.py (auto-loaded by AWX)

CSRF_TRUSTED_ORIGINS = [
    "https://awx.testing.blueteam.au",
]

ALLOWED_HOSTS = ["*"]

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SOCIAL_AUTH_REDIRECT_IS_HTTPS = True
