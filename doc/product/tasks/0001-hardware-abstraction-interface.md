---
id: TASK-0001
status: todo
feature_id: FEAT-0001
title: Define provisioner script contract
---

# Define Provisioner Script Contract

## Goal

Establish the convention that all hardware-class provisioner scripts must follow. This is a documented contract, not code — no implementation here.

## Scope

- Define the **function signatures** every provisioner script must implement:
  - `provision` — install ZFS, create the `tank` pool and datasets, install Docker, deploy the compose stack.
  - `verify` — confirm the ZFS pool is healthy and all expected containers are running; exits non-zero on failure.
- Define the **error reporting convention**: on failure, a provisioner sets these variables before exiting non-zero:
  - `GRINGOTTS_ERROR_CODE` — machine-readable code (e.g. `ZFS_POOL_FAILED`, `DOCKER_UNAVAILABLE`, `COMPOSE_DEPLOY_FAILED`).
  - `GRINGOTTS_ERROR_MSG` — plain-language sentence for the user.
  - `GRINGOTTS_REMEDIATION` — single next action.
- Define the **provision sub-step convention**: `provision` is divided into named sub-steps. On entry, each sub-step checks `PROVISION_STEP` from the session file and skips itself if already completed. On completion, it calls `session_set_provision_step <name>`. Sub-steps must be idempotent — re-running a completed sub-step must be safe. The ordered sub-steps for `debian_linux` are: `zfs_installed`, `zfs_pool_created`, `zfs_datasets_created`, `docker_installed`, `repo_cloned`, `tailscale_configured`, `compose_deployed`.
- Define the **hardware class identifiers**: `debian_linux` (the only active class in this iteration; `synology`, `qnap`, `raspberry_pi` are reserved for future use).
- Define the **exit code convention**: `0` = success, `1` = recoverable failure (error vars set), `2` = unrecoverable failure.
- Document where provisioner scripts live: `provisioners/<hardware_class>.sh`.

## Acceptance Criteria

- A `provisioners/CONTRACT.md` file exists describing all of the above.
- TASK-0008 explicitly references this contract.
- No executable code in this task.

## Dependencies

None — this is the foundation task.

## Notes

This contract is also reused by FEAT-0002 (replica configuration) and FEAT-0003 (recovery flow).
