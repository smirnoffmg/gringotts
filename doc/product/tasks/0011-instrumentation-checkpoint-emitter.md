---
id: TASK-0011
status: todo
feature_id: FEAT-0001
title: Implement local checkpoint log emitter
---

# Implement Local Checkpoint Log Emitter

## Goal

Implement `lib/emit.sh` — a sourceable script that appends structured checkpoint events to a local log file at `~/.gringotts/provisioning.log`. This log is the measurement instrument for the SOL-0002 Experiment 1 completion-rate metric.

## Scope

Emit the following named events (at minimum) with associated fields:

| Event                  | Fields                                                          |
| ---------------------- | --------------------------------------------------------------- |
| `zfs_installed`        | `hardware_class`                                                |
| `zfs_pool_created`     | `hardware_class`, `device`                                      |
| `zfs_datasets_created` | `hardware_class`                                                |
| `docker_installed`     | `hardware_class`                                                |
| `repo_cloned`          | `hardware_class`, `tag`                                         |
| `tailscale_configured` | `hardware_class`                                                |
| `compose_deployed`     | `hardware_class`, `services` (space-separated list)             |
| `first_file_written`   | `hardware_class`, `checksum_verified` (0 or 1)                  |
| `session_resumed`      | `hardware_class`, `resumed_at_checkpoint`, `provision_step`     |
| `step_failed`          | `hardware_class`, `step`, `error_code`                          |
| `session_abandoned`    | `hardware_class`, `last_completed_checkpoint`, `provision_step` |

- Log format: one event per line, `timestamp=<epoch> event=<name> <key=value ...>`.
- `emit <event> [key=value ...]` — the single public function; appends one line to the log.
- `emit` must never exit non-zero or print to stdout/stderr — instrumentation failures must not surface to the user.
- Secrets (domain, keys) must never appear in log lines.

## Acceptance Criteria

- bats unit tests: each defined event name, when passed to `emit`, results in a log line containing all required fields.
- bats unit test: `emit` does not exit non-zero even if the log file is unwritable.
- `lib/emit.sh` has no dependency on provisioner scripts, session state, or wizard flow.

## Dependencies

- TASK-0001 (event/step vocabulary aligns with provisioner contract)
