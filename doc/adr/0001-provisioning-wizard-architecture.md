---
id: ADR-0001
title: Provisioning Wizard Architecture
status: accepted
relates_to:
  - FEAT-0001
---

# ADR-0001 — Provisioning Wizard Architecture

## Status

Proposed

## Context

FEAT-0001 (Guided Primary-Store Provisioning) must guide non-expert users through standing up a self-hosted primary store. The first iteration targets a single hardware class: a Beelink ME Mini (Intel N150 iGPU, 16 GB RAM) running Debian 13. The wizard installs ZFS, creates a storage pool and dataset layout, installs Docker, and deploys the gringotts service stack (Traefik, Jellyfin, Immich, the *arr suite, Gluetun/qBittorrent). The wizard must achieve ≥60% single-session completion and must not require prior sysadmin knowledge.

The first iteration is implemented as a bash/CLI tool. Five decisions have meaningful architectural consequences:

1. How platform-specific provisioning logic is structured so the main script stays hardware-agnostic.
2. Where partial provisioning state is persisted when the primary store is not yet online.
3. How the wizard determines which hardware class it is running on.
4. How elevated-privilege operations are communicated to the user before they run.
5. How the wizard script is delivered to the target device in a way consistent with the self-hosting trust model.

## Decision

### 1. Hardware-class abstraction layer (sourced scripts)

Platform-specific provisioning logic lives in a `provisioners/` directory, one script per hardware class (`synology.sh`, `qnap.sh`, `raspberry_pi.sh`, `debian_linux.sh`). Each script defines a fixed set of functions (`detect`, `provision`, `verify`). The main wizard script sources the appropriate file at runtime after hardware detection and calls only those functions — it has no hardware-specific branching of its own.

This structure is intentionally reusable: FEAT-0002 (replica configuration) and FEAT-0003 (recovery flow) can source the same scripts without duplication. The function signatures must therefore be stable before those features enter implementation.

**Rejected alternative:** A single script branching on hardware type via `if`/`case` — this couples wizard flow and platform logic, making the FEAT-0002/FEAT-0003 reuse dependency implicit and hard to maintain.

### 2. Local provisioning session state

While the primary store is not yet online it cannot hold session state. Partial provisioning state (last completed checkpoint, hardware class, configuration parameters) is written to a local state file (`~/.gringotts/provisioning_state`). The file uses a simple `key=value` format and is sourced at startup to resume from the last completed checkpoint.

The session file is deleted automatically on provisioning completion. It is also treated as stale and ignored if its timestamp is older than 7 days, at which point the wizard restarts from the beginning. The file stores only checkpoint index, hardware class identifier, and non-sensitive configuration (host address, chosen directory path); credentials are never written to it.

**Rejected alternative:** Server-side session state — introduces a dependency on a remote product service during initial setup, which contradicts the self-hosted-first model and adds unnecessary infrastructure for a CLI tool.

### 3. Hardware self-detection via local OS/firmware markers

The wizard runs on the target device. Hardware class is determined by inspecting local filesystem markers — no network discovery is needed:

- Synology DSM: presence of `/etc/synoinfo.conf`
- QNAP QTS: presence of `/etc/config/uLinux.conf`
- Raspberry Pi: `/proc/device-tree/model` containing `Raspberry Pi`
- Debian-family Linux: `/etc/os-release` with `ID=debian` or `ID_LIKE` containing `debian`, and no NAS/SBC markers above

Detection is read-only and produces no side effects. If no marker matches, the wizard exits with an unsupported-hardware error rather than guessing.

**Rejected alternative:** mDNS/Bonjour network discovery — applicable only when the wizard runs on a separate client machine, not on the device being provisioned. Since the wizard runs on the target, local marker inspection is simpler, faster, and requires no network tooling.

### 4. Privileged operations: pre-execution disclosure gate

On Debian-family systems the wizard runs `apt`, `ufw`, `useradd`, and `systemctl` with elevated privileges. Before any privileged operation runs, the wizard must print a disclosure screen listing: (a) which packages it will install, (b) which network ports it will open, (c) which system user it will create, and (d) a link to the wizard source. The user must type `yes` before execution proceeds.

This is a hard requirement, not a UX suggestion. Running privileged operations before the user understands their scope violates informed consent and creates unacceptable support and trust risk.

**Rejected alternative:** Running privileged operations silently on first launch — standard practice for many installers but incompatible with the product's self-hosting trust model.

### 5. Wizard delivery: download-verify-run, then git clone

The wizard is distributed as a single versioned shell script. The only supported installation method is:

```bash
curl -LO https://github.com/org/gringotts/releases/download/v<version>/wizard.sh
sha256sum -c <<< "<published-digest>  wizard.sh"
bash wizard.sh
```

Each release publishes a SHA-256 digest alongside `wizard.sh`. Users must verify the digest before running. The digest is the trust anchor: it lets the user confirm they are running the exact script that was reviewed and released, not a modified version.

Once running, `wizard.sh` clones the gringotts repository at the matching release tag into `~/gringotts/` and operates from within that directory for all subsequent steps (compose files, Makefile). The clone step requires `git`; the wizard installs it via `apt` if absent. The cloned tag is pinned to the same version as `wizard.sh` — the wizard does not clone `main`.

**Rejected alternative:** `curl ... | bash` — executes the script before the user can inspect it or verify integrity, and makes the pre-execution disclosure gate in Decision 4 meaningless since the script is already running by the time any disclosure is printed.

**Rejected alternative:** Bundled tarball — a tarball containing `wizard.sh` and all compose files would work but adds release tooling complexity. A single versioned script that clones a pinned tag achieves the same reproducibility with simpler packaging.

## Consequences

- The `provisioners/` function signatures become a cross-script contract. Breaking changes affect FEAT-0002 and FEAT-0003; a versioning or deprecation policy is required before those features ship.
- Local session state means resumption only works on the same machine. Cross-device resumption is not supported in this iteration.
- Hardware self-detection relies on filesystem markers that could be absent on non-standard or customised firmware images; the unsupported-hardware error path must be clear enough that users can report their device variant for future support.
- The pre-execution disclosure gate adds one interactive step to the Debian-family happy path. This is an acceptable completion-rate cost given the security requirement.
- Each release must publish a SHA-256 digest alongside `wizard.sh`. The digest and the script must be updated atomically; a mismatched or missing digest will block installation until corrected.
- The download-verify-run pattern places responsibility on the user to run the `sha256sum` check. Users who skip verification get no integrity guarantee; documentation must make this explicit.
