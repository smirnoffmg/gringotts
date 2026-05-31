---
id: FEAT-0001
title: Guided Primary-Store Provisioning
status: accepted
solution_hypothesis_id: SOL-0002
architectural_review_status: cleared
---

# Guided Primary-Store Provisioning

## Context

SOL-0002 requires that the authoritative copy of user data reside on hardware the user controls. The critical risk identified in SOL-0002 Experiment 1 is that self-hosting friction can itself become an access problem: users who cannot complete setup are worse off than on a default cloud. The provisioning flow is therefore a usability gate, not merely a setup step. The design must achieve ≥60% completion rate (non-expert users, single session) before broader rollout is justified.

The target hardware surface is intentionally broad: consumer NAS appliances (Synology, QNAP), single-board computers (Raspberry Pi), and self-managed VPS instances. Each has a different entry point but must converge on the same end state — a reachable, initialised primary store.

## Decision

Build a step-by-step provisioning wizard that guides users from hardware detection through storage initialisation to first-file write, with inline diagnostics and recovery prompts at each failure point. The wizard abstracts all platform-specific configuration (network discovery, drive formatting, daemon installation) behind a single, consistent interaction surface. No sysadmin knowledge should be required to reach a working primary store.

Key design choices:

1. **Hardware detection first.** The wizard actively discovers reachable candidate hosts on the local network (mDNS/Bonjour, direct IP entry) and presents them by name and model before asking the user to make any configuration decisions. Users should recognise their device before typing anything.
2. **Single-path happy flow.** For each hardware class there is exactly one opinionated default path (storage pool, directory layout, daemon config). Advanced options are accessible but collapsed — the default flow produces a working result without them.
3. **Per-step instrumented checkpoints.** Each wizard step emits a completion event: hardware detected, storage initialised, daemon reachable, first file written, replica optionally configured. Drop-off is measurable at step granularity, enabling targeted iteration against the 40% abort-risk threshold.
4. **Failure-mode inline recovery.** If any step fails (device unreachable, drive not formatted, port blocked), the wizard presents a plain-language explanation and a specific remediation action — not a generic error. The user does not need to leave the flow to consult documentation.
5. **Session resumption.** If the user closes the wizard mid-flow, progress is saved and the session can be resumed from the last completed checkpoint. Incomplete provisioning does not leave the primary store in an inconsistent state.

## Acceptance Criteria

- A first-time user with no sysadmin experience can complete primary-store setup on a Synology NAS, a Raspberry Pi 4, and a freshly provisioned Ubuntu VPS without consulting external documentation.
- Provisioning completion rate (hardware detected -> first file written on primary) reaches ≥60% across a minimum 50-user instrumented pilot.
- If completion rate falls below 40% on any single hardware class, that class is flagged in the instrumentation dashboard and blocked from general availability until remediated.
- Every wizard failure state surfaces a plain-language explanation and a single next action; no step produces a raw error code or an empty failure screen.
- Session state persists across browser/app restarts; resuming a partial session requires no repeated steps.
- The wizard does not require the user to open a terminal on the primary-store host unless explicitly choosing the VPS path (which has a one-command bootstrap).
- The first-file write step confirms byte-level integrity (checksum verified on the primary) before the wizard declares provisioning complete.

## Consequences

**If this feature is successful:**

- The provisioning completion gate is cleared, unblocking broader rollout of SOL-0002.
- Instrumentation data from per-step checkpoints feeds directly into the SOL-0002 Experiment 1 measurement, providing evidence for or against the solution hypothesis.
- The hardware-class abstraction layer established here is reused by the replica configuration path (FEAT-0002) and the recovery flow (FEAT-0003).

**If this feature underperforms:**

- Drop-off data at step granularity will identify whether friction is concentrated at hardware detection, storage initialisation, or network reachability — enabling targeted redesign rather than wholesale replacement.
- Persistent <40% completion on any hardware class may indicate that class should be removed from the supported surface or replaced with a managed-hardware option, partially reintroducing provider dependence as acknowledged in SOL-0002 Consequences.

**Residual risks:**

- Hardware diversity (firmware versions, drive configurations, router NAT behaviours) creates a long tail of edge cases that instrumented pilots may not surface until general availability.
- Session resumption requires storing partial provisioning state server-side; if the primary is not yet online, that state must be held by the product service — introducing a transient dependency on the product service even in the self-hosted-first model.
- Guided setup on VPS requires the user to run a bootstrap command with elevated privileges; the security implications of that command (what it installs, what network ports it opens) must be surfaced before execution, not after.
