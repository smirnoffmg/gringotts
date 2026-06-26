---
id: SOL-0001
status: accepted
metric_ids:
  - MET-0001
  - MET-0002
  - MET-0003
---

# Self-Hosted E2E-Encrypted Personal Cloud with One-Click Migration Assistant

## Context

PROB-0001 identifies five control-loss dimensions — Access, Custody, Portability, Terms Stability, and Disclosure Boundary — all rooted in the same structural condition: users store data on infrastructure they do not own, under keys they do not hold, governed by terms they cannot negotiate. The disconfirmation analysis (D3) confirms that user-controlled alternatives exist (Nextcloud, Immich, Synology), but they require substantial technical skill to set up and no migration path from existing big-tech libraries. The target persona is the non-expert consumer who currently stores data on a default big-tech platform and has not actively sought alternatives.

**Why this approach over alternatives:**

_Alternative A — Regulated-provider model (rejected):_ Advocate for or build a product that keeps data on managed cloud infrastructure but under stricter contractual terms, mandatory E2E encryption, and regulated portability (e.g., a GDPR-compliant European cloud provider). This addresses Terms Stability and Disclosure Boundary incrementally but does not solve Custody (a managed provider still holds keys by default in most architectures) and creates a different concentrated dependency. It is also a slow regulatory play. Rejected as the primary solution because it leaves the structural Custody gap unaddressed and is not reversible — users remain dependent on a third-party provider under better-but-still-asymmetric terms.

_Alternative B — Browser extension / audit tool that stays on big-tech platforms (rejected as primary, retained as SOL-0002):_ A lightweight tool that audits existing cloud storage settings, enables available E2E options (e.g., iCloud Advanced Data Protection), and runs continuous export/sync to a local drive. This is maximally reversible and requires no infrastructure. It is retained as SOL-0002 for users unwilling to migrate, but rejected as the primary solution because it cannot change the structural Custody or ToS Stability dimensions — it works within the existing provider relationship rather than replacing it.

_Chosen approach:_ A self-hosted personal cloud application (photo library + general file sync) that the user runs on their own hardware (NAS, home server, Raspberry Pi class device) or on a VPS they control, with:

- Client-side E2E encryption by default (user holds keys, server never sees plaintext)
- A one-click migration assistant that imports from Google Photos/Takeout, iCloud export, and OneDrive, normalising metadata to open standards (EXIF, XMP) in the process
- Continuous device sync (mobile + desktop) as a drop-in replacement for the big-tech default

This approach fully addresses all five control dimensions. It is a **significant commitment** — users take on operational responsibility for their own infrastructure — which is noted explicitly as a consequence below.

## Decision

Build a self-hosted personal cloud application with the following mechanisms:

**1. Zero-knowledge architecture by default**
All files are encrypted client-side using a key derived from the user's passphrase via Argon2id before leaving the device. The server stores only ciphertext. Key derivation and encryption/decryption happen entirely in the client SDK (mobile app, desktop client, browser extension for web upload). There is no server-side key escrow; recovery depends on a user-generated recovery code stored offline.

**2. One-click migration assistant**
An onboarding flow that accepts a Google Takeout archive, Apple Data & Privacy export ZIP, or OneDrive full backup, and:

- Parses proprietary sidecar formats (Google's JSON metadata files, Apple's HEIC+AAE pairs) and embeds metadata directly into file EXIF/XMP fields
- Deduplicates against files already on the user's device
- Uploads the normalised, encrypted library to the user's self-hosted instance in a resumable background job

**3. Continuous sync as default cloud replacement**
Mobile apps (iOS, Android) and a desktop client (macOS, Windows, Linux) provide background photo and file sync to the user's instance, replicating the UX of iCloud/Google Photos. The server address is user-configured; the apps are indistinguishable in daily use from a managed cloud app.

**4. Open data formats and local-first storage**
The underlying file store uses a directory structure the user can browse directly without the application. Files on disk are in their original format (JPEG, RAW, PDF, etc.) with metadata embedded. The encrypted-at-rest layer is a thin wrapper the user can decrypt with the open-source client tools even if the application is discontinued.

**5. Managed hosting option as an on-ramp (reversible)**
For users unwilling to manage their own hardware, offer a managed hosting option that still uses the same zero-knowledge client-side encryption — the managed server never holds keys. This is explicitly positioned as temporary infrastructure while the user decides on self-hosted hardware, with a documented one-click migration to self-hosted at any time.

## Experiments

**Experiment 1 — Migration assistant usability test (pre-build)**

- _Action:_ Recruit 8 non-technical users (screened for: currently using Google Photos or iCloud, no self-hosting experience). Give each a pre-built Google Takeout archive and a staging instance of the migration assistant. Observe unassisted completion.
- _Pass criterion:_ ≥ 6 of 8 complete the import without support intervention, and ≥ 6 report that their metadata (dates, albums, locations) carried over correctly after inspection.
- _Fail criterion:_ Fewer than 6 complete without help, or ≥ 3 report metadata loss → indicates the migration assistant UX or metadata normalisation pipeline needs significant rework before proceeding.

**Experiment 2 — E2E encryption comprehension test (pre-build)**

- _Action:_ Show 10 non-technical users a one-page onboarding explainer of the zero-knowledge model and the recovery code flow. Then administer the four PDCS questions (MET-0003). No product to interact with — test comprehension of the written explanation alone.
- _Pass criterion:_ Median PDCS ≥ 70 after reading the explainer, and ≤ 2 users express confusion about the recovery code responsibility.
- _Fail criterion:_ Median PDCS < 60 or ≥ 4 users are confused by recovery codes → the mental model explanation must be redesigned before shipping onboarding.

**Experiment 3 — Self-hosting willingness and drop-off (technical spike + survey)**

- _Action:_ Build a minimal Docker Compose deployment of the server (photo index + file store + sync API). Recruit 15 users from target persona (non-technical, current big-tech cloud users) and ask them to follow a written setup guide. Measure time-to-first-sync and drop-off point.
- _Pass criterion:_ ≥ 10 of 15 reach first successful sync within 45 minutes using the guide alone.
- _Fail criterion:_ Fewer than 10 succeed, or median time > 60 minutes → indicates the self-hosting UX requires a pre-configured hardware appliance or managed on-ramp to be viable for this persona before a pure software approach.

**Experiment 4 — Export round-trip test (technical spike)**

- _Action:_ Generate a synthetic library of 500 photos with known EXIF (GPS, date, camera model), 50 documents (PDFs with Dublin Core metadata), and 20 Google Photos JSON sidecar files. Run the migration assistant. Diff the output against the source using exiftool and a metadata validation script.
- _Pass criterion:_ Zero metadata fields dropped; all sidecar data correctly embedded into EXIF/XMP; output files open correctly in three independent tools (Apple Photos, digiKam, darktable).
- _Fail criterion:_ Any metadata field loss rate > 0.5% or any file that fails to open in ≥ 1 reference tool → indicates a format-conversion bug requiring a fix before user testing.

## Success criteria

Measured at 6 months post-general-availability:

| Metric                                    | Target                                                                                                                   |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| MET-0001: User-Held Key Custody Rate      | ≥ 90% of active accounts have 100% of files under client-side E2E encryption                                             |
| MET-0002: Successful Portable Export Rate | ≥ 95% of export attempts complete with all files, open-standard metadata, within 60 minutes for ≤ 50 GB                  |
| MET-0003: Perceived Data Control Score    | Median PDCS ≥ 80 at T+90 days, and ≥ 30 points above the big-tech control group baseline                                 |
| Migration completion rate                 | ≥ 70% of users who initiate the migration assistant complete it (library fully imported and encrypted on their instance) |
| 90-day retention                          | ≥ 60% of users who complete migration are still actively syncing at 90 days                                              |

## Consequences

**Tradeoffs and risks:**

- **Operational burden shifts to the user.** Self-hosting means users are responsible for backups, uptime, hardware failure, and software updates. This is a significant and explicit commitment — for the disconfirmation-D2 persona (users who have never experienced a loss-of-control incident), the operational overhead may feel like a net regression in convenience. The managed hosting on-ramp mitigates this for early adopters, but the long-term bet is that the target persona values control enough to accept this tradeoff. That bet must be validated by Experiment 3 before heavy investment.

- **Recovery key UX is a hard problem.** Zero-knowledge encryption requires the user to safeguard a recovery key. Users who lose both their passphrase and recovery code lose their data permanently — a worse outcome than the provider-holds-keys model. Experiment 2 specifically tests whether users understand and accept this. If they don't, a social-recovery or hardware-key model (e.g., passkey-bound recovery) must be designed before launch.

- **Feature parity with big-tech is a moving target.** Google Photos' AI features (scene recognition, face grouping, semantic search) rely on server-side access to plaintext. A zero-knowledge architecture makes these features hard to replicate without on-device ML, which is feasible on modern hardware but requires sustained investment. Shipping without these features risks being perceived as a step backward in UX, not just a privacy trade.

- **This is a significant infrastructure commitment.** Unlike SOL-0002, this solution cannot be "undone" cheaply once users have migrated their libraries. The open data formats and export capability (MET-0002) are the reversibility mechanism — they ensure users can always leave — but the migration effort is real. This must be communicated clearly at onboarding.

**Follow-up work introduced:**

- Design social/hardware recovery key UX (prerequisite to launch)
- On-device ML pipeline for photo organisation features (post-launch investment)
- Security audit of client SDK key derivation and encryption implementation (prerequisite to launch)
- Companion browser extension for web-upload E2E path (post-launch)
- Investigate appliance hardware (pre-configured NAS/Pi) as a distribution channel if Experiment 3 shows self-setup is too hard
