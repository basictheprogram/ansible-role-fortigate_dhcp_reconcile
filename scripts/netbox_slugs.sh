#!/usr/bin/env bash
# scripts/netbox_slugs.sh
#
# Lists valid site slugs and device-role slugs from NetBox.
# Use this to find the correct values for netbox_site_slug
# and netbox_device_role_slug in your host_vars.
#
# Usage:
#   cp .env.example .env      # fill in your values
#   bash scripts/netbox_slugs.sh

set -euo pipefail

echo "==> Load environment variables from .env file"
if [ -f ".env" ]; then
    set -o allexport
    source ./.env
    set +o allexport
fi

: "${NB_URL:?NB_URL is not set. Copy .env.example to .env and fill it in.}"
: "${NB_TOKEN:?NB_TOKEN is not set. Copy .env.example to .env and fill it in.}"

echo ""
echo "==> Sites (use the slug value for netbox_site_slug)"
curl -sk \
    -H "Authorization: Token ${NB_TOKEN}" \
    "${NB_URL}/api/dcim/sites/?limit=50" \
    | python3 -m json.tool | grep '"slug"'

echo ""
echo "==> Device roles (use the slug value for netbox_device_role_slug)"
curl -sk \
    -H "Authorization: Token ${NB_TOKEN}" \
    "${NB_URL}/api/dcim/device-roles/?limit=50" \
    | python3 -m json.tool | grep '"slug"'
