---
id: FEAT-0001
status: proposed
solution_hypothesis_id: SOL-0001
architectural_review_status: pending
metric_ids:
  - MET-0001
  - MET-0003
---

# Zero-Knowledge Client-Side Encryption

## Context

SOL-0001 was accepted as the primary response to PROB-0001's Custody dimension: users store data under keys held by the provider, meaning the provider can decrypt, scan, and disclose files without explicit user consent. The solution's core architectural commitment is that the server must never possess plaintext or a recoverable form of the encryption key. Every other feature in this solution — migration, sync, export, managed hosting — depends on this cryptographic foundation being in place and comprehensible to non-expert users.

Experiment 2 in SOL-0001 specifically tests whether non-technical users understand the zero-knowledge model and the recovery code responsibility before any product is built. The pass criterion (median PDCS ≥ 70, ≤ 2 users confused by recovery codes) shapes two requirements for this feature: the key derivation must be invisible to users in normal operation, and the recovery code onboarding must be explicit and unavoidable.

This feature directly drives MET-0001 (User-Held Key Custody Rate, target ≥ 90% of active accounts) and contributes to MET-0003 (Perceived Data Control Score, target median ≥ 80 at T+90 days) by giving users a concrete, auditable basis for trusting that their data is private.

## Decision

**In scope:**

- Client SDK (shared across mobile apps, desktop client, and browser upload path) that derives an encryption key from the user's passphrase using Argon2id (memory: 64 MiB, iterations: 3, parallelism: 4 as minimum parameters; user-configurable upward). The derived key never leaves the device.
- Per-file envelope encryption: a random 256-bit AES-GCM content key is generated for each file; the content key is wrapped with the user's derived key and stored alongside the ciphertext. This allows key rotation without re-encrypting the full library.
- A recovery code — 24 random words (BIP-39 wordlist) encoding a 256-bit backup key — generated at account creation, used to wrap the master key as a second envelope. The user must confirm they have written it down before setup completes; there is no server copy.
- Onboarding screen that explains, in plain language, that the server cannot decrypt the user's files and that losing both passphrase and recovery code means permanent data loss. The user must actively check a checkbox and proceed; they cannot skip.
- An open-source CLI tool (`vault-decrypt`) that allows a user to decrypt their encrypted file store using only their passphrase or recovery code, without the application running — demonstrating and guaranteeing escape from vendor lock-in.

**Out of scope:**

- Social recovery (splitting the master key across trusted contacts) — identified as follow-up work in SOL-0001; not in this feature to avoid delaying the cryptographic core.
- Hardware key (passkey / FIDO2) binding for recovery — follow-up work; too complex to ship alongside the core.
- Server-side key escrow of any kind — explicitly excluded by the zero-knowledge requirement; any escrow proposal must be treated as a violation of this feature's contract.
- Shared links that expose plaintext to the server — a separate feature decision; this feature does not define the sharing model.
- On-device ML or search indexing — separate features; this feature establishes the encryption layer only.

## Acceptance criteria

- When a user creates an account and sets a passphrase, a recovery code (24 BIP-39 words) is shown exactly once. The user cannot proceed past the onboarding screen without checking a box confirming they have recorded the code. The next screen does not display the code again.
- When a user uploads a file, the file content transmitted to the server is ciphertext. A network inspector (e.g., browser DevTools or Charles Proxy) shows no recognisable plaintext, filename, or EXIF data in the request body.
- When a security researcher with full read access to the server database and file store attempts to decrypt any stored file without the user's passphrase or recovery code, decryption fails. (Verified by independent penetration test; canary file approach.)
- When a user installs the app on a new device and enters their passphrase, all previously uploaded files decrypt correctly and display with their original content and metadata.
- When a user enters their recovery code (24 words) on a new device after forgetting their passphrase, all previously uploaded files decrypt correctly.
- When a user runs `vault-decrypt --passphrase <phrase> --input <encrypted-store-dir> --output <plaintext-dir>`, all files are decrypted to their original format within the output directory, with zero file-count discrepancy versus the encrypted store manifest.
- The Argon2id parameters used for key derivation are logged in the account's key metadata record and are readable by the user in the app's Security settings screen.
- Key derivation on a reference device (a 2019 mid-range Android phone, e.g., Pixel 3a) completes in ≤ 5 seconds for the minimum Argon2id parameters, so that unlock does not feel broken to the user.
- The onboarding screen explaining zero-knowledge encryption and recovery code responsibility scores ≥ 70 median PDCS in the Experiment 2 usability test cohort (8–10 non-technical users), validating that the explanation is comprehensible before launch.

## Consequences

**Security posture:** Moving key material entirely to the client eliminates a whole class of server-side breaches for user data. It also means any server-side vulnerability cannot expose plaintext — a meaningful and auditable privacy guarantee.

**Irrecoverable data loss risk:** Users who lose both their passphrase and recovery code lose their data permanently. This is an explicit, unavoidable tradeoff of the zero-knowledge model. The onboarding screen and the SOL-0001 hypothesis both call this out. There is no server-side safety net. This tradeoff must be re-evaluated if user research (Experiment 2 failure mode) shows non-technical users consistently misplace recovery codes.

**Feature constraints on the rest of the product:** Any feature that requires the server to read file content — server-side thumbnail generation, server-side full-text search, server-side AI organisation — is incompatible with this feature's contract. Those features must be solved on the client side (on-device ML, client-side indexing) or deferred. This creates ongoing engineering cost but also a healthy forcing function for privacy-preserving design.

**Key rotation cost:** The envelope encryption scheme allows passphrase changes without re-encrypting file content (only content-key envelopes are re-wrapped). However, a user who suspects their passphrase is compromised must rotate all content keys to be fully safe — this is an O(n files) operation and can be slow for large libraries. Key rotation UX is not in scope here but must be a follow-up feature before GA.

**Audit dependency:** MET-0001 requires quarterly independent penetration tests to confirm the server cannot decrypt canary files. This creates a recurring operational and budget commitment that the team must plan for from the start.
