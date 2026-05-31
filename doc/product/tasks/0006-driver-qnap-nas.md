---
id: TASK-0006
status: todo
feature_id: FEAT-0001
title: Implement provisioner for QNAP NAS
---

> **Dropped.** NAS support is out of scope for the first iteration. See TASK-0005 for rationale.

# Implement Provisioner — QNAP NAS

## Goal

Implement `provisioners/qnap.sh` so that it satisfies the contract from TASK-0001. The wizard runs on the QNAP QTS shell (SSH).

## Scope

- `provision`:
  - Creates or validates a shared folder via `qpkg` CLI or QTS shell utilities.
  - Installs or verifies the provisioning daemon.
  - Sets `GRINGOTTS_ERROR_*` and exits `1` on recoverable failure.
- `verify`:
  - Confirms daemon is running and the shared folder is writable.
  - Exits `0` on success, `1` on recoverable failure.

## Acceptance Criteria

- bats integration tests (QTS CLI calls mocked via PATH-stubbing) cover: happy path, storage-init failure, daemon failure.
- All errors escape as `GRINGOTTS_ERROR_*` variables; no raw QTS output reaches the user.

## Dependencies

- TASK-0001 (contract)
- TASK-0003 (detection must identify `qnap`)
