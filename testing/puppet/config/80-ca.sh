#!/bin/bash
# Override default 80-ca.sh to skip CA setup when certs already exist.
# The default script runs 'puppetserver ca setup' unconditionally,
# which crashes on restart because certs are already present.

if [ -f "/etc/puppetlabs/puppet/ssl/certs/ca.pem" ]; then
  echo "CA already initialized, skipping setup"
else
  echo "No existing CA found, running initial setup"
  puppetserver ca setup
fi
