#!/bin/bash
# Ensure Puppet Server is configured to send reports to PuppetDB.
# Runs on every start since puppet.conf persists in a volume and
# env vars only apply on first setup.

puppet config set reports puppetdb --section server
puppet config set storeconfigs true --section server
puppet config set storeconfigs_backend puppetdb --section server
