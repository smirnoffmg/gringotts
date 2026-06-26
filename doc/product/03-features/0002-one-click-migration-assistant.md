---
id: FEAT-0002
status: proposed
solution_hypothesis_id: SOL-0001
architectural_review_status: pending
metric_ids:
  - MET-0002
  - MET-0003
---

# One-Click Migration Assistant

## Context

SOL-0001's adoption depends on non-technical users being able to move their existing photo and file libraries — held in Google Photos, iCloud, and OneDrive — onto their self-hosted instance without specialist skill. The disconfirmation analysis in SOL-0001 (D3) found that existing self-hosted alternatives (Nextcloud, Immich, Synology) have no migration path from big-tech libraries, which is a primary reason non-technical users have not adopted them. Without a reliable migration path, asking users to abandon their existing library is asking them to accept permanent data loss as a precondition of switching.

Experiment 1 in SOL-0001 (migration assistant usability test) sets the bar: ≥ 6 of 8 non-technical users must complete the import without support intervention, and ≥ 6 must confirm that dates, albums, and locations carried over correctly. Experiment 4 (export round-trip test) sets the technical bar: zero metadata fields dropped across a 500-photo, 50-document synthetic library, with output opening correctly in Apple Photos, digiKam, and darktable.

This feature is the primary driver of the migration completion rate success criterion (≥ 70% of users who initiate the assistant complete it) and contributes to MET-0002 (Successful Portable Export Rate) by normalising metadata to open standards at import time — meaning every file on the user's instance is already in a portable state.

## Decision

**In scope:**

- A guided onboarding flow (step-by-step wizard, ≤ 5 screens) that accepts three input sources: (1) a Google Takeout archive (.zip or directory of .zips), (2) an Apple Data & Privacy export ZIP, and (3) a OneDrive full backup export. The user selects their source; the app handles the rest.
- Metadata normalisation pipeline:
  - Google Photos: parse per-photo JSON sidecar files (title, description, creation timestamp, GPS latitude/longitude, album membership) and embed all fields into the output file's EXIF (photos) or XMP (documents) before upload. The JSON sidecar is discarded after successful embedding.
  - Apple HEIC + AAE pairs: parse the AAE XML sidecar for edit history and adjustment data; embed the original capture metadata from the HEIC EXIF; transcode to user's choice of HEIC (lossless) or JPEG (maximum compatibility). AAE sidecar is discarded after embedding.
  - OneDrive: files are typically already in native formats with EXIF intact; the pipeline verifies EXIF completeness and flags any files with missing date fields for user review.
- Deduplication against files already on the user's device (perceptual hash for photos, SHA-256 for documents) before upload. Duplicates are listed for user confirmation; none are silently discarded.
- Resumable background upload job: the user can close the app and the import continues. Progress is shown as a persistent status bar (files imported / total, estimated time remaining). If the upload is interrupted, it resumes from the last successfully uploaded file on next app open.
- A post-import review screen showing: total files imported, total files skipped (duplicates), any files that could not be parsed (listed by filename with reason), and a random sample of 5 photos with their embedded dates and GPS locations for the user to visually verify.

**Out of scope:**

- Real-time API-based sync from Google Photos or iCloud (i.e., importing without a Takeout/export step) — requires OAuth integration with third-party APIs that can be revoked, rate-limited, or terminated; inconsistent with the self-hosted model's independence goal.
- Migration from services other than Google Photos, iCloud, and OneDrive in v1 — scope limited to the three sources covering the target persona's dominant use cases.
- Editing or re-processing of metadata after import — the migration assistant embeds metadata once; corrections are a separate library management feature.
- Automatic re-import when the source library changes — the migration assistant is a one-time onboarding tool, not a continuous sync bridge to big-tech platforms.
- Merging two self-hosted instances — out of scope for migration; a separate library merge feature.

## Acceptance criteria

- When a user selects a Google Takeout archive and initiates import, the wizard displays the total file count and estimated duration before any upload begins. The user can cancel at this point without any files being uploaded.
- When a Google Photos JSON sidecar file contains a GPS latitude/longitude, creation timestamp, and title, all three fields appear correctly in the imported file's EXIF (verified by opening the file in Apple Photos or digiKam) — with zero field-loss rate across a 500-photo synthetic test library (Experiment 4 pass criterion).
- When a Google Photos JSON sidecar references a file that is not present in the archive, the missing file is listed by name in the post-import review screen under "Files that could not be imported," with the reason "Source file missing from archive." The import of all other files continues.
- When a user closes the app during an active import, and reopens it, the import resumes automatically from the last successfully uploaded file, with no duplicate files created on the server.
- When a file already exists on the user's device (matched by perceptual hash for photos, SHA-256 for documents), it appears in the deduplication list before upload. The user must explicitly choose to skip or overwrite it; the app does not silently discard or overwrite the file.
- When the import completes, the post-import review screen shows a count of files imported, files skipped (duplicates), and files that could not be parsed. It also shows a sample of 5 randomly selected imported photos with their embedded capture date and GPS location (as a map pin), allowing the user to visually verify metadata accuracy.
- When a user with a 10 GB Google Takeout archive (≈ 3 000 photos) runs the migration assistant on a standard home broadband connection (50 Mbps upload), the import completes within 60 minutes of starting the upload phase (matching the MET-0002 SLA for ≤ 50 GB).
- Output files from Apple HEIC + AAE pairs open without error in Apple Photos on macOS 13+, digiKam 7+, and darktable 4+ (Experiment 4 pass criterion for reference tools).
- The migration wizard is completable without support intervention by ≥ 6 of 8 non-technical users in the Experiment 1 usability test, and ≥ 6 of those users confirm that dates, albums, and locations appear correctly in the post-import review screen.

## Consequences

**Migration completion rate dependency:** The 70% migration completion success criterion in SOL-0001 depends almost entirely on this feature. If the assistant fails Experiment 1, the entire solution hypothesis is at risk — not just this feature. The usability test must be run before significant engineering investment in the upload pipeline.

**Metadata normalisation is lossy for some edge cases:** Google Photos JSON sidecars occasionally contain fields with no EXIF equivalent (e.g., Google-specific "views" count, internal album IDs). These fields are discarded. The feature explicitly discards sidecar-only proprietary fields after embedding open-standard equivalents; users who care about Google-specific metadata are not the target persona and this tradeoff is acceptable.

**Archive format brittleness:** Google, Apple, and Microsoft can change their export archive formats at any time without notice. The metadata parsing pipeline must be treated as maintenance-heavy: each format change can silently break metadata embedding for new imports. An automated canary test (Experiment 4 equivalent) must be run on each new Takeout sample in CI to detect breakage early.

**Large-library UX:** For users with very large libraries (> 100 GB), the import may take multiple hours or days. The resumable job design handles interruption, but the post-import review screen's "sample of 5 photos" approach is insufficient for users who want to audit large libraries. A full metadata audit export (CSV of all files with embedded fields) is a natural follow-up feature.

**Deduplication false positives:** Perceptual hashing for photos can, in rare cases, flag visually similar but distinct photos (e.g., burst shots) as duplicates. The explicit user-confirmation step before any skip mitigates silent data loss, but the user experience of reviewing a large deduplication list is poor. Improved deduplication UX (grouped review, bulk decisions) is follow-up work.
