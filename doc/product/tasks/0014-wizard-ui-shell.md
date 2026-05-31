---
id: TASK-0014
status: todo
feature_id: FEAT-0001
title: Implement wizard main script
---

# Implement Wizard Main Script

## Goal

Implement `wizard.sh` — the top-level script that sequences provisioning steps, manages session state, and wires together detection, the active provisioner, recovery messaging, and the checkpoint emitter. This script contains no business logic of its own; all logic lives in the sourced libraries and provisioner scripts.

## Scope

- **Startup:** source `lib/session.sh` and call `session_load`. If `CHECKPOINT > 0` or `PROVISION_STEP` is set, resume from the last completed position (print "Resuming from [step / provision sub-step]"); call `emit session_resumed`. Otherwise call `session_create`.
- **Detection:** source and run `detect_hardware.sh`. On unrecognised hardware, call `show_recovery` and exit.
- **Provisioner load:** source `provisioners/$HARDWARE_CLASS.sh`.
- **Disclosure gate:** print the disclosure screen and require the user to type `yes` before calling `provision` (content provided by TASK-0008).
- **Step sequence:**
  1. Call `provision`; on non-zero exit call `show_recovery` and loop (offer retry or quit). `provision` internally manages sub-step sequencing, emits sub-step events, and calls `session_set_provision_step` — the wizard shell does not duplicate any of this.
  2. On success: call `session_advance`, proceed.
  3. Call `verify`; same retry logic.
  4. Call the first-file write step from `lib/checksum_write.sh`.
- **Complete:** print a completion summary (ZFS pool, datasets, running containers, verified hash).
- **Interrupt handling:** trap `SIGINT`/`SIGTERM`; call `emit session_abandoned` before exiting.
- All prompts use `read -r`; no dependency on `dialog` or `whiptail` in this iteration.

## Acceptance Criteria

- bats end-to-end test (all libraries and provisioner mocked) covers: fresh run happy path, resume from mid-session (checkpoint level), resume from mid-provision (sub-step level, e.g. `PROVISION_STEP=docker_installed`), failure-then-recovery-then-complete, interrupt during provisioning.
- No business logic in `wizard.sh` — all delegated to sourced scripts.
- Script passes `shellcheck` with no warnings.

## Dependencies

- TASK-0003 (hardware detection)
- TASK-0008 (debian_linux provisioner)
- TASK-0009 (recovery messaging)
- TASK-0010 (session persistence)
- TASK-0011 (checkpoint emitter)
- TASK-0013 (checksum write step)
