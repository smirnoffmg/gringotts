---
id: TASK-0007
status: todo
feature_id: FEAT-0001
title: Implement provisioner for Raspberry Pi
---

# Implement Provisioner — Raspberry Pi (SBC)

## Goal

Implement `provisioners/raspberry_pi.sh` so that it satisfies the contract from TASK-0001. The wizard runs directly on the Pi (user has SSHed in or is at a local terminal).

## Scope

- `provision`:
  - Detects attached external storage (USB drive or dedicated partition); if absent, sets `GRINGOTTS_ERROR_CODE=DRIVE_NOT_ATTACHED`, `GRINGOTTS_REMEDIATION="Attach a USB drive and rerun"`, exits `1`.
  - Mounts and validates the data directory (`/mnt/gringotts` by default).
  - Installs the provisioning daemon binary and writes the systemd unit file; enables and starts the service.
  - Sets `GRINGOTTS_ERROR_*` and exits `1` on any recoverable failure.
- `verify`:
  - Confirms `systemctl is-active gringotts` and that the data directory is writable.
  - Exits `0` on success, `1` on failure.

## Acceptance Criteria

- bats integration tests (systemd and mount calls mocked) cover: happy path, no external storage, daemon start failure.
- No dependency on a desktop environment or graphical tooling — pure shell.
- All errors escape as `GRINGOTTS_ERROR_*`; no raw `systemctl` output reaches the user directly.

## Dependencies

- TASK-0001 (contract)
- TASK-0003 (detection must identify `raspberry_pi`)
