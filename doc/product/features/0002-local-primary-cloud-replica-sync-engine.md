---
id: FEAT-0002
title: Local-Primary / Cloud-Replica Sync Engine
status: proposed
solution_hypothesis_id: SOL-0002
architectural_review_status: pending
---

# Local-Primary / Cloud-Replica Sync Engine

## Context

SOL-0002's core structural claim is that the user's own hardware is the source of truth and that cloud providers are demoted to optional, fully replaceable replicas. That claim requires an underlying sync engine that enforces the read/write topology: all operations resolve against the primary first, and replication to cloud backends is write-through and asynchronous. Without this engine, the topology is aspirational — any shortcut that reads from or promotes a cloud replica to authoritative status reintroduces the provider dependence the solution is designed to eliminate.

The engine must also satisfy SOL-0002 Experiments 2 and 3: simulated termination of all cloud replicas must leave data fully accessible from the primary (100% pass criterion), and a provider swap must be achievable without reconfiguring the primary or losing data. Both properties are structural — they must be enforced by the engine's architecture, not by operational procedure.

This feature composes with SOL-0001 (FEAT-0001/0002): if E2E encryption is active, the engine replicates ciphertext only — it never holds or transmits plaintext to cloud backends.

## Decision

Build a sync engine that implements a strict local-primary topology: the primary store is the single source of truth for all read and write operations, and cloud backends receive asynchronous write-through replicas. The engine enforces topology invariants at the protocol level so that no client operation can inadvertently resolve against a cloud replica.

Key design choices:

1. **Primary-first read/write contract.** Every file read and write is issued against the primary store. Cloud replicas are write destinations only — the engine never reads from a replica to serve a user operation, even when the primary is temporarily unreachable. If the primary is unreachable, the operation fails explicitly rather than silently falling back to a cloud replica.
2. **Asynchronous write-through replication.** After a write is committed and confirmed on the primary, the engine queues replication to each configured cloud backend. Replication is best-effort and non-blocking from the user's perspective; replica lag is tracked and surfaced (see FEAT-0005). A write is considered durable when it is committed on the primary — not when replica confirmation arrives.
3. **Provider-agnostic backend adapter.** Cloud backends are addressed through a pluggable adapter interface (S3-compatible API as the standard, with first-party adapters for common consumer clouds). Adding or removing a backend requires only credential configuration — the primary store and the rest of the engine are untouched. This directly satisfies the provider-swap requirement of SOL-0002 Experiment 3.
4. **Conflict model: primary wins.** If a replica diverges from the primary (e.g., due to a partial sync, a backend that applied its own transforms, or a replica-side manipulation), the primary is canonical and the divergence is surfaced as a replica integrity warning rather than a conflict to resolve.
5. **Replica loss is a degraded-redundancy event, not a data-loss event.** The engine must make this distinction explicit in its state model: a configuration with zero cloud replicas is valid (though warned), not broken. Loss of all replicas changes the durability class of the primary but does not change the availability or integrity of user data.
6. **Byte-level integrity verification.** Replicas are verified by checksum after each sync cycle. Any mismatch between the primary checksum and the replica checksum is flagged as a replica integrity error and triggers a re-sync, not a silent acceptance of the replica state.

## Acceptance Criteria

- All read and write operations in the client resolve against the primary store; no user-facing operation reads from a cloud replica to produce a result.
- If the primary is unreachable, client operations return an explicit unavailability error; no silent fallback to a cloud replica occurs.
- Simulated revocation of all cloud replica credentials leaves 100% of user data immediately accessible from the primary with no manual recovery step — satisfying SOL-0002 Experiment 2.
- Adding a new cloud backend (provider swap) requires only credential input; no changes to the primary store configuration, file layout, or client settings are required — satisfying SOL-0002 Experiment 3.
- Removing a cloud backend (provider drop) completes without data loss on the primary and without requiring a re-sync from the dropped provider.
- Each write is confirmed on the primary before the client receives a success response; replica confirmation is not required for write acknowledgement.
- Checksums are computed and stored for every file on the primary; each replica sync cycle verifies checksums and reports mismatches without auto-resolving in favour of the replica.
- The engine operates correctly when zero cloud replicas are configured; this state is warned but not treated as a configuration error that blocks operation.
- Replication to cloud backends operates without transmitting plaintext when SOL-0001 E2E encryption is active (ciphertext-only replication).

## Consequences

**If this feature is successful:**

- SOL-0002 Experiments 2 and 3 can be run and are expected to pass, providing direct evidence for the solution hypothesis.
- The provider-agnostic adapter layer creates a durable foundation for supporting new cloud backends without engine changes — including backends not yet anticipated.
- Composing with SOL-0001 (ciphertext-only replication) addresses four of the five HYP-0001 control dimensions in a single coherent architecture.

**If this feature underperforms:**

- If primary-unreachable situations are more frequent than anticipated (home network instability, NAS power cycles), the strict no-fallback policy may produce a poor availability experience — requiring a revisit of the topology contract or a more sophisticated offline-capable client.
- If checksum verification at scale produces unacceptable sync overhead, the verification cycle frequency may need to be configurable, introducing a durability vs. performance trade-off that must be surfaced to the user.

**Residual risks:**

- The primary-first contract creates a single point of failure if the user's hardware is offline; without a cloud replica, this is already the case, but with replicas the user may expect cloud fallback and be surprised by explicit failure. UX must set correct expectations (see also FEAT-0003 provisioning disclosures and FEAT-0005 health dashboard).
- Provider-agnostic adapters must handle backend-specific behaviours (rate limiting, eventual consistency, object size limits, multipart thresholds) without leaking those details into the engine core. Each new first-party adapter carries an ongoing maintenance burden.
- Replication lag is unbounded in the current design; a write committed on the primary that has not yet replicated represents a window of reduced durability. The engine must track and surface this window (FEAT-0005) but cannot eliminate it without synchronous replication, which would tie write latency to cloud round-trip times.
