---
id: TASK-0013
status: todo
feature_id: FEAT-0001
title: Implement first-file write and checksum verification
---

# Implement First-File Write and Checksum Verification

## Goal

Implement `lib/checksum_write.sh`: write a probe file to `/tank`, verify byte-level integrity with `sha256sum`, and declare provisioning complete only on confirmed integrity. All tests from TASK-0012 must pass.

## Scope

- Write a known-content probe file to `/tank/.gringotts_probe`.
- Compute `sha256sum` of the written file and compare against the expected hash.
- On match: call `emit first_file_written checksum_verified=1`, call `session_complete`, print the completion summary (ZFS pool name, dataset list, running containers, verified hash).
- On mismatch: set `GRINGOTTS_ERROR_CODE=CHECKSUM_MISMATCH`, call `show_recovery`, call `emit step_failed step=first_file_write error_code=CHECKSUM_MISMATCH`; do not print the completion message; allow retry.
- Remove the probe file after successful verification.

## Acceptance Criteria

- All tests from TASK-0012 pass (green).
- The completion message is never printed if the hash comparison fails.
- Exactly one `first_file_written` log line is emitted on success (idempotent on retry).

## Dependencies

- TASK-0012 (tests must exist first)
- TASK-0009 (recovery messaging)
- TASK-0010 (session_complete)
- TASK-0011 (emit)
