---
id: TASK-0010
status: todo
feature_id: FEAT-0001
title: Implement session persistence
---

# Implement Session Persistence

## Goal

Implement `lib/session.sh` — a sourceable script providing functions for managing the local provisioning state file at `~/.gringotts/provisioning_state`. All tests from TASK-0004 must pass.

## Scope

- `session_create <hardware_class>` — writes a new state file with `checkpoint=0`, `hardware_class=<value>`, `provision_step=`, `updated_at=<epoch>`.
- `session_load` — sources the state file if it exists and is not stale (< 7 days old); sets `CHECKPOINT`, `HARDWARE_CLASS`, and `PROVISION_STEP`. No-ops silently if absent or stale.
- `session_advance` — increments `checkpoint` in the state file and updates `updated_at`; idempotent.
- `session_set_provision_step <name>` — writes `provision_step=<name>` to the state file and updates `updated_at`; called by each provision sub-step on completion.
- `session_complete` — deletes the state file.
- Writes are atomic: write to a `.tmp` file, then `mv` into place to avoid partial-write corruption.
- `~/.gringotts/` directory is created if absent.

## Acceptance Criteria

- All tests from TASK-0004 pass (green).
- Atomic write behaviour is covered by an existing test (from TASK-0004) that confirms prior state survives a simulated mid-write failure.
- `lib/session.sh` has no dependency on provisioner scripts, detection, or wizard flow.

## Dependencies

- TASK-0004 (tests must exist first)
- TASK-0001 (checkpoint vocabulary)
