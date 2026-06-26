---
id: FEAT-0003
status: proposed
solution_hypothesis_id: SOL-0001
architectural_review_status: pending
metric_ids:
  - MET-0001
  - MET-0003
---

# Continuous Device Sync

## Context

SOL-0001's 90-day retention success criterion (≥ 60% of users who complete migration are still actively syncing at 90 days) requires that the self-hosted personal cloud function as a seamless drop-in replacement for iCloud and Google Photos in daily use — not merely a migration destination. If users must manually trigger uploads or remember to back up their devices, the product does not solve the control-loss problem: it creates a new one, where the user's most recent photos and files are not protected until they remember to act.

The target persona (non-expert consumer, currently relying on a default big-tech platform) expects automatic background sync as table-stakes behaviour. Experiment 3 in SOL-0001 tests self-hosting setup; the 45-minute time-to-first-sync criterion implies that sync must begin reliably and visibly within a reasonable setup window. Users who never see a successful sync will not believe the product is working and will revert to the managed platform.

This feature must also maintain the zero-knowledge constraint established by FEAT-0001: files are encrypted client-side before transmission. Sync must not introduce any code path where plaintext leaves the device.

## Decision

**In scope:**

- iOS and Android mobile apps with a background photo sync service that automatically detects new photos in the device camera roll and queues them for encrypted upload to the user's configured instance. Sync runs over Wi-Fi by default; a user-configurable option allows sync over mobile data.
- macOS, Windows, and Linux desktop clients with a watched folder (user-configured) that automatically syncs new and modified files to the user's instance, and syncs new files from the instance back to the local folder (bidirectional). The desktop client installs as a system tray / menubar application.
- First-sync experience: on initial setup, the app shows an estimated time to complete the initial library upload based on current upload speed and library size, so the user can set appropriate expectations rather than wondering whether the app is working.
- Conflict resolution: when the same file is modified on two devices before either change syncs, both versions are preserved with a disambiguating suffix (e.g., `report_deviceA.pdf`, `report_deviceB.pdf`) and the user is notified. No silent overwrites.
- Sync status visible at a glance: a persistent indicator in the app (mobile) and system tray (desktop) shows one of three states: Synced (all files up to date), Syncing (n files queued), or Paused (user-initiated or connectivity-triggered). A tap/click expands to a log of recent activity.
- The user-configured server address is the only required setup input. The app derives all API endpoints from the base URL; no port numbers, paths, or certificates need to be entered manually (assuming standard TLS on 443 with a valid certificate).

**Out of scope:**

- Peer-to-peer sync between devices without the server as intermediary — a future performance optimisation; not in v1.
- Selective sync (choosing which folders or albums sync to which devices) — valuable but adds UI and configuration complexity; deferred to a follow-up feature.
- Sync from third-party apps (Dropbox, Google Drive, etc.) running alongside this client — out of scope; the client syncs from the user's device filesystem or camera roll only.
- Real-time collaborative editing (e.g., simultaneous multi-user document edits with operational transform) — out of scope; this is a personal cloud, not a collaborative editing tool.
- Server-side duplicate detection across devices — deduplication at sync time is done client-side by checking the local manifest before upload; server-side deduplication is a separate performance feature.

## Acceptance criteria

- When a user takes a new photo on their iOS or Android device while connected to Wi-Fi, the photo appears in their self-hosted library (visible in the mobile app's photo grid) within 5 minutes of being taken, without any manual user action.
- When a user adds a file to the watched folder on their desktop client, the file appears in the self-hosted library and on all other connected devices within 5 minutes, without any manual user action.
- When a file is uploaded via the mobile or desktop sync client, no plaintext file content or filename is transmitted to the server (verified by network inspection: server receives only ciphertext with opaque identifiers matching FEAT-0001's contract).
- When the user's device has no Wi-Fi connectivity, the sync client queues pending uploads locally and automatically resumes sync when Wi-Fi is restored, without user intervention, and without losing any queued items.
- When the same file has been independently modified on two devices before syncing, both versions are preserved on the server with distinct filenames (original name plus a device identifier suffix), and the user receives an in-app notification listing the conflict within 60 seconds of the sync resolving.
- The sync status indicator reflects the current state accurately: it shows "Synced" only when the local manifest matches the server manifest for all files; it shows "Syncing" with a file count while uploads or downloads are in progress; it shows "Paused" when the user has manually paused or when the configured connectivity condition (e.g., Wi-Fi only) is not met.
- On initial app setup, after the user enters their server address and passphrase, the app displays an estimated time to complete the initial library upload (based on measured upload speed and local library size) within 30 seconds of completing authentication.
- The setup flow — from app install to first successful photo sync — is completable by ≥ 10 of 15 non-technical users within 45 minutes using only the written setup guide, matching the Experiment 3 pass criterion.
- The mobile app's background sync continues uploading new photos when the app is not in the foreground, on both iOS (using Background App Refresh) and Android (using WorkManager), without requiring the user to open the app manually for each upload.

## Consequences

**Battery and data usage:** Background sync on mobile consumes battery and, if the mobile-data option is enabled, cellular data. The default Wi-Fi-only setting mitigates data cost, but battery impact depends on photo volume. This must be measured during beta and documented for users; excessive battery drain is a known cause of users disabling background sync, which directly threatens the 90-day retention criterion.

**iOS background sync limitations:** Apple's Background App Refresh imposes constraints on how frequently and how long background tasks can run. For users with high photo volumes (e.g., burst photography), there may be a lag of up to 30 minutes between photo capture and sync completion. The 5-minute acceptance criterion applies to typical single-shot photo capture; burst scenarios are explicitly outside that SLA and should be disclosed.

**Zero-knowledge constraint on filenames:** To maintain FEAT-0001's zero-knowledge contract, filenames transmitted to the server must also be encrypted or replaced with opaque identifiers. This means the server cannot index files by name, which affects search and browsing UX. Client-side filename encryption must be designed alongside FEAT-0001's client SDK; this feature assumes that contract is in place.

**Conflict resolution UX at scale:** The "preserve both versions with suffix" conflict resolution strategy is safe but produces clutter for users who frequently edit documents on multiple devices. A more sophisticated last-write-wins or merge strategy is technically possible for certain file types (text, markdown) but is deferred as follow-up work to keep v1 scope bounded.

**Self-hosted instance availability:** If the user's self-hosted server is offline (power outage, router change, travel), sync pauses until connectivity is restored. This is expected behaviour for a self-hosted model, but it is a regression versus iCloud/Google Photos, which are always available. The managed hosting on-ramp (FEAT-0005) mitigates this for users who are not yet comfortable with self-hosting.
