---
id: FEAT-0003
title: Replica Health Dashboard & Provider Swap
status: proposed
solution_hypothesis_id: SOL-0002
architectural_review_status: pending
---

# Replica Health Dashboard & Provider Swap

## Context

SOL-0002 shifts durability and availability burdens from the provider to the user. A self-hosted primary with no cloud replica exposes the user to total data loss on hardware failure; a primary with unhealthy or lagging replicas provides false confidence. SOL-0002 Decision §4 is explicit: the design must *surface* the trade-offs (power loss, drive failure, home-network reachability) rather than imply cloud-grade reliability.

This is a UX obligation, not merely a monitoring nicety. Without visibility into replica health, replication lag, and recovery readiness, users cannot make informed decisions about their durability posture. SOL-0002 Experiment 4 (hardware-failure recovery) requires that recovery be *guided and reliable* — that presupposes the user knows a replica exists, is current, and is recoverable before a failure occurs, not after.

Additionally, SOL-0002 Experiment 3 requires that provider swap be achievable without data loss and without reconfiguring the primary. The workflow for dropping and adding a provider belongs in this feature — it is the operational surface through which the provider-agnosticism of FEAT-0004 is exposed to users.

## Decision

Build a persistent health dashboard that gives users a clear, honest view of their storage topology — primary status, per-replica sync status and lag, durability class, and recovery readiness — and a guided provider-swap workflow that lets users drop and add cloud backends safely, with data-integrity verification at each step.

Key design choices:

1. **Honest durability classification.** The dashboard displays an explicit durability class for the user's current configuration: *Primary only* (highest risk — no replica), *Primary + replica (current)* (standard — replica within acceptable lag threshold), *Primary + replica (lagging)* (degraded — replica behind, durability window open), *Primary unreachable* (access risk — only replicas available, read-only mode). Users see the class label and a plain-language explanation of what it means for their data.
2. **Per-replica sync status and lag.** For each configured cloud backend, the dashboard shows the last successful sync time, the number of objects pending replication, estimated lag, and the result of the most recent checksum verification pass. Replica integrity errors are surfaced immediately as warnings, not buried in logs.
3. **Recovery readiness indicator.** The dashboard shows whether a full primary rebuild from each replica has been tested (via Experiment 4 validation runs) and when the last verified recovery point was. An untested replica is labelled as *unverified recovery path* — the user is informed that durability depends on it, but its recoverability has not been confirmed.
4. **Failure alerting.** Users configure alert thresholds: maximum acceptable replication lag, minimum number of healthy replicas, primary-unreachable timeout. Alerts are delivered in-app and optionally by email or push notification. Alerts are actionable — each alert links to the specific dashboard state that triggered it and a suggested remediation.
5. **Guided provider-swap workflow.** To drop a cloud backend: the dashboard verifies that at least one other replica (or the primary) holds a current, checksum-verified copy of all data before allowing the backend to be removed. To add a cloud backend: the workflow provisions credentials, runs an initial sync, and verifies checksum parity before marking the backend as healthy. The user cannot accidentally drop their last verified copy.
6. **Primary hardware-failure recovery path.** The dashboard surfaces a *Recover primary from replica* action, visible at all times (not only during failure). Selecting it initiates a guided rebuild: the user selects the source replica, the target hardware is provisioned (via the FEAT-0003 provisioning flow), and data is restored with byte-level integrity verification. The recovery path is tested, not improvised.

## Acceptance Criteria

- The dashboard displays a durability class label and plain-language explanation for every possible topology state (primary only, primary + replica current, primary + replica lagging, primary unreachable).
- Per-replica sync status, lag, pending-object count, and last-checksum-verification time are visible without navigating away from the main dashboard view.
- A replica with a failing checksum verification is surfaced as a warning within one sync cycle of the integrity error occurring; the user is not required to poll or inspect logs.
- The provider-drop workflow refuses to proceed if the replica being dropped is the only checksum-verified copy of any file on the system; it presents an explicit blocking explanation.
- The provider-add workflow completes an initial sync and checksum verification pass before marking the new backend as healthy; a partially synced backend is labelled *initialising*, not *healthy*.
- A user can complete a provider swap (drop provider A, add provider B, verify data integrity) following the guided workflow without data loss and without any change to the primary store configuration — satisfying SOL-0002 Experiment 3.
- The *Recover primary from replica* workflow is reachable from the dashboard at all times (not gated behind a failure state) and completes with byte-level integrity verification of the restored primary.
- Alert thresholds are user-configurable; at minimum, replication lag and minimum healthy replica count are configurable. Alerts link directly to the triggering dashboard state.
- The dashboard correctly reflects the *Primary + replica (lagging)* state within one sync cycle of the primary receiving a write that has not yet replicated.

## Consequences

**If this feature is successful:**

- Users have the information they need to maintain an adequate durability posture without requiring operational expertise — directly addressing SOL-0002 Decision §4's requirement to surface the trade-offs honestly.
- SOL-0002 Experiment 3 (provider swap with zero data loss) can be run through the guided workflow, providing measurable evidence for the solution hypothesis.
- SOL-0002 Experiment 4 (hardware-failure recovery) has a supported, guided path rather than requiring manual recovery — making the pass criterion (guided and reliable, no expert intervention) achievable.
- The recovery-readiness indicator creates a forcing function for users to run and verify recovery before they need it.

**If this feature underperforms:**

- If users do not engage with the dashboard (ignore lag warnings, skip recovery testing), the durability improvements of the architecture are nominal — the user is structurally better off but behaviourally unprotected. This may indicate the dashboard needs to be more intrusive (mandatory acknowledgement of degraded states) rather than passive.
- If the provider-drop safety check (last-verified-copy guard) produces false positives (e.g., due to checksum lag on a healthy replica), users may be unable to drop providers they intend to remove — eroding trust in the workflow. Checksum freshness thresholds must be calibrated carefully.

**Residual risks:**

- Recovery readiness depends on the replica being current at the time of primary failure, not at the time of the last dashboard check. A replica that was healthy at last check but lagged at failure time may produce an incomplete recovery. The dashboard's lag indicator reduces but does not eliminate this window.
- Alert fatigue: if the primary is frequently unreachable due to normal home-network events (router reboots, ISP outages), users will suppress alerts, defeating the purpose. Alert thresholds must be tuned to distinguish transient from persistent failures; this requires data from real-world primary deployments that may not be available pre-launch.
- The *Recover primary from replica* path depends on the FEAT-0003 provisioning flow being available for the target hardware at recovery time. If the user's hardware has changed (different NAS model, different OS), the provisioning path may need to be re-validated before recovery can proceed.
