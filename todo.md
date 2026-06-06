# Gringotts — Roadmap

## Phase 1 — USB Installer (feat/usb-installer)

- [x] Write Debian 13 preseed.cfg for Beelink ME Mini (TASK-0015)
- [x] Write USB installer creation script and instructions (TASK-0016)
- [ ] Test preseed flow end-to-end in UTM
- [ ] Verify 4-partition layout + `blkid -L gringotts` on p4
- [ ] Test on real Beelink hardware
- [ ] Merge to main

## Phase 2 — Provisioning Wizard (FEAT-0001)

Foundation:
- [ ] Define provisioner script contract (TASK-0001)
- [ ] Write failing bats tests for hardware self-detection (TASK-0002)
- [ ] Implement hardware self-detection (TASK-0003)
- [ ] Write failing bats tests for session persistence (TASK-0004)
- [ ] Implement session persistence (TASK-0010)

Hardware drivers:
- [ ] Implement provisioner — Beelink ME Mini / Debian-family Linux (TASK-0008)
- [ ] Implement provisioner — Synology NAS (TASK-0005)
- [ ] Implement provisioner — QNAP NAS (TASK-0006)
- [ ] Implement provisioner — Raspberry Pi (TASK-0007)

Reliability:
- [ ] Implement inline failure/recovery messaging (TASK-0009)
- [ ] Implement local checkpoint log emitter (TASK-0011)
- [ ] Write failing bats tests for first-file write + checksum (TASK-0012)
- [ ] Implement first-file write + checksum verification (TASK-0013)

Shell:
- [ ] Implement wizard main script (TASK-0014)

## Phase 3 — Service Stack (FEAT-0001 completion)

- [ ] Docker Compose definitions (Jellyfin, Immich, *arr)
- [ ] Deployed by wizard as final provisioning step

## Phase 4 — Cloud Sync Engine (FEAT-0002)

- [ ] Provider-agnostic sync driver
- [ ] Cloud demoted to optional, replaceable replica

## Phase 5 — Health Dashboard (FEAT-0003)

- [ ] Replica health monitoring
- [ ] Provider swap UI
