#!/bin/sh
set -eu

version=1.2.9
expected=c13d51188510f16a53379f3f7e640711aa9bc08c9eb31378417080298207db7a
directory=/opt/midpoint/var/icf-connectors
target="$directory/connector-scim2-$version-fat.jar"
url="https://github.com/ExclamationLabs/connector-scim2/releases/download/V$version/connector-scim2-1.2.9-1751303081596-fat.jar"

mkdir -p "$directory"
mkdir -p /opt/midpoint/var/schema
cp /bootstrap/jit-extension.xsd /opt/midpoint/var/schema/jit-extension.xsd
if [ -f "$target" ] && echo "$expected  $target" | sha256sum -c - >/dev/null 2>&1; then
  echo "SCIM connector $version already installed and verified"
  exit 0
fi

temporary="$target.part"
rm -f "$temporary"
curl --fail --location --proto '=https' --tlsv1.2 --retry 5 --output "$temporary" "$url"
echo "$expected  $temporary" | sha256sum -c -
mv "$temporary" "$target"
chmod 0644 "$target"
echo "Installed verified SCIM connector $version"
