#!/bin/bash
# Override default 80-ca.sh to skip CA setup when certs already exist.
# The default script runs 'puppetserver ca setup' unconditionally,
# which crashes on restart because certs are already present.

if [ -f "/etc/puppetlabs/puppet/ssl/certs/ca.pem" ]; then
  echo "CA already initialized, skipping setup"
else
  echo "No existing CA found, running initial setup"
  # Build --subject-alt-names from DNS_ALT_NAMES env var
  if [ -n "$DNS_ALT_NAMES" ]; then
    SAN_ARGS=""
    IFS=',' read -ra NAMES <<< "$DNS_ALT_NAMES"
    for name in "${NAMES[@]}"; do
      SAN_ARGS="${SAN_ARGS:+${SAN_ARGS},}DNS:${name}"
    done
    puppetserver ca setup --subject-alt-names "$SAN_ARGS" --certname "$PUPPET_CERTNAME"
  else
    puppetserver ca setup
  fi
fi
