# AWX production settings
# Mounted to /etc/tower/settings.py (the primary file loaded by awx.settings.production)
#
# AWX's production.py clears DATABASES and SECRET_KEY, then loads this file.
# Environment variables like DATABASE_HOST are NOT auto-read by AWX --
# this file bridges env vars into Django settings.

import os
import uuid

# ── Database ─────────────────────────────────────────────────────────────────
DATABASES = {
    'default': {
        'ATOMIC_REQUESTS': True,
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DATABASE_NAME', 'awx'),
        'USER': os.environ.get('DATABASE_USER', 'awx'),
        'PASSWORD': os.environ.get('DATABASE_PASSWORD', ''),
        'HOST': os.environ.get('DATABASE_HOST', 'postgres'),
        'PORT': os.environ.get('DATABASE_PORT', '5432'),
    }
}

# ── Secret Key ───────────────────────────────────────────────────────────────
# Read from env first, fall back to /etc/tower/SECRET_KEY file.
_secret_key = os.environ.get('SECRET_KEY', '')
if not _secret_key and os.path.exists('/etc/tower/SECRET_KEY'):
    with open('/etc/tower/SECRET_KEY', 'rb') as f:
        _secret_key = f.read().strip().decode()
SECRET_KEY = _secret_key

# ── Redis / Cache / Broker ───────────────────────────────────────────────────
# Use TCP connections to the redis container (not unix sockets).
_redis_host = os.environ.get('REDIS_HOST', 'redis')
_redis_port = os.environ.get('REDIS_PORT', '6379')

BROKER_URL = 'redis://{}:{}/0'.format(_redis_host, _redis_port)

CHANNEL_LAYERS = {
    'default': {
        'BACKEND': 'channels_redis.core.RedisChannelLayer',
        'CONFIG': {
            'hosts': [BROKER_URL],
            'capacity': 10000,
            'group_expiry': 157784760,  # 5 years
        },
    },
}

CACHES = {
    'default': {
        'BACKEND': 'awx.main.cache.AWXRedisCache',
        'LOCATION': 'redis://{}:{}/1'.format(_redis_host, _redis_port),
    }
}

# ── Websocket ────────────────────────────────────────────────────────────────
BROADCAST_WEBSOCKET_SECRET = SECRET_KEY
BROADCAST_WEBSOCKET_PORT = 8052
BROADCAST_WEBSOCKET_PROTOCOL = 'http'
BROADCAST_WEBSOCKET_VERIFY_CERT = False

# ── Instance Registration ───────────────────────────────────────────────────
# Required for provision_instance to work outside K8s.
# Without this, awx-task crashes with "only intended for use in K8s installs".
AWX_AUTO_DEPROVISION_INSTANCES = True
SYSTEM_UUID = str(uuid.uuid5(uuid.NAMESPACE_DNS, 'awx.testing.blueteam.au'))

# ── Hosts & Security ────────────────────────────────────────────────────────
ALLOWED_HOSTS = ['*']

CSRF_TRUSTED_ORIGINS = [
    'https://awx.testing.blueteam.au',
]

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SOCIAL_AUTH_REDIRECT_IS_HTTPS = True
