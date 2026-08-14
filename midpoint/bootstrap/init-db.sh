#!/bin/bash
set -euo pipefail

cd /opt/midpoint
bin/midpoint.sh init-native

if bin/ninja.sh -B info >/tmp/ninja-info.log 2>&1; then
  echo "Repository schema already initialized"
else
  cat /tmp/ninja-info.log
  bin/ninja.sh run-sql --create --mode REPOSITORY
  bin/ninja.sh run-sql --create --mode AUDIT
fi
