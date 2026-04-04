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

# ── Instance Registration & Execution ───────────────────────────────────────
# IS_K8S must be False so AWX does not attempt to launch jobs as K8s pods.
IS_K8S = False

# CLUSTER_HOST_ID must match the hostname used in provision_instance.
# This is how AWX decides work_type == 'local' (receptor work-command)
# instead of trying to route to a remote execution node.
CLUSTER_HOST_ID = 'awxtask'

AWX_AUTO_DEPROVISION_INSTANCES = True
SYSTEM_UUID = str(uuid.uuid5(uuid.NAMESPACE_DNS, 'awx.testing.blueteam.au'))

# Tell receptor where its socket lives (must match receptor.conf control-service)
RECEPTOR_SOCKET_PATH = '/tmp/receptor/receptor.sock'
RECEPTOR_RELEASE_WORK = True
RECEPTOR_LOG_LEVEL = 'info'

# ── Execution Environments ──────────────────────────────────────────────────
# The EE image that will be used for "local" execution via ansible-runner.
# Because IS_K8S=False and we use receptor work-command (worktype: local),
# ansible-runner runs INSIDE the awx-task container — the EE image is only
# used for metadata/defaults. The awx:24.6.1 image already has ansible-runner.
GLOBAL_JOB_EXECUTION_ENVIRONMENTS = [
    {'name': 'AWX EE (latest)', 'image': 'quay.io/ansible/awx-ee:latest'},
]
CONTROL_PLANE_EXECUTION_ENVIRONMENT = 'quay.io/ansible/awx-ee:latest'

# ── Instance Group Defaults ─────────────────────────────────────────────────
# These control the "default" execution queue. We do NOT want it to be a
# container group (that's the K8s path). register_queue in the entrypoint
# creates the group; these settings ensure it has no pod_spec_override.
DEFAULT_EXECUTION_QUEUE_NAME = 'default'
DEFAULT_CONTROL_PLANE_QUEUE_NAME = 'controlplane'

# ── Job Isolation ───────────────────────────────────────────────────────────
# Base path for ansible-runner's temporary job directories inside the container
AWX_ISOLATION_BASE_PATH = '/tmp'
AWX_ISOLATION_SHOW_PATHS = [
    '/var/lib/awx/projects',
]

# ── Hosts & Security ────────────────────────────────────────────────────────
ALLOWED_HOSTS = ['*']

CSRF_TRUSTED_ORIGINS = [
    'https://awx.testing.blueteam.au',
]

SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SOCIAL_AUTH_REDIRECT_IS_HTTPS = True
