---
id: SOL-0002
status: accepted
problem_hypothesis_id: HYP-0001
target_metric_id: MET-0002
---
# Self-Hosted-First Storage with Cloud as Optional Replica

## Context

HYP-0001 establishes that access continuity and terms stability are structurally lost when users commit personal data to big-tech cloud platforms. Providers can terminate accounts unilaterally with no guaranteed recovery path (Evidence §2), and they reserve the right to change pricing and terms on data users already committed under prior conditions (Evidence §6) — Google Photos ending unlimited free storage in 2021 is the canonical case. In both, the failure mode is the same: the provider is the source of truth, so the provider controls whether and on what terms the user keeps their own data.

SOL-0001 addresses custody and disclosure boundary by making the provider hold only ciphertext, but it explicitly leaves access untouched — an E2E provider can still revoke the storage infrastructure and lock the user out of the encrypted blobs. The remaining lever is *where the authoritative copy lives*. If the primary copy resides on hardware the user controls (a home NAS, a self-managed VPS), and the cloud is demoted to an optional, replaceable replica, then termination and terms changes lose their coercive power: the user already physically holds their data.

This solution hypothesis addresses two of the five control dimensions from HYP-0001:

- **Access:** The authoritative copy is user-controlled; provider termination cannot revoke it.
- **Terms stability:** Pricing or ToS changes affect only an optional replica the user can drop or swap without data loss.

It does not directly address custody or disclosure boundary on the replica (see SOL-0001, which composes with this), nor portability of format (see SOL-0003).

## Decision

Build and validate a self-hosted-first storage model in which the user's own hardware is the source of truth, and any big-tech cloud is configured as an optional, fully replaceable replica rather than the primary store.

Key design choices under test:

1. **Local-primary, cloud-secondary topology:** All reads and writes resolve against user-controlled storage first; cloud replicas are write-through backups, never the authoritative copy. Loss of every cloud replica is a degraded-redundancy event, not a data-loss event.
2. **Low-friction provisioning:** Standing up the primary store must not require sysadmin skill — target a guided setup on commodity hardware (NAS appliance, single-board computer, or a one-command VPS deploy) that a non-expert can complete.
3. **Provider-agnostic replica layer:** Replicas target any S3-compatible or consumer cloud backend interchangeably, so a terminated or repriced provider can be dropped and replaced without touching the primary.
4. **Honest availability trade-off in UX:** Self-hosting shifts the uptime and durability burden to the user; the design must surface this (power loss, drive failure, home-network reachability) rather than imply cloud-grade reliability.

## Experiments

### Experiment 1 — Provisioning completion rate (usability gate)

- **Hypothesis:** ≥60% of users who begin the primary-store setup flow complete it and successfully store at least one file on user-controlled hardware within the same session.
- **Method:** Instrument the guided provisioning flow; measure drop-off at each step (hardware detection, storage initialization, first-file write, replica configuration).
- **Risk signal:** If completion rate is <40%, self-hosting friction reintroduces an access problem of its own — users who cannot stand up the primary are worse off than on a default cloud. Revise provisioning before broader rollout.

### Experiment 2 — Termination-survival simulation

- **Hypothesis:** Simulated termination of every configured cloud replica leaves the user with full, immediate read/write access to all data via the primary store.
- **Method:** Engineering validation — revoke all replica credentials and disconnect cloud backends; confirm zero data loss and uninterrupted access.
- **Pass criterion:** 100% of data remains accessible from the primary; no manual recovery step required.

### Experiment 3 — Terms-change resilience test

- **Hypothesis:** A user can drop a repriced or terms-changed provider and substitute a new replica backend without data loss and without reconfiguring the primary.
- **Method:** Walk a test cohort through a provider swap (drop provider A, add provider B); measure data integrity post-swap and time-to-complete.
- **Goal:** Confirm replicas are genuinely fungible — that no provider holds the user hostage on terms.

### Experiment 4 — Durability under user-side failure (reliability gate)

- **Hypothesis:** With at least one cloud replica configured, a simulated primary-hardware failure (drive loss) is fully recoverable from replica with zero data loss.
- **Method:** Destroy the primary store in a test environment; rebuild from replica; verify byte-level integrity.
- **Risk signal:** If recovery is incomplete or requires expert intervention, the model trades provider-controlled access loss for user-controlled access loss — not a net improvement. Recovery must be guided and reliable.

## Success Criteria

The solution hypothesis is validated if, after 90 days of general availability:

1. **MET-0002 ≥ 50%** — Majority of active users have their authoritative copy on user-controlled hardware with the cloud demoted to replica.
2. **Termination survival = 100%** — Simulated loss of all cloud replicas leaves all data accessible from the primary, with no manual recovery.
3. **Provider swap with zero data loss** — Users can drop and replace a cloud backend without data loss or primary reconfiguration.
4. **Provisioning completion ≥ 60%** — Users who begin primary-store setup complete it without abandonment.

The solution hypothesis is **not** validated if provisioning completion remains below 40% at 90 days, or if termination-survival or hardware-failure-recovery tests show any data loss.

## Consequences

**If validated:**

- The access and terms-stability dimensions of HYP-0001 are addressed for adopting users: no provider can revoke or reprice their way to control over the user's data.
- The durability and availability burden shifts to the user; the product takes on responsibility for making that burden manageable (guided recovery, replica health monitoring, failure alerting).
- Composes cleanly with SOL-0001: encrypted blobs (custody) on a user-owned primary (access) covers four of the five control dimensions together.
- Establishes a defensible position that default cloud-primary competitors structurally cannot match without abandoning their business model.

**If not validated:**

- Self-hosting friction may be fundamentally incompatible with non-technical users at meaningful adoption — which may force a managed-hardware or hosted-primary middle ground that partially reintroduces provider dependence.
- The access dimension may require a different mechanism (e.g., multi-provider federation, SOL-0005) rather than user-owned primary hardware.

**Residual risks regardless of outcome:**

- Self-hosting does not address custody or disclosure boundary on the cloud replica — without SOL-0001, an unencrypted replica reintroduces the §4/§5 exposure on the backed-up copy.
- A user-owned primary with no cloud replica configured trades provider-controlled access loss for total data loss on hardware failure; replica configuration cannot be optional in practice.
- Ongoing maintenance (power, drive replacement, network reachability, security patching) compounds over the account lifetime and is a sustained burden the provider previously absorbed.
