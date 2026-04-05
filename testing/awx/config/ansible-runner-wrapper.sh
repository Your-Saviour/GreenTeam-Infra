#!/bin/bash
# Wrapper to suppress stderr from ansible-runner worker.
# Docker (masquerading as podman) outputs warnings/tracebacks to stderr
# which leak into receptor's worker stream and break AWX's JSON parser.
exec /var/lib/awx/venv/awx/bin/ansible-runner "$@" 2>/tmp/ansible-runner-stderr.log
