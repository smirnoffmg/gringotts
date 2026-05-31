---
id: TASK-0003
status: todo
feature_id: FEAT-0001
title: Implement hardware self-detection
---

# Implement Hardware Self-Detection

## Goal

Implement `detect_hardware.sh` so that all tests from TASK-0002 pass. The script inspects local OS markers to set `HARDWARE_CLASS`.

## Scope

- Check for Debian-family Linux: `/etc/os-release` where `ID=debian` or `ID_LIKE` contains `debian`. Sets `HARDWARE_CLASS=debian_linux`.
- On unrecognised hardware: exit `2`, set `GRINGOTTS_ERROR_CODE=UNSUPPORTED_HARDWARE`, `GRINGOTTS_ERROR_MSG`, and `GRINGOTTS_REMEDIATION`.
- Script is sourced by the wizard main script; the detected class is available as `HARDWARE_CLASS`.
- Detection order: reserved NAS/SBC markers (`/etc/synoinfo.conf`, `/etc/config/uLinux.conf`, `/proc/device-tree/model`) are checked first and produce `UNSUPPORTED_HARDWARE` — this prevents misidentifying a Debian-based NAS firmware as `debian_linux`.

## Acceptance Criteria

- All tests from TASK-0002 pass (green).
- Script has no side effects beyond setting `HARDWARE_CLASS` — no writes, no network calls.
- Script is independently sourceable; no dependency on wizard flow or session state.

## Dependencies

- TASK-0001 (error variable convention)
- TASK-0002 (tests must exist first)
