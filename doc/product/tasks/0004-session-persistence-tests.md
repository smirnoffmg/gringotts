---
id: TASK-0004
status: todo
feature_id: FEAT-0001
title: Write failing bats tests for session persistence
---

# Write Failing bats Tests for Session Persistence

## Goal

Author the bats test suite for the local session persistence functions before they exist. Session state is a `key=value` file at `~/.gringotts/provisioning_state` on the device being provisioned.

## Scope

Write bats tests covering:

- **Create session** — calling `session_create` writes a new state file with `checkpoint=0` and `hardware_class` set.
- **Advance checkpoint** — calling `session_advance` increments the checkpoint index; re-sourcing the file reflects the new value.
- **Resume session** — sourcing an existing state file restores `CHECKPOINT` and `HARDWARE_CLASS` correctly.
- **Idempotent advance** — advancing to the same checkpoint twice does not corrupt the file.
- **Set provision sub-step** — calling `session_set_provision_step zfs_pool_created` persists `provision_step=zfs_pool_created`; re-sourcing the file reflects the new value.
- **Resume provision sub-step** — sourcing an existing state file with `provision_step=docker_installed` restores `PROVISION_STEP=docker_installed`.
- **Stale session ignored** — a state file whose `updated_at` timestamp is older than 7 days is treated as absent by `session_load`.
- **Completion cleanup** — calling `session_complete` removes the state file.

All tests must fail (red) before TASK-0010 begins.

## Acceptance Criteria

- Test file exists at `tests/session.bats` and runs with `bats`.
- Every test fails with a clear "not implemented" signal.
- Tests use a temp directory (`BATS_TMPDIR`) — no writes to the real `~/.gringotts`.

## Dependencies

- TASK-0001 (checkpoint vocabulary — step names must align with provisioner contract)
