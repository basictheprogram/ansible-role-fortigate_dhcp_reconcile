#!/usr/bin/env bash
# scripts/fortigate_dhcp_server.sh
#
# Fetches FortiGate DHCP server configuration from the CMDB API.
# Use this to confirm your fortigate_dhcp_server_id and inspect
# the reserved-address list the role will read.
#
# Usage:
#   cp .env.example .env      # fill in your values
#   bash scripts/fortigate_dhcp_server.sh

set -euo pipefail

echo "==> Load environment variables from .env file"
if [ -f ".env" ]; then
    set -o allexport
    source ./.env
    set +o allexport
fi

: "${FG_HOST:?FG_HOST is not set. Copy .env.example to .env and fill it in.}"
: "${FG_TOKEN:?FG_TOKEN is not set. Copy .env.example to .env and fill it in.}"
: "${FG_DHCP_SERVER_ID:=1}"
: "${FG_VDOM:=root}"

echo "==> Querying FortiGate DHCP server ${FG_DHCP_SERVER_ID} on ${FG_HOST}"
curl -sk \
    -H "Authorization: Bearer ${FG_TOKEN}" \
    "${FG_HOST}/api/v2/cmdb/system.dhcp/server/${FG_DHCP_SERVER_ID}?vdom=${FG_VDOM}" \
    | python3 -m json.tool
