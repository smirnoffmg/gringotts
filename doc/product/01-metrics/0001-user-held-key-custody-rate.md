---
id: MET-0001
status: proposed
problem_hypothesis_id: PROB-0001
---

# User-Held Key Custody Rate

## Context

PROB-0001 identifies provider-held encryption keys (§5) as a core structural mechanism of control loss. A user whose data is encrypted under a key they hold — and that the provider never possesses — is immune to provider-compelled disclosure, accidental account termination data loss, and content scanning. This metric measures whether the solution actually shifts key custody to users, which is the single most decisive technical indicator of restored control along the Custody dimension.

## Decision

**User-Held Key Custody Rate** = the percentage of active user accounts for which all stored files are encrypted under a key derived exclusively from user-controlled credentials (i.e., the service has zero-knowledge of the plaintext and cannot decrypt without the user's passphrase or device key).

A user account counts toward the numerator only if:

- The encryption key is generated client-side and never transmitted to the server in plaintext or in a recoverable form, **and**
- A third-party audit or reproducible test confirms the server cannot decrypt the stored ciphertext.

Accounts with _any_ server-readable files (e.g., shared links using server-side re-encryption) are excluded from the numerator for those files.

Target: **≥ 90% of active accounts** maintain 100% user-held key custody at steady state.

## How we measure

- **Data source:** Application telemetry — each file upload records the encryption mode (client-side E2E vs. server-side). Aggregated per account at the end of each billing period.
- **Query:** `COUNT(accounts where all_files_e2e = TRUE) / COUNT(active_accounts)`, computed weekly.
- **Audit:** Quarterly penetration test by an independent security firm; testers attempt decryption of a canary file using only server-side access. Pass = canary remains opaque.
- **Instrumentation required:** Client SDK must emit an `encryption_mode` field on every upload event. Server telemetry pipeline aggregates this to an account-level flag.

## Consequences

**What this makes easy to optimise for:** Any feature that moves a file outside E2E (e.g., server-side thumbnail generation, server-side search indexing) will visibly depress this metric, creating a healthy forcing function to solve those features in a privacy-preserving way (e.g., on-device indexing, client-side thumbnail generation).

**What this makes easy to game or ignore:** A team could technically achieve 100% by disabling all features that touch plaintext (sharing, OCR search, AI organisation) rather than solving them properly. The metric must be read alongside feature-adoption metrics to ensure E2E coverage doesn't come at the cost of a product users won't actually use. It also says nothing about whether the user's _device_ or _passphrase_ is itself secure — key custody on the server side does not guarantee key safety on the client side.
