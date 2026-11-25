# dockarr

Docker Compose setup for a single-machine homelab: a media stack, home automation and a set of self-hosted apps.

Each service is its own Compose stack under `services/<name>/`. Most of them run behind a
[Tailscale](https://tailscale.com) sidecar container, so each one gets its own HTTPS hostname
on the tailnet (`https://<service>.<tailnet>.ts.net`) without exposing ports on the LAN.
[Task](https://taskfile.dev) wraps the common commands.

## Services

| Area | Services |
|---|---|
| Media | Jellyfin, Seerr (`jellyseerr`), Transmission, Sonarr, Radarr, Prowlarr, Bazarr, Jackett, FlareSolverr (`servarr`) |
| Network | Pi-hole (tailnet DNS), joal (behind gluetun) |
| Home | Home Assistant, Mealie, Vikunja, Homepage |
| Tools | Stirling-PDF, FileGator, Wiki.js, n8n, CloudBeaver, Portainer, Vaultwarden |
| Dev | Gitea, Gitea Actions runner |
| AI | Qdrant, text-embeddings-inference (`embeddings`) |

These stacks have no Tailscale sidecar and publish their ports on the host: `servarr`,
`transmission`, `file-gator`, `cloudbeaver` and `joal`.

## Layout

```
services/<name>/docker-compose.yml   one stack per service
services/<name>/config/serve.json    Tailscale serve config for the sidecar
config/                              Homepage and Home Assistant config templates
install/                             host bootstrap (Docker, Tailscale, joal)
migrate/                             upgrade scripts for breaking version bumps
Taskfile.yml                         task runner entry point
```

## Setup

1. Copy the env files and fill them in:
   ```sh
   cp .env.example .env
   cp .homepage.env.example .homepage.env
   ```
   The main variables in `.env`:
   - `CONFIG`: app data root; each service stores its data in `$CONFIG/<service>`.
   - `DATA`: media library root (`movies/`, `tv/`, `movies-anime/`, `tv-anime/`).
   - `DOWNLOADS`: Transmission download directory.
   - `TS_AUTHKEY` and `TS_DOMAIN`: Tailscale auth key and tailnet domain.
   - `.homepage.env` holds the URLs and API keys for the Homepage widgets.
2. On a fresh host, install Docker and Tailscale, then create the `dockarr` network:
   ```sh
   task install
   ```
3. Generate the Homepage and Home Assistant config into `$CONFIG`:
   ```sh
   task setup-config
   ```
4. Start the stacks. Start Pi-hole first, because the other Tailscale sidecars use it as their DNS:
   ```sh
   task pihole-up
   task start            # every service listed in STACK_SERVICES
   ```

## Usage

```sh
task                  # list tasks
task <service>-up     # create or update one stack (e.g. task jellyfin-up)
task <service>-down   # stop and remove one stack
task start            # bring up every stack
task teardown         # stop and remove every container on the host
```

To upgrade a service, change the image tag in its compose file, then run `task <service>-up`.
Image tags are always pinned to exact versions.

## Breaking upgrades

`migrate/` has a script for each service whose upgrade can't simply be rolled back
(Jellyfin, n8n, Home Assistant, Stirling-PDF, CloudBeaver).
Each script:

1. Runs preflight checks (current version, plugins, deprecated config, disk space).
2. Stops the service and backs up its data directory.
3. Bumps the image tag in the compose file and restarts the service.
4. Waits for it to become healthy and prints rollback instructions.

```sh
task migrate-jellyfin -- --check                       # preflight only, changes nothing
BACKUP_DIR=~/backups/migrations task migrate-jellyfin  # run it
```

Backups go to `$BACKUP_DIR`, which defaults to `$CONFIG/backups/migrations`.
Point it at a different disk when `$CONFIG` is short on space.

## Notes

- The Pi-hole stack waits for its Tailscale sidecar to *start*, not to be *healthy*. Tailscale
  reports unhealthy while its DNS server (Pi-hole itself) is unreachable, so waiting for healthy
  would deadlock.
- Every file in the repo uses LF line endings (enforced by `.gitattributes`). The git-ignored
  `.env` files may still have CRLF line endings on an existing host. Docker Compose and Task handle that,
  but scripts that source them must strip the `\r` (see `migrate/lib.sh`).
- `.env` and `.homepage.env` contain secrets and are git-ignored.
