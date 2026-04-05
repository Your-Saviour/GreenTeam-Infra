#!/bin/bash
# Install Forge modules from Puppetfile using r10k.
# Runs on every start but r10k skips modules already installed.

PUPPETFILE="/etc/puppetlabs/code/environments/production/Puppetfile"

if [ ! -f "$PUPPETFILE" ]; then
  echo "No Puppetfile found, skipping module install"
  exit 0
fi

# r10k ships with puppetserver; install modules into the environment's modules dir
r10k puppetfile install \
  --puppetfile "$PUPPETFILE" \
  --moduledir /etc/puppetlabs/code/environments/production/modules \
  --verbose

echo "Module install complete"
