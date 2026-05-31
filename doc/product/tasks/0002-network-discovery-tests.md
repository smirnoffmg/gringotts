---
id: TASK-0002
status: todo
feature_id: FEAT-0001
title: Write failing bats tests for hardware self-detection
---

# Write Failing bats Tests for Hardware Self-Detection

## Goal

Author the bats test suite for the hardware self-detection script before the script exists. For the first iteration the only active class is `debian_linux` (Beelink ME Mini running Debian 13).

## Scope

Write bats tests covering:

- **Debian** — stub `/etc/os-release` with `ID=debian`; assert `detect_hardware` outputs `debian_linux`.
- **Debian-family via ID_LIKE** — stub `/etc/os-release` with `ID=ubuntu` and `ID_LIKE=debian`; assert output is `debian_linux`.
- **Unknown hardware** — no recognised markers; assert exit code `2` and a non-empty `GRINGOTTS_ERROR_MSG`.

All tests must fail (red) before TASK-0003 begins.

## Acceptance Criteria

- Test file exists at `tests/detect_hardware.bats` and runs with `bats`.
- Every test fails with a clear "not implemented" signal, not a missing-file error.
- Tests use only stubbed filesystem paths — no real device required.

## Dependencies

- TASK-0001 (exit code and error variable conventions)
