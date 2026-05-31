---
id: TASK-0012
status: todo
feature_id: FEAT-0001
title: Write failing bats tests for first-file write and checksum verification
---

# Write Failing bats Tests for First-File Write and Checksum Verification

## Goal

Author tests for the first-file write step before implementation exists (TASK-0013). This step writes a probe file to the ZFS pool (`/tank`) and verifies byte-level integrity via `sha256sum` — confirming ZFS is writable end-to-end before the wizard declares provisioning complete.

## Scope

Write bats tests covering:

- **Happy path** — probe file written to `/tank`; `sha256sum` of written file matches expected hash; wizard advances to complete.
- **Checksum mismatch** — written file hash differs from expected; `step_failed` is logged with `error_code=CHECKSUM_MISMATCH`; wizard does not declare complete.
- **Write failure** — write command exits non-zero (e.g. pool not mounted); recovery messaging shown; provisioning not declared complete.
- **Retry after failure** — after a failed write, the user retries and succeeds; wizard advances to complete.

All tests must fail (red) before TASK-0013 begins.

## Acceptance Criteria

- Test file exists at `tests/checksum.bats` and runs with `bats`.
- Tests assert that the "provisioning complete" message is never printed unless the hash comparison succeeds.
- Tests use a temp directory — no writes to the real `/tank` or `~/.gringotts`.

## Dependencies

- TASK-0001 (error code convention)
- TASK-0009 (recovery layer must exist to be called in tests)
- TASK-0011 (log emitter must exist to assert event emission)
