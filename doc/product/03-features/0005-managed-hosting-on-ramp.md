---
id: FEAT-0005
status: accepted
solution_hypothesis_id: SOL-0001
architectural_review_status: cleared
metric_ids:
  - MET-0001
  - MET-0003
---

# Managed Hosting On-Ramp

## Context

SOL-0001's Experiment 3 failure criterion is explicit: if fewer than 10 of 15 non-technical users can set up a self-hosted instance within 45 minutes, "the self-hosting UX requires a pre-configured hardware appliance or managed on-ramp to be viable for this persona before a pure software approach." The managed hosting on-ramp is SOL-0001's designed response to this risk: a hosted infrastructure path that preserves the zero-knowledge encryption contract, so that users who cannot yet manage their own hardware still gain the Custody, Disclosure Boundary, and Terms Stability improvements the solution promises.

The SOL-0001 Consequences section notes this directly: the managed on-ramp is "explicitly positioned as temporary infrastructure while the user decides on self-hosted hardware, with a documented one-click migration to self-hosted at any time." This framing is load-bearing — the on-ramp must not become a quiet lock-in vector that recreates the big-tech relationship it was designed to replace. The exit path to self-hosting must be as prominent and frictionless as the sign-up path.

The managed hosting option contributes to MET-0001 (User-Held Key Custody Rate) by still using client-side E2E encryption — the managed server holds only ciphertext, not keys — and to MET-0003 (Perceived Data Control Score) by giving users who cannot self-host a credible, auditable privacy guarantee rather than a choice between big-tech and technical complexity they cannot navigate.

## Decision

**In scope:**

- A managed hosting tier where the application vendor operates the server infrastructure on the user's behalf. The server stores only ciphertext; key derivation and encryption/decryption use the identical FEAT-0001 client SDK. The managed server has zero technical ability to read user file content — this must be verifiable, not just a policy claim.
- Onboarding that presents managed hosting and self-hosting as parallel first-class options. The managed hosting option is not the default; both options are presented neutrally with a clear explanation of the tradeoffs (managed: simpler setup, vendor-operated infrastructure; self-hosted: full infrastructure control, requires hardware).
- A self-hosting migration wizard accessible from the managed hosting account settings at any time. The wizard walks the user through: (1) setting up their self-hosted instance, (2) initiating an encrypted transfer of their library from the managed server to the self-hosted instance, (3) verifying the transfer is complete, and (4) deleting their data from the managed server.
- After migration to self-hosting is confirmed complete, the managed server executes a verified deletion of all the user's ciphertext. The user receives a deletion confirmation (timestamp, file count deleted) stored in their self-hosted instance.
- Transparent infrastructure disclosure: the app settings screen for managed hosting accounts lists the cloud provider(s) and geographic region(s) where the user's ciphertext is stored, updated within 30 days of any change.
- Pricing and terms: the managed hosting tier operates under a fixed, plain-language terms of service. The terms explicitly state: (a) the server cannot decrypt user content, (b) the user can export and migrate at any time, (c) the operator will give ≥ 90 days notice of any material terms change, and (d) if the service is discontinued, users receive ≥ 90 days to migrate.

**Out of scope:**

- A freemium tier with advertising or data monetisation — incompatible with the product's privacy positioning and the zero-knowledge contract.
- Managed hosting that uses server-side key management for "convenience" (e.g., optional key escrow for account recovery) — this would violate FEAT-0001's contract and undermine MET-0001; any key escrow proposal must be treated as a violation.
- Multi-tenancy features (organisational accounts, team sharing on managed hosting) — personal cloud product; team features are a separate future product line.
- White-labelling or reseller programme for managed hosting — out of scope for v1.
- SLA guarantees for managed hosting beyond what is documented in the terms — uptime SLAs, data durability guarantees, and support SLAs are operational commitments that must be defined separately before GA.

## Acceptance criteria

- When a new user reaches the onboarding screen, they are presented with a choice between managed hosting and self-hosting. Neither option is pre-selected. Each option shows a one-sentence description of the tradeoff. The user cannot proceed without actively choosing one.
- When a managed hosting user opens their account settings, a "Migrate to self-hosting" option is visible and accessible without navigating more than two levels deep in the settings hierarchy.
- When a managed hosting user completes the self-hosting migration wizard, all files are present and decryptable on their self-hosted instance (verified by file count comparison and decryption of a random sample of 10 files) before the managed server deletion step begins.
- When the migration wizard reaches the deletion step, the user must actively confirm deletion with an explicit acknowledgement ("I have verified my self-hosted library is complete. Delete my data from the managed server."). The deletion does not proceed without this confirmation.
- When managed server deletion completes, the user's account settings show a deletion confirmation record containing the timestamp and the count of files deleted. This record is stored on the self-hosted instance.
- When a network inspector examines traffic between the managed hosting client and the managed server, no plaintext file content or decryptable key material is present in any request or response body (same verification method as FEAT-0001's network inspection criterion).
- The managed hosting account settings screen displays the cloud provider name and geographic region of the user's stored ciphertext. This information is updated within 30 days of any infrastructure change.
- The managed hosting terms of service are accessible from within the app (not only via an external website) and contain, in plain language: (a) a statement that the server cannot decrypt user content, (b) a statement that the user can export and migrate at any time, (c) the minimum notice period for material terms changes (≥ 90 days), and (d) the minimum notice period if the service is discontinued (≥ 90 days).
- When a managed hosting user initiates a library export (via FEAT-0004), the export behaves identically to a self-hosted export: same file formats, same metadata standards, same time SLA. No managed-hosting-specific restrictions or delays apply to exports.

## Consequences

**Lock-in risk of the on-ramp itself:** The managed on-ramp is designed as temporary infrastructure, but product incentives (subscription revenue, growth metrics) may create internal pressure to make self-hosting migration harder or less prominent over time. This risk must be countered by making the migration path a first-class, tested feature — not a buried settings option — and by tracking the percentage of managed hosting users who successfully self-migrate as a health metric.

**Operational and regulatory complexity:** Operating a managed hosting service, even one that holds only ciphertext, creates compliance obligations (GDPR data processor status, data residency requirements, breach notification obligations). These are manageable but non-trivial and must be addressed with legal counsel before launch. The transparent infrastructure disclosure requirement in this feature is partly designed to support GDPR Article 30 (records of processing activities).

**The zero-knowledge guarantee requires ongoing verification:** Stating that the managed server "cannot decrypt" user content is a meaningful commitment only if it is independently verifiable. The quarterly penetration test required by FEAT-0001 (MET-0001 audit) must explicitly cover the managed hosting environment. Publishing the penetration test reports (summary, not full detail) is a transparency mechanism that supports user trust.

**Revenue model alignment:** The managed hosting tier is the most direct revenue mechanism in SOL-0001 (self-hosting users pay for software, not infrastructure). Subscription pricing must be set at a level that sustains operations without creating incentives to monetise user data or delay self-hosting migration. The terms of service commitment (no data monetisation) must be legally binding, not merely aspirational.

**Deletion verification gap:** After managed server deletion, the user receives a deletion confirmation record with a timestamp and file count. However, the user cannot independently verify that the operator actually deleted all ciphertext (e.g., from backups). Publishing a deletion policy (retention period for backups after account deletion, e.g., "backups purged within 30 days of account deletion") and including it in the terms of service closes this gap as a policy matter; technical verification of deletion is not currently feasible.
