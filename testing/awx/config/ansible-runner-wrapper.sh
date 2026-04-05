#!/bin/bash
# Wrapper for ansible-runner worker to fix Docker/podman stream compatibility.
# 1. Redirects stderr (Docker warnings/tracebacks) to a log file
# 2. Filters stdout to only pass through valid JSON lines (non-empty, starts with {)
#    because Docker adds empty lines and non-JSON output that breaks AWX's stream parser.
/var/lib/awx/venv/awx/bin/ansible-runner "$@" 2>/tmp/ansible-runner-stderr.log | while IFS= read -r line; do
  case "$line" in
    "{"*) printf '%s\n' "$line" ;;
  esac
done
