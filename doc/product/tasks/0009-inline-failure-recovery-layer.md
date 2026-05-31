---
id: TASK-0009
status: todo
feature_id: FEAT-0001
title: Implement inline failure/recovery messaging
---

# Implement Inline Failure / Recovery Messaging

## Goal

Implement `lib/recovery.sh` — a sourceable script that maps every `GRINGOTTS_ERROR_CODE` to a formatted plain-language message and a single remediation action, printed to the terminal inline without interrupting the wizard flow.

## Scope

- Source `lib/recovery.sh`; call `show_recovery` after any provisioner exits non-zero.
- `show_recovery` reads `GRINGOTTS_ERROR_CODE`, `GRINGOTTS_ERROR_MSG`, and `GRINGOTTS_REMEDIATION` and prints:
  - A headline in plain language (no raw error codes shown by default).
  - The single remediation action.
  - An optional "Show technical details" prompt that reveals the raw `GRINGOTTS_ERROR_CODE` on request.
- Defined error codes to handle at minimum:
  - `ZFS_INSTALL_FAILED` — apt could not install `zfsutils-linux`
  - `ZFS_POOL_FAILED` — `zpool create` failed (wrong device, existing data, etc.)
  - `ZFS_DATASET_FAILED` — dataset creation failed
  - `DOCKER_INSTALL_FAILED` — Docker apt install failed
  - `DOCKER_UNAVAILABLE` — Docker daemon not running after install
  - `REPO_CLONE_FAILED` — `git clone` failed (no network, auth error, tag not found)
  - `REPO_TAG_MISMATCH` — cloned tag does not match wizard version
  - `TAILSCALE_INSTALL_FAILED` — apt could not install `tailscale`
  - `TAILSCALE_AUTH_FAILED` — `tailscale up` rejected the auth key
  - `COMPOSE_DEPLOY_FAILED` — one or more containers failed to start
  - `UNSUPPORTED_HARDWARE` — hardware detection found no recognised markers
  - `CHECKSUM_MISMATCH` — probe file write verification failed
- Fallback for unrecognised codes: honest generic message + "Contact support" — never a blank screen.
- `show_recovery` must not exit the wizard; control returns to the caller after printing.

## Acceptance Criteria

- bats unit tests: every defined error code produces a non-empty message and non-empty remediation line.
- bats unit test: an unknown error code produces the fallback message without error.
- No raw error code or shell stack trace is visible in the default output path.
- `lib/recovery.sh` has no dependency on provisioner scripts — it operates solely on the three `GRINGOTTS_ERROR_*` variables.

## Dependencies

- TASK-0001 (`GRINGOTTS_ERROR_*` variable convention)
