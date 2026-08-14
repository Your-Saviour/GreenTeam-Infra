#!/bin/sh
set -eu

required='MIDPOINT_URL MIDPOINT_ADMIN_PASSWORD MIDPOINT_PUBLIC_URL MIDPOINT_AUTHENTIK_ISSUER MIDPOINT_AUTHENTIK_SCIM_URL MIDPOINT_OIDC_CLIENT_ID MIDPOINT_OIDC_CLIENT_SECRET MIDPOINT_SCIM_TOKEN'
for variable in $required; do
  eval "value=\${$variable:-}"
  [ -n "$value" ] || { echo "$variable is required" >&2; exit 1; }
done

case "$MIDPOINT_AUTHENTIK_ISSUER $MIDPOINT_AUTHENTIK_SCIM_URL" in
  *https://*https://*) ;;
  *) echo "Authentik issuer and SCIM endpoint must both use HTTPS" >&2; exit 1 ;;
esac

echo "Validating Authentik OIDC discovery"
curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
  "${MIDPOINT_AUTHENTIK_ISSUER}.well-known/openid-configuration" >/dev/null

echo "Validating Authentik SCIM discovery and bearer token"
curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
  -H "Authorization: Bearer $MIDPOINT_SCIM_TOKEN" \
  "${MIDPOINT_AUTHENTIK_SCIM_URL}/ServiceProviderConfig" >/dev/null

escape_xml() { printf '%s' "$1" | sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g;s/"/\&quot;/g;s/'"'"'/\&apos;/g'; }
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM

for source in /objects/*.xml; do
  output="$work/$(basename "$source")"
  sed \
    -e "s|@@SCIM_URL@@|$(escape_xml "$MIDPOINT_AUTHENTIK_SCIM_URL")|g" \
    -e "s|@@SCIM_TOKEN@@|$(escape_xml "$MIDPOINT_SCIM_TOKEN")|g" \
    -e "s|@@OIDC_ISSUER@@|$(escape_xml "$MIDPOINT_AUTHENTIK_ISSUER")|g" \
    -e "s|@@OIDC_CLIENT_ID@@|$(escape_xml "$MIDPOINT_OIDC_CLIENT_ID")|g" \
    -e "s|@@OIDC_CLIENT_SECRET@@|$(escape_xml "$MIDPOINT_OIDC_CLIENT_SECRET")|g" \
    -e "s|@@PUBLIC_URL@@|$(escape_xml "$MIDPOINT_PUBLIC_URL")|g" \
    "$source" >"$output"

  type=$(sed -n 's/^[[:space:]]*<\([A-Za-z][A-Za-z]*\)\([[:space:]>].*\)$/\1/p' "$output" | head -n1)
  oid=$(sed -n 's/.*oid="\([^"]*\)".*/\1/p' "$output" | head -n1)
  [ -n "$type" ] && [ -n "$oid" ] || { echo "Cannot identify object in $source" >&2; exit 1; }
  case "$type" in
    resource) endpoint=resources ;;
    role) endpoint=roles ;;
    task) endpoint=tasks ;;
    securityPolicy) endpoint=securityPolicies ;;
    objectTemplate) endpoint=objectTemplates ;;
    *) echo "Unsupported object type $type in $source" >&2; exit 1 ;;
  esac
  echo "Importing $(basename "$source") ($oid)"
  curl --fail --silent --show-error --user "administrator:$MIDPOINT_ADMIN_PASSWORD" \
    -H 'Content-Type: application/xml' -X PUT --data-binary "@$output" \
    "$MIDPOINT_URL/ws/rest/$endpoint/$oid" >/dev/null
done

# Select the imported policy globally without replacing the built-in SystemConfiguration.
cat >"$work/security-policy-delta.xml" <<'EOF'
<objectModification xmlns="http://midpoint.evolveum.com/xml/ns/public/common/api-types-3"
                    xmlns:c="http://midpoint.evolveum.com/xml/ns/public/common/common-3"
                    xmlns:t="http://prism.evolveum.com/xml/ns/public/types-3">
  <itemDelta><t:modificationType>replace</t:modificationType><t:path>globalSecurityPolicyRef</t:path>
    <t:value oid="8dfe9f58-24e7-4cb2-8421-050000000001" type="c:SecurityPolicyType"/>
  </itemDelta>
</objectModification>
EOF
curl --fail --silent --show-error --user "administrator:$MIDPOINT_ADMIN_PASSWORD" \
  -H 'Content-Type: application/xml' -X PATCH --data-binary "@$work/security-policy-delta.xml" \
  "$MIDPOINT_URL/ws/rest/systemConfigurations/00000000-0000-0000-0000-000000000001" >/dev/null

echo "Bootstrap completed; rendered files and plaintext secrets removed"
