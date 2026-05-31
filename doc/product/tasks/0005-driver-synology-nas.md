---
id: TASK-0005
status: todo
feature_id: FEAT-0001
title: Implement provisioner for Synology NAS
---

> **Dropped.** NAS support (Synology, QNAP) is out of scope for the first iteration. Focus is on Debian-family Linux on x86 hardware (Beelink ME Mini). Synology DSM also does not support ZFS natively, making the storage layer incompatible without significant additional work.

# Implement Provisioner — Synology NAS

## Goal

Implement `provisioners/synology.sh` so that it satisfies the contract from TASK-0001. The wizard runs directly on the Synology DSM shell (SSH). No graphical DSM interaction is required.

## Scope

- `provision`:
  - Creates (or validates) a shared folder on the default storage pool via `synoshare` CLI or DSM API.
  - Installs or verifies the provisioning daemon via `synopkg` CLI.
  - Sets `GRINGOTTS_ERROR_CODE` / `GRINGOTTS_ERROR_MSG` / `GRINGOTTS_REMEDIATION` and exits `1` on recoverable failure.
- `verify`:
  - Confirms the daemon process is running and the shared folder is writable.
  - Exits `0` on success, `1` on recoverable failure.
- Advanced storage options (custom volume, custom path) are supported via environment variables but not required by the default flow.

## Acceptance Criteria

- bats integration tests (with DSM CLI calls mocked via PATH-stubbing) cover: happy path end-to-end, drive-not-formatted error, daemon install failure.
- No call to `sudo` or `root`-only tools — Synology DSM shell runs as admin.
- All errors escape as `GRINGOTTS_ERROR_*` variables; no raw `synopkg` or DSM error text is passed to the user directly.

## Dependencies

- TASK-0001 (contract)
- TASK-0003 (detection must identify `synology` before this script is sourced)
