---
id: SOL-0001
status: accepted
problem_hypothesis_id: HYP-0001
target_metric_id: MET-0001
---
# User-Held E2E Encryption Layer

## Context

HYP-0001 establishes that custody and disclosure-boundary control are structurally lost when users store personal data on big-tech cloud platforms. The provider holds decryption keys by default (Evidence §5), which means the provider and any party that legally compels them can read user data at will. Behavioral profiling of stored content (Evidence §7) is a downstream consequence of the same key-custody arrangement. Only a small fraction of users have activated opt-in E2E encryption where it exists (e.g., iCloud Advanced Data Protection), and most providers do not offer it at all for general file storage.

The problem is not the cloud storage model itself — it is that encryption keys are held by someone other than the user. If the user holds their own keys and encryption/decryption occurs exclusively on client devices, the provider is reduced to an encrypted-blob store: structurally unable to profile, disclose, or revoke access to the content (though they can still revoke access to the storage infrastructure).

This solution hypothesis addresses two of the five control dimensions from HYP-0001:

- **Custody:** User holds keys; provider cannot decrypt.
- **Disclosure boundary:** Compelled provider disclosure yields ciphertext, not plaintext; no behavioral profiling of content is possible.

It does not directly address access continuity, portability, or terms stability (see SOL-0002 and SOL-0003).

## Decision

Build and validate a client-side encryption layer that intercepts file storage operations — wrapping existing big-tech cloud providers as the transport layer — where key generation, storage, and rotation are entirely user-controlled, with no key escrow with the service operator.

Key design choices under test:

1. **Zero-knowledge architecture:** The service never receives plaintext or keys. Server-side search and thumbnailing are not possible; client-side indexing compensates.
2. **Key portability via user-controlled passphrase or hardware key (e.g., FIDO2):** Keys must survive provider account loss, meaning they cannot be derived from provider credentials.
3. **Transparent to the underlying provider:** Works with Google Drive, iCloud, OneDrive, Dropbox, and S3-compatible storage as transport layers without requiring provider cooperation.
4. **Progressive disclosure UX:** Key management is surfaced clearly; users must understand the custody trade-off (no provider-assisted recovery) before activation.

## Experiments

### Experiment 1 — Key setup completion rate (usability gate)

- **Hypothesis:** ≥70% of users who begin the key-setup flow will complete it and successfully encrypt at least one file within the same session.
- **Method:** Instrument the onboarding flow; measure drop-off at each step (passphrase creation, key backup confirmation, first-file encryption).
- **Risk signal:** If completion rate is <50%, the UX creates a new control problem — users are blocked from their own data — and the design must be revised before broader rollout.

### Experiment 2 — Custody comprehension test

- **Hypothesis:** ≥80% of users who complete onboarding can correctly answer: "If your account at [provider] is terminated, can you still access your files?"
- **Method:** Present a 3-question comprehension check post-setup; gate on understanding before activating production encryption.
- **Goal:** Confirm users meaningfully understand the custody shift, not just click-through it.

### Experiment 3 — Provider-compelled disclosure simulation

- **Hypothesis:** A simulated legal request to the service operator for a specific user's files returns only ciphertext with no recoverable plaintext.
- **Method:** Internal red-team exercise; engineering validation of the zero-knowledge architecture.
- **Pass criterion:** Zero plaintext or key material accessible server-side for any E2E-encrypted vault.

### Experiment 4 — Adoption trajectory (30 / 60 / 90 days)

- **Hypothesis:** E2E encryption adoption rate (MET-0001) reaches 20% of active users within 30 days of general availability, 40% within 60 days, 60% within 90 days.
- **Method:** Cohort analysis of activation events.
- **Risk signal:** If adoption plateaus below 20%, the friction or comprehension barrier is too high; revisit progressive disclosure and default-on options.

## Success Criteria

The solution hypothesis is validated if, after 90 days of general availability:

1. **MET-0001 ≥ 60%** — Majority of active users hold their own encryption keys.
2. **Custody comprehension ≥ 80%** — Users who activate E2E encryption can correctly describe what they control and what they give up.
3. **Zero plaintext exposure** — Internal red-team and third-party audit confirm zero server-side plaintext or key access for E2E-encrypted vaults.
4. **Key setup completion ≥ 70%** — Users who begin the setup flow complete it without abandonment.

The solution hypothesis is **not** validated if MET-0001 remains below 20% at 90 days, or if any audit finds plaintext accessible server-side.

## Consequences

**If validated:**

- The custody and disclosure-boundary dimensions of HYP-0001 are addressed for adopting users.
- The service becomes structurally unable to comply with government data requests beyond metadata; this has legal and regulatory implications (jurisdiction-dependent) that must be explicitly scoped.
- Server-side features requiring plaintext access (AI-powered search, cloud-side thumbnailing, sharing via link preview) are unavailable for E2E vaults; client-side alternatives are required.
- Sets a strong trust differentiator vs. default big-tech cloud storage.

**If not validated:**

- Key management UX may be fundamentally incompatible with non-technical users at meaningful adoption rates — a constraint that may require defaulting to a passphrase-recovery model, which weakens the custody guarantee.
- The disclosure-boundary dimension may require regulatory or legal approaches (provider policy advocacy, jurisdiction selection) rather than a technical solution.

**Residual risks regardless of outcome:**

- E2E encryption does not prevent the provider from revoking storage access — the access dimension of HYP-0001 is not addressed here.
- Lost passphrases with no escrow mean permanent data loss; this shifts custody risk from provider to user, which may not be a net improvement for all users.
- Key rotation and multi-device key sync add ongoing complexity that compounds over the account lifetime.
