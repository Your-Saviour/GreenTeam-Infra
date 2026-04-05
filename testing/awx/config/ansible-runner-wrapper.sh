#!/usr/bin/env python3
"""Wrapper for ansible-runner worker that filters non-JSON lines from stdout.

Docker (masquerading as podman) adds empty lines and non-JSON output that
break AWX's ansible_runner.streaming.Processor JSON parser. This wrapper
only passes through lines that are valid JSON objects.
"""
import subprocess
import sys

proc = subprocess.Popen(
    ['/var/lib/awx/venv/awx/bin/ansible-runner'] + sys.argv[1:],
    stdin=sys.stdin,
    stdout=subprocess.PIPE,
    stderr=open('/tmp/ansible-runner-stderr.log', 'w'),
)

for line in proc.stdout:
    stripped = line.strip()
    if stripped and stripped.startswith(b'{'):
        sys.stdout.buffer.write(line)
        sys.stdout.buffer.flush()

proc.wait()
sys.exit(proc.returncode)
