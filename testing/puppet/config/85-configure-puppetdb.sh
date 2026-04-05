#!/bin/bash
# Ensure Puppet Server is configured to send reports to PuppetDB.

PUPPET_CONF="/etc/puppetlabs/puppet/puppet.conf"

# Add [master] section with reports if not already present
if ! grep -q '^reports' "$PUPPET_CONF" 2>/dev/null; then
  # Check if [master] section exists
  if grep -q '^\[master\]' "$PUPPET_CONF" 2>/dev/null; then
    sed -i '/^\[master\]/a reports = puppetdb' "$PUPPET_CONF"
  elif grep -q '^\[server\]' "$PUPPET_CONF" 2>/dev/null; then
    sed -i '/^\[server\]/a reports = puppetdb' "$PUPPET_CONF"
  else
    printf '\n[master]\nreports = puppetdb\nstoreconfigs = true\nstoreconfigs_backend = puppetdb\n' >> "$PUPPET_CONF"
  fi
  echo "PuppetDB reports enabled in puppet.conf"
else
  echo "PuppetDB reports already configured"
fi
