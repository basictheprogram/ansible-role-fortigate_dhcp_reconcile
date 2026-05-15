# realtime.fortigate_dhcp_reconcile

Reconciles DHCP reservations on a FortiGate appliance against printer device records in NetBox. Classifies every device by its reconciliation state, renders a dark-mode HTML report, and optionally patches NetBox IP addresses to match the FortiGate.

---

## How it works

1. **Preflight** — validates all required variables before any API call.
2. **Fetch FortiGate** — reads DHCP reserved addresses from the FortiGate CMDB endpoint (`/api/v2/cmdb/system.dhcp/server/<id>`). Reserved addresses are the source of truth; unreserved devices are considered misconfigured and out of scope.
3. **Fetch NetBox** — queries NetBox for all devices matching the configured site and device-role, then fetches each device's interfaces to get MAC addresses.
4. **Compare** — classifies every MAC into one of five states (see below).
5. **Report** — renders an HTML reconciliation report to disk.
6. **Fix NetBox** *(opt-in)* — patches NetBox primary IPs to match the FortiGate. Only runs with `--tags fix_netbox`.

> **FortiOS 7.4 note:** The monitor endpoint `/api/v2/monitor/dhcp/leases` is absent on FortiOS 7.4.x. This role uses the CMDB endpoint instead, which is available on all FortiOS versions and requires no special monitor permissions.

---

## Requirements

**Ansible collections**

```yaml
# requirements.yml
collections:
  - name: ansible.utils
  - name: ansible.builtin
```

Install with:

```bash
ansible-galaxy collection install -r requirements.yml
```

**Python library** (on the Ansible controller)

```bash
pip install netaddr
```

**FortiGate REST API admin**

Create a REST API admin in FortiOS under **System → Administrators**. The `super_admin_readonly` built-in profile is sufficient for read-only reconciliation. To also use `--tags fix_netbox`, the profile needs write access to `ipam/ip-addresses` and `dcim/devices` in NetBox (not FortiGate).

**NetBox API token**

Any token with read access to `dcim/devices`, `dcim/interfaces`, and `ipam/ip-addresses`. Write access to those same endpoints is needed for `--tags fix_netbox`.

---

## Role variables

All variables have defaults in `defaults/main.yml`. Override in `group_vars`, `host_vars`, or inventory.

### FortiGate connection

| Variable | Default | Description |
|---|---|---|
| `fortigate_host` | `192.168.1.1` | FortiGate IP or hostname |
| `fortigate_port` | `443` | HTTPS port |
| `fortigate_validate_certs` | `true` | Set `false` for self-signed certs |
| `fortigate_api_token` | `{{ vault_fortigate_api_token }}` | REST API bearer token (store in vault) |
| `fortigate_vdom` | `root` | VDOM name. Single-VDOM appliances use `root` |
| `fortigate_dhcp_server_id` | `1` | DHCP server ID to read reservations from |

**Finding the DHCP server ID** — run on the FortiGate CLI:

```
config system dhcp server
    show
end
```

Each `edit <id>` block shows a server ID. Or query the API directly:

```bash
cp .env.example .env   # fill in FG_HOST, FG_TOKEN, FG_DHCP_SERVER_ID
bash scripts/fortigate_dhcp_server.sh
```

### NetBox connection

| Variable | Default | Description |
|---|---|---|
| `netbox_url` | `http://netbox.example.local` | NetBox base URL |
| `netbox_token` | `{{ vault_netbox_token }}` | API token (store in vault) |
| `netbox_validate_certs` | `false` | Set `true` for valid TLS |
| `netbox_site_slug` | `main` | Site slug to filter devices |
| `netbox_device_role_slug` | `printer` | Device role slug to filter devices |

### Subnet and report

| Variable | Default | Description |
|---|---|---|
| `printer_subnet` | `10.0.10.0/24` | CIDR range. Reservations outside this range are ignored |
| `reconcile_report_path` | `reports/reconciliation_<date>.html` | Report output path, relative to the playbook directory |

---

## Vault setup

Store secrets in an encrypted vault file:

```yaml
# group_vars/all/vault.yml
vault_fortigate_api_token: "your-fortigate-token"
vault_netbox_token: "your-netbox-token"
```

Reference them in your vars:

```yaml
# group_vars/all/main.yml
fortigate_api_token: "{{ vault_fortigate_api_token }}"
netbox_token: "{{ vault_netbox_token }}"
```

Encrypt the vault:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

---

## Reconciliation states

| State | Meaning |
|---|---|
| ✅ `ok` | MAC in both FortiGate and NetBox, IPs match |
| ⚠️ `ip_drift` | MAC in both, but IPs differ — NetBox is stale |
| 🔌 `nb_only` | MAC in NetBox, not in FortiGate reservations — device may be offline or removed |
| ❓ `fg_only` | MAC in FortiGate reservations, not in NetBox — unknown device |
| 🔧 `nb_incomplete` | Device exists in NetBox but has no interface / no MAC — data quality issue |

---

## Example playbook

```yaml
---
- name: Reconcile printer DHCP reservations with NetBox
  hosts: fortigate
  gather_facts: false
  roles:
    - role: realtime.fortigate_dhcp_reconcile
```

Run a standard reconciliation (report only, no changes):

```bash
ansible-playbook reconcile.yml --ask-vault-pass
```

Run and patch NetBox IPs for drifted devices:

```bash
ansible-playbook reconcile.yml --ask-vault-pass --tags fix_netbox
```

---

## Example inventory / host_vars

```yaml
# host_vars/<fortigate-hostname>/main.yml
fortigate_host: "192.168.1.254"
fortigate_port: 443
fortigate_validate_certs: false
fortigate_api_token: "{{ vault_fortigate_api_token }}"
fortigate_vdom: "root"
fortigate_dhcp_server_id: 3

netbox_url: "https://netbox.example.com"
netbox_token: "{{ vault_netbox_token }}"
netbox_validate_certs: false
netbox_site_slug: "main-office"
netbox_device_role_slug: "printer"

printer_subnet: "192.168.0.0/23"
```

---

## Debug scripts

Two helper scripts live in `scripts/` for manual API verification. Both load credentials from a `.env` file:

```bash
cp .env.example .env   # fill in your values — this file is gitignored
```

| Script | Purpose |
|---|---|
| `scripts/fortigate_dhcp_server.sh` | Fetch FortiGate DHCP server config — confirm server ID and inspect reserved addresses |
| `scripts/netbox_slugs.sh` | List valid NetBox site slugs and device-role slugs |

```bash
bash scripts/fortigate_dhcp_server.sh
bash scripts/netbox_slugs.sh
```

---

## License

MIT
