---
id: MET-0002
status: proposed
problem_hypothesis_id: PROB-0001
---

# Successful Portable Export Rate

## Context

PROB-0001 identifies incomplete portability (§3) as a structural control-loss mechanism: current big-tech export tools produce point-in-time archives with format friction, multi-day generation times, and metadata loss that make data practically non-portable for most users. The Portability dimension of the problem is only solved if users can actually get their data out — in a usable, complete, standards-compliant form — without specialist technical skill. This metric measures whether the solution delivers on that promise.

## Decision

**Successful Portable Export Rate** = the percentage of export attempts that complete with:

1. All files present (zero missing items vs. the library manifest at export-request time), **and**
2. Metadata embedded in open standards (EXIF for photos, ID3 for audio, Dublin Core / sidecar XMP for documents) — no proprietary sidecar-only formats, **and**
3. Export package generated and ready for download within **60 minutes** for libraries up to 50 GB.

An export attempt is initiated when a user triggers an export. It is counted as a failure if any of the three criteria above are not met, or if the user abandons the flow before download (interpreted as a usability failure).

Target: **≥ 95% of export attempts** succeed by the above definition, measured monthly.

## How we measure

- **Data source:** Server-side export job telemetry — each export job records item count (manifest vs. packaged), metadata-embedding pass/fail per file type, and wall-clock duration.
- **Query:** `COUNT(export_jobs where all_items_present AND metadata_embedded AND duration_minutes <= 60) / COUNT(export_jobs_initiated)`, monthly.
- **Spot-check:** Monthly automated canary export of a synthetic 10 GB library with known EXIF, sidecar JSON, and document metadata; automated diff confirms zero data loss and correct embedding.
- **Instrumentation required:** Export pipeline must write per-file metadata embedding outcome to a job log. Front-end must fire an `export_abandoned` event with a step identifier if the user leaves the export flow.

## Consequences

**What this makes easy to optimise for:** Fast, complete, standards-compliant exports. Engineering will be incentivised to invest in efficient packaging pipelines and robust metadata-embedding tooling rather than treating export as a low-priority edge case.

**What this makes easy to game or ignore:** The metric counts export _attempts_ regardless of whether the user actually had a use for the export (e.g., emergency migration vs. routine backup test). A high rate achieved by making exports trivially easy to trigger but hard to use downstream would look good here but fail users. A companion qualitative measure — "did you successfully import your export into another system?" — is needed to close this gap. The 60-minute threshold is also tuned for 50 GB; very large libraries (>1 TB) will need a separate SLA and should not drag down this metric.
