---
id: TASK-0008
status: todo
feature_id: FEAT-0001
title: Implement provisioner for Debian-family Linux
---

# Implement Provisioner — Debian-Family Linux

## Goal

Implement `provisioners/debian_linux.sh` so that it satisfies the contract from TASK-0001. This provisioner installs ZFS, creates the `tank` storage pool and dataset layout, installs Docker, and deploys the gringotts compose stack.

The user is expected to have obtained `wizard.sh` via the download-verify-run pattern (ADR-0001 Decision 5) before reaching this provisioner.

## Scope

- **Pre-execution disclosure gate** (runs before `provision`):
  - Print a plain-language summary of every action `provision` will take:
    - Packages installed via `apt`: `git`, `make`, `zfsutils-linux`, `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-compose-plugin`, `tailscale`
    - A ZFS pool named `tank` will be created on a user-selected drive (destructive)
    - ZFS datasets to be created under `tank/`
    - The gringotts repo will be cloned to `~/gringotts/`
    - Tailscale will be installed and joined to the user's tailnet
    - Docker Compose services to be started: `traefik`, `prowlarr`, `sonarr`, `radarr`, `jellyfin`, `immich` (always); `gluetun` + `qbittorrent` optionally if the user opts in to VPN-routed torrenting
  - Print the URL to the wizard source and the expected SHA-256 digest.
  - State the prerequisites the user must complete before continuing: DNS for their domain must point at the Tailscale address of this machine.
  - Prompt `Type "yes" to continue:`. If the user does not type `yes`, exit `0` with no side effects.
  - This gate is not skippable via flag or environment variable.

- `provision` (sub-steps — each checks `PROVISION_STEP` and skips if already completed; each is idempotent):
  1. **`zfs_installed`**: `apt install -y git make zfsutils-linux`. Skip if all three are already installed.
  2. **`zfs_pool_created`**: Locate the data partition via `blkid -L gringotts` (created by the Debian preseed per ADR-0002). Print the device path and size; warn that creating the pool is destructive and provides no redundancy (single-drive); require explicit `yes`. Run `zpool create tank <device>`. Skip if `zpool list tank` succeeds.
  3. **`zfs_datasets_created`**: Create `tank/media`, `tank/media/movies`, `tank/media/tv`, `tank/media/music`, `tank/media/downloads`, `tank/photos`, `tank/photos/immich`, `tank/apps`. Each dataset creation is individually idempotent (`zfs list <dataset> 2>/dev/null || zfs create <dataset>`).
  4. **`docker_installed`**: Add Docker's official apt repository; install `docker-ce docker-ce-cli containerd.io docker-compose-plugin`. Skip if `docker version` succeeds.
  5. **`repo_cloned`**: Install `git` if absent; clone the gringotts repo at the matching release tag to `~/gringotts/`. Skip if `~/gringotts/.git` exists. Verify the cloned tag matches the wizard version before proceeding.
  6. **`tailscale_configured`**: `apt install -y tailscale`. Collect Tailscale auth key interactively (not echoed). Run `tailscale up --authkey=$TS_AUTHKEY`. Skip if `tailscale status` shows `Running`.
  7. **`compose_deployed`**: Collect domain name interactively. Prompt "Enable VPN-routed torrenting? [y/N]". If yes: collect VPN provider name and the corresponding credentials (WireGuard private key + address, or username/password — depends on provider); write to `docker/gluetun/.env`; deploy all services including `gluetun` and `qbittorrent`. If no: deploy without `gluetun` and `qbittorrent` (Sonarr/Radarr will have no download client configured until the user adds one manually). All secrets written to per-service `.env` files under `~/gringotts/docker/`; never echoed, logged, or written to the session state file.
  - Each sub-step calls `session_set_provision_step <name>` and `emit <event>` on completion — events are emitted as sub-steps complete, not batched at the end.
  - Sets `GRINGOTTS_ERROR_*` and exits `1` on any recoverable failure.

- `verify`:
  - `zpool status tank` shows `ONLINE`.
  - `docker ps --format '{{.Names}}'` lists all expected containers in `Up` state.
  - `/dev/dri/renderD128` exists (required by Jellyfin and Immich for iGPU acceleration); surface a warning if absent but do not fail — the stack runs without hardware acceleration.
  - Exits `0` on success, `1` on failure.

## Acceptance Criteria

- bats tests cover: happy path end-to-end (all sub-steps mocked), disclosure declined (no side effects), resume from each sub-step checkpoint (skips already-completed steps), ZFS pool already exists (idempotent skip), Docker already installed (idempotent skip), Tailscale already running (idempotent skip), compose deploy failure.
- The full list of packages, datasets, containers, and prerequisites is written into the disclosure text as part of this task's diff.
- `provision` is never called if the user does not type `yes`.
- Secrets (Tailscale auth key, Mullvad keys, domain) are written to `.env` files only; never written to the session state file or the instrumentation log.
- A resume test must confirm that if `PROVISION_STEP=docker_installed`, sub-steps 1–4 are skipped and execution resumes at `repo_cloned`.

## Dependencies

- TASK-0001 (contract)
- TASK-0003 (detection must identify `debian_linux`)

## Notes

ADR-0001 Decision 5 defines the delivery pattern that precedes this provisioner running. The disclosure gate here is the second trust checkpoint — the first is the `sha256sum` verification the user performed before running `wizard.sh`.
