# 3. Zero-Knowledge Constraint on Managed Hosting

Date: 2025-07-14

## Status

Proposed

## Context

FEAT-0005 (Managed Hosting On-Ramp) introduces a deployment topology where the application vendor operates the server infrastructure on the user's behalf. SOL-0001's core architectural commitment — established by FEAT-0001 — is that the server must never possess plaintext or a recoverable form of the encryption key. The question this ADR records is whether that constraint is preserved, relaxed, or extended when the vendor controls the server hardware.

There is a strong product incentive to relax the constraint for the managed tier. Vendor-operated infrastructure makes it technically possible to add server-side key management — for example, to support account recovery without a recovery code, or to enable server-side search and AI features. Each of these is a genuine UX convenience. MET-0001 (User-Held Key Custody Rate, target ≥ 90%) and MET-0003 (Perceived Data Control Score) are both undermined the moment the managed server can decrypt user content, because the product's privacy guarantee becomes a policy claim rather than a technical fact.

The managed hosting option must contribute to MET-0001, not erode it. That requires the guarantee to be technically verifiable, not merely contractual.

## Decision

The FEAT-0001 zero-knowledge constraint applies without relaxation to the managed hosting tier. Specifically:

- The managed server stores only ciphertext. It never receives plaintext file content or a decryptable form of the user's content key.
- Key derivation and per-file envelope encryption/decryption use the identical FEAT-0001 client SDK, deployed unchanged on mobile, desktop, and browser upload paths. The SDK is not modified for managed-tier users.
- There is no server-side key escrow option, including no optional escrow framed as "convenience" or "account recovery." Any proposal to add server-side key management to the managed tier must be treated as a violation of this decision and must not proceed without superseding this ADR.
- The zero-knowledge guarantee must be verifiable: the managed hosting environment is explicitly included in the quarterly penetration test required by FEAT-0001's MET-0001 audit. Penetration test summaries are published.
- Network traffic between managed-tier clients and the managed server must satisfy the same inspection criterion as FEAT-0001: no plaintext file content or decryptable key material in any request or response body.

**Rejected alternative — Managed tier with optional server-side key escrow:**
Allow users to opt in to server-held key escrow on the managed tier for account recovery convenience. Rejected because: (a) it bifurcates the client SDK into two code paths, increasing audit surface; (b) once escrow exists, it becomes a social-engineering and legal-compulsion target regardless of the "optional" framing; (c) it causes managed-tier users to fail the MET-0001 custody criterion, directly undermining the solution's primary metric; and (d) it is hard to reverse — users who have enrolled in escrow cannot retroactively un-share their key with the server.

**Rejected alternative — Managed tier with server-side search via homomorphic or trusted-execution-environment encryption:**
Accept that the managed server holds a limited, search-only form of key material inside a TEE. Rejected at this stage because TEE-based architectures are complex to audit, have a history of side-channel vulnerabilities, and would require a new trust model to explain to users. This may be worth revisiting post-launch if on-device ML proves insufficient for search UX; a future ADR should supersede this one at that point.

## Consequences

- The managed hosting tier is architecturally identical to the self-hosted tier from the client SDK's perspective. This is a strong constraint that simplifies testing and audit but rules out server-side features (AI photo organisation, semantic search) that require plaintext access. These features must be delivered via on-device ML if they are to be delivered at all.
- The zero-knowledge guarantee on the managed tier is a technical fact, not a policy promise. This is the correct basis for user trust and for regulatory positioning (GDPR data processor obligations are materially lighter when the processor provably cannot access the data).
- The quarterly penetration test scope must explicitly name the managed hosting environment. Omitting it would leave the guarantee unverified.
- Server-side key escrow proposals — however they are framed — must be escalated and treated as requests to supersede this ADR, not as incremental feature requests. Engineering and product leads must both sign off on any such supersession.
- This decision is difficult to reverse in one direction: removing escrow after it has been offered to users is harder than never offering it. The asymmetry reinforces the decision to refuse it now.
