---
id: FEAT-0004
status: proposed
solution_hypothesis_id: SOL-0001
architectural_review_status: pending
metric_ids:
  - MET-0002
---

# Open Data Formats and Portable Export

## Context

PROB-0001's Portability dimension identifies incomplete portability as a structural control-loss mechanism: even if a user decides to leave a big-tech platform, export tools produce point-in-time archives with format friction, multi-day generation times, and metadata loss that make practical portability a myth for most users. SOL-0001 addresses this by committing to open data formats and a local-first storage model as defaults — not just as an export option.

This feature is the reversibility guarantee for the entire solution. SOL-0001's Consequences section explicitly identifies open data formats and export capability (MET-0002) as the mechanism by which users can always leave, even if the application is discontinued. A user who migrates to this self-hosted platform must never face the same lock-in they experienced with big-tech providers.

MET-0002 (Successful Portable Export Rate) targets ≥ 95% of export attempts completing with all files present, metadata in open standards, and generation within 60 minutes for libraries ≤ 50 GB. This feature is the sole driver of that metric.

## Decision

**In scope:**

- **Local-first directory structure:** Files stored on the server are in their original formats (JPEG, RAW, DNG, PDF, DOCX, etc.) organised in a human-readable directory tree (`/library/YYYY/MM/DD/filename.ext`). The user can browse, copy, or back up the file store using standard filesystem tools without the application. No proprietary container format wraps the files.
- **Metadata embedded at rest:** All metadata (capture date, GPS, camera model, album name, description, tags) is embedded directly in file EXIF (for photos) or XMP sidecar (for formats that do not support embedded EXIF, e.g., PDF, DNG). No metadata lives only in the application database; the database is a performance index, not the canonical metadata store. If the database is deleted, metadata can be re-indexed from the files.
- **One-click export:** A user-initiated export from the app UI generates a download package (ZIP or tar.gz, user's choice) containing all files in their original formats with embedded metadata. Export is paginated into volumes of ≤ 10 GB to allow download on consumer internet connections; multi-volume exports are numbered and a manifest file lists all volumes and their contents.
- **Export progress and completion notification:** The export job runs server-side as a background task. The app shows a progress indicator (files packaged / total). When complete, the user receives an in-app notification and, if configured, an email notification with a download link valid for 72 hours.
- **Open-source `vault-decrypt` CLI:** The same CLI introduced in FEAT-0001 also handles format verification: `vault-decrypt --verify` checks that all files in an encrypted store decrypt to valid, non-corrupt files and that all EXIF fields are present for photos. This gives users and auditors an independent tool to verify the integrity of their archive without depending on the application being available.
- **Database re-index from files:** An admin command (`server reindex`) rebuilds the application's metadata database entirely from the files on disk, without any external data source. If the database is lost or corrupted, the user runs this command and the application is fully restored.

**Out of scope:**

- Streaming export (downloading individual files or albums as they are packaged, before the full export is complete) — a future UX improvement; the v1 export is a complete-package-then-download model.
- Export to a third-party destination (e.g., uploading directly to a new cloud provider's S3 bucket) — out of scope; the export produces a local archive, not a push to another service.
- Scheduled automatic exports — valuable as a backup strategy but a separate feature; v1 export is user-initiated.
- Format conversion at export time (e.g., converting HEIC to JPEG during export) — out of scope; files are exported in their stored format. Format conversion is a separate library management feature.
- Differential or incremental export (exporting only files added since last export) — deferred; v1 export is full-library.

## Acceptance criteria

- When a user browses the server's file store directory using a standard filesystem client (e.g., SSH + ls, or mounting as a network drive), they can see individual files in their original format (JPEG, RAW, PDF) organised under `/library/YYYY/MM/DD/`. No file is wrapped in a proprietary container that prevents direct opening.
- When the application database is deleted and `server reindex` is run, the application's library view is fully restored (all files, metadata, albums) matching the pre-deletion state — verified by comparing file count and a random sample of 20 files' metadata fields before and after.
- When a user initiates an export of a library ≤ 50 GB from the app UI, the export package is ready for download within 60 minutes (matching MET-0002's SLA). A progress indicator is visible throughout.
- When a user downloads and unzips the export package, all files open without error in at least two of the following independent tools: Apple Photos (macOS 13+), digiKam 7+, darktable 4+, Windows Photos. No file is corrupt or zero-byte.
- When a photo in the library has an embedded GPS coordinate, capture date, and camera model, the same three fields are present and correct in the exported file's EXIF (verified by running `exiftool` on the exported file).
- When a library contains 500 photos with known EXIF and 50 documents with known Dublin Core metadata, the export package contains all 550 files with zero metadata field loss (matching Experiment 4's pass criterion).
- When a multi-volume export (library > 10 GB) completes, a manifest file at the root of the first volume lists all volumes by filename and their file-count ranges, so the user can verify they have downloaded all volumes.
- When a user runs `vault-decrypt --verify` on their encrypted store, the command reports the total file count, the count of files that decrypted successfully, the count with complete EXIF, and exits with a non-zero status code if any file fails decryption or is corrupt.
- When an export job completes, the user receives an in-app notification. If the user has configured an email address, they also receive an email notification with a download link. The download link expires after 72 hours.
- ≥ 95% of export attempts initiated in production meet all three MET-0002 criteria (all files present, open-standard metadata, ≤ 60 minutes for ≤ 50 GB) measured monthly.

## Consequences

**Database as performance index, not source of truth:** Embedding metadata in files rather than the database is the correct design for portability but creates a write-amplification pattern: every metadata edit (adding a tag, changing a description) must write to the file's EXIF as well as the database. For RAW files, this means updating a potentially large file for a small metadata change. A sidecar XMP file is used for formats where in-file EXIF modification is impractical (e.g., DNG with embedded RAW data), which reintroduces a sidecar dependency but keeps the sidecar in an open standard.

**Export generation load:** Generating a multi-GB export package is CPU- and I/O-intensive and can impact server performance for other users on shared hardware. The export job must be throttled or scheduled during off-peak hours, which conflicts with the 60-minute SLA for on-demand exports. This tension must be resolved in the server implementation; a dedicated export queue with resource limits is the likely approach.

**The 72-hour download link is a security surface:** A signed, time-limited URL for an export download is a standard pattern, but it means the full plaintext archive is temporarily accessible via a URL. For zero-knowledge-conscious users, this is a regression: the export package is decrypted before download (since the point of export is a portable plaintext archive). Users should be made aware of this explicitly. An alternative — client-side decryption of the export package after download — is a follow-up option for users who want end-to-end protection of the export itself.

**Re-index performance for large libraries:** The `server reindex` command is an O(n) operation over all files and will take significant time for large libraries (e.g., > 100 000 files). This is acceptable as a disaster recovery tool but not as a routine operation. The command must produce a progress indicator and support resumption if interrupted.

**MET-0002 measurement gap for very large libraries:** The ≤ 50 GB / 60-minute SLA is the defined success criterion. Libraries larger than 50 GB will routinely exceed this threshold; they should be tracked under a separate SLA and must not drag down the reported MET-0002 rate. The export pipeline must tag jobs by library size so that ≤ 50 GB and > 50 GB cohorts can be reported separately.
