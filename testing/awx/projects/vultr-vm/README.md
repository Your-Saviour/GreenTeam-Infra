# Vultr VM — AWX Project

Creates and destroys Vultr VMs via AWX job templates. Adapted from the cloudlab `start-instances.yaml` playbook.

## Playbooks

| Playbook | Purpose |
|----------|---------|
| `create.yml` | Provision a Vultr VM with SSH key and optional DNS |
| `destroy.yml` | Tear down a VM, its DNS record, and SSH key |

## AWX Setup

### 1. Custom Credential Types

Create two custom credential types in AWX (Administration > Credential Types).

**Vultr API:**

Input Configuration:
```yaml
fields:
  - id: vultr_api_key
    type: string
    label: Vultr API Key
    secret: true
required:
  - vultr_api_key
```

Injector Configuration:
```yaml
env:
  VULTR_API_KEY: "{{ vultr_api_key }}"
```

**Cloudflare API:**

Input Configuration:
```yaml
fields:
  - id: cloudflare_api_key
    type: string
    label: Cloudflare API Token
    secret: true
required:
  - cloudflare_api_key
```

Injector Configuration:
```yaml
env:
  CLOUDFLARE_API_KEY: "{{ cloudflare_api_key }}"
```

### 2. Credentials

Create credentials using the types above (Resources > Credentials) and enter your API keys.

### 3. Project

Create a manual project (Resources > Projects):
- **Name:** Vultr VM
- **Source Control Type:** Manual
- **Playbook Directory:** vultr-vm

### 4. Job Templates

**Vultr VM — Create:**
- **Project:** Vultr VM
- **Playbook:** create.yml
- **Inventory:** use a localhost inventory (or the project's inventory.yml)
- **Credentials:** Vultr API + Cloudflare API
- **Enable Survey:** Yes (see survey config below)

**Vultr VM — Destroy:**
- **Project:** Vultr VM
- **Playbook:** destroy.yml
- **Inventory:** same localhost inventory
- **Credentials:** Vultr API + Cloudflare API
- **Enable Survey:** Yes (see survey config below)

### 5. Survey Configuration

**Create survey:**

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `vm_label` | Text | `awx-vm` | No | VM label prefix |
| `vm_hostname` | Text | `awx-vm` | No | Hostname prefix |
| `vm_plan` | Multiple Choice | `vc2-1c-1gb` | No | Options: `vc2-1c-1gb`, `vc2-1c-2gb`, `vc2-2c-4gb` |
| `vm_region` | Multiple Choice | `mel` | No | Options: `mel`, `syd` |
| `vm_os` | Multiple Choice | `Ubuntu 24.04 LTS x64` | No | Options: `Ubuntu 24.04 LTS x64`, `Ubuntu 22.04 LTS x64`, `Debian 12 x64` |
| `vm_tags` | Text | `testing,awx` | No | Comma-separated tags |
| `skip_dns` | Multiple Choice | `false` | No | Options: `false`, `true` |
| `domain_name` | Text | `ye-et.com` | No | Cloudflare DNS zone |

**Destroy survey:**

| Variable | Type | Default | Required | Description |
|----------|------|---------|----------|-------------|
| `destroy_label` | Text | — | Yes | Full instance label (e.g. `awx-vm-Ab3x`) |
| `destroy_hostname` | Text | — | No | Hostname for DNS cleanup (e.g. `awx-vm-Ab3x`) |
| `destroy_ssh_key_name` | Text | — | No | SSH key name to remove (e.g. `awx-deploy-Ab3x`) |
| `vm_region` | Multiple Choice | `mel` | Yes | Region where instance lives |
| `skip_dns` | Multiple Choice | `false` | No | Options: `false`, `true` |

## Collection Dependencies

Collections are auto-installed when the AWX stack starts. To manually install:

```bash
docker exec awx-task ansible-galaxy collection install \
  -r /var/lib/awx/projects/vultr-vm/collections/requirements.yml
```

Required collections:
- `vultr.cloud >= 1.13.0`
- `community.general >= 9.0.0`
