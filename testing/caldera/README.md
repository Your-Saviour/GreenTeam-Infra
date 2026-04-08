# Caldera Testing Stack

MITRE's automated adversary emulation platform built on the ATT&CK framework. Simulates real-world threats, tests defences, and automates red team operations through a C2 server with REST API and web interface.

## Architecture

```
                    Internet
                       │
                ┌──────┴──────┐
                │   Traefik   │  caldera.testing.blueteam.au
                │  (testing)  │  Port 443 → 8888
                └──────┬──────┘
                       │
              testing-proxy network
                       │
                ┌──────┴──────┐
                │   Caldera   │  Web UI + REST API
                │  (caldera)  │  + Agent C2 contacts
                └─────────────┘
                  Published ports:
                  7010/tcp  — Sandcat TCP
                  7011/udp  — UDP contact
                  7012/tcp  — Manx WebSocket
                  8022/tcp  — SSH tunnel
                  2222/tcp  — FTP contact
                  8853/tcp  — DNS contact
```

## Containers

| Name | Image | Purpose | Network |
|------|-------|---------|---------|
| `caldera-app` | `ghcr.io/mitre/caldera:latest` | C2 server, web UI, API, agent handler | `testing-proxy` |

## Prerequisites

1. Core testing stack running (`testing-proxy` network must exist)
2. Config file prepared (see Setup below)

## Setup

```bash
# 1. Create config from template
cp config/local.yml.example config/local.yml

# 2. Generate secrets and update config/local.yml
#    Replace each REPLACE_ME value:
openssl rand -base64 32  # → api_key_blue
openssl rand -base64 32  # → api_key_red
openssl rand -base64 32  # → encryption_key
openssl rand -base64 32  # → crypt_salt

# 3. (Optional) Change default user passwords in config/local.yml

# 4. Copy .env.example to .env (optional — only needed to pin image tag)
cp .env.example .env

# 5. Start
docker compose up -d
```

## Access

- **URL:** `https://caldera.testing.blueteam.au`
- **Default credentials:**
  - Red team: `red` / `admin` or `admin` / `admin`
  - Blue team: `blue` / `admin`

## Agent Deployment

Agents connect directly to the host (not through Traefik). When deploying an agent:

1. Go to **Agents > Deploy an agent** in the web UI
2. Select the agent type (Sandcat for most use cases, Manx for reverse shell)
3. Set the server address to the host's IP or hostname (not `localhost`)
4. The agent will connect back on the appropriate port (8888 for HTTP, 7010 for TCP, etc.)

## Useful Commands

```bash
# View logs
docker compose logs -f caldera

# Check agent connections
docker compose exec caldera python3 -c "import requests; print(requests.get('http://localhost:8888/api/v2/agents', headers={'KEY': 'YOUR_API_KEY_RED'}).json())"

# Restart after config change
docker compose restart caldera

# List operations via API
curl -sk -H "KEY: YOUR_API_KEY_RED" https://caldera.testing.blueteam.au/api/v2/operations
```

## File Layout

```
caldera/
├── docker-compose.yml        # Stack definition
├── .env.example              # Compose-level config template
├── README.md                 # This file
└── config/
    ├── local.yml.example     # Caldera config template (copy to local.yml)
    └── local.yml             # Caldera config with secrets (not committed)
```

## Notes

- **Security:** Caldera is a C2 framework — deploy only on isolated test networks. Never expose agent ports to the internet.
- **First start:** Takes 1-2 minutes while plugins load and agents compile. Watch logs with `docker compose logs -f`.
- **No external database:** Caldera uses an embedded database. Data persists in the `caldera_data` volume.
- **Use GHCR image, not Docker Hub.** The `mitre/caldera` Docker Hub image is abandoned (July 2021). Use `ghcr.io/mitre/caldera:latest` which is actively maintained.
- **No curl in container.** The GHCR image doesn't include curl or wget. Healthchecks use Python's `urllib` instead.
- **Config is not merged.** `local.yml` replaces `default.yml` entirely — all keys must be present. Copy `local.yml.example` which includes every required key.
- **Agent callback address:** The `app.contact.http` setting in `config/local.yml` must be reachable by agents. Update it to the host's actual IP when deploying agents on remote machines.
- **No core stack changes:** This stack requires no modifications to Traefik config or the core testing compose file.
