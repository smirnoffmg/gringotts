# 4. Managed-to-Self-Hosted Migration Transfer Protocol

Date: 2025-07-14

## Status

Proposed

## Context

FEAT-0005 (Managed Hosting On-Ramp) requires a migration path from the vendor-operated managed hosting tier to a user-operated self-hosted instance. The migration wizard must transfer the user's full encrypted library — potentially hundreds of gigabytes — between two servers, verify completeness before deletion, and then trigger verified deletion on the managed server. The wizard is a first-class, tested feature, not a buried settings option; the SOL-0001 Consequences section explicitly names the risk that product incentives could degrade the migration path over time.

Three independent sub-decisions shape the transfer:

1. **Transfer direction:** does the managed server push ciphertext to the self-hosted instance, or does the self-hosted instance pull ciphertext from the managed server?
2. **Transfer channel:** does the transfer go server-to-server, or client-mediated (ciphertext transits the user's device)?
3. **Completeness verification:** how does the wizard confirm the transfer is complete before allowing the managed server deletion step?

## Decision

### 1. Pull-based transfer: self-hosted instance pulls from managed server

The self-hosted instance initiates and drives the transfer by requesting ciphertext files from the managed server via an authenticated export API. The managed server is a passive source; it does not push data or initiate connections to the self-hosted instance.

**Rejected alternative — Push-based transfer (managed server pushes to self-hosted instance):**
Requires the managed server to reach the self-hosted instance over the network. Most self-hosted instances are behind NAT or a firewall; establishing an inbound connection from an external server typically requires port forwarding or a relay, which adds setup steps for a non-technical user. Pull-based transfer requires only that the self-hosted instance can reach the managed server's HTTPS endpoint, which is standard outbound connectivity.

### 2. Server-to-server transfer over HTTPS (client orchestrates, does not relay data)

The transfer is server-to-server: the self-hosted instance makes authenticated HTTPS requests directly to the managed server's export API and stores the received ciphertext locally. The user's client application (mobile or desktop) orchestrates the wizard UI and monitors progress but does not relay file bytes — it issues the start command and polls for status.

The transfer must be resumable: the self-hosted instance records a per-file completion state so that a network interruption does not require restarting from zero.

**Rejected alternative — Client-mediated transfer (ciphertext transits user's device):**
The client downloads each encrypted file from the managed server and re-uploads it to the self-hosted instance. This works without any direct network path between the two servers and requires no new server-to-server API. Rejected because: (a) it is dramatically slower for large libraries — bytes travel managed→client→self-hosted instead of managed→self-hosted; (b) it requires the user's device to remain active for the full duration of a potentially multi-hour transfer; (c) it saturates the user's upload bandwidth, which is typically the bottleneck. Server-to-server is strictly better when a direct path exists, and direct outbound HTTPS is available in all target deployment environments.

### 3. Completeness verification: file count and random-sample decryption before deletion unlock

The migration wizard enforces a two-part completeness gate before the managed server deletion step becomes available:

- **File count match:** the self-hosted instance reports its received file count to the client; the managed server reports its source file count. The wizard compares these and blocks the deletion step if they do not match.
- **Random-sample decryption:** the client decrypts a random sample of 10 files from the self-hosted instance using the user's local key. All 10 must decrypt without error. This is performed client-side; no plaintext is sent anywhere.

Only after both checks pass does the wizard present the deletion confirmation screen. The user must then type an explicit acknowledgement before deletion proceeds. The managed server deletion is irreversible; the gate exists to make accidental data loss technically impossible, not merely unlikely.

After deletion completes, the managed server returns a deletion receipt (timestamp, file count deleted). The client stores this receipt on the self-hosted instance.

**Rejected alternative — File count only, no decryption sample:**
A count match confirms quantity but not integrity — silent corruption or truncation during transfer would not be caught. Adding the decryption sample catches integrity failures at negligible cost (10 files). The sample size is a balance between thoroughness and UX delay; it is not a statistical guarantee of full-library integrity, and the feature documentation must say so.

**Rejected alternative — Full library decryption verification before deletion:**
Decrypting every file before allowing deletion provides a stronger integrity guarantee but is impractical for large libraries (hours of client-side computation for a 500 GB library). The file count plus 10-file sample is accepted as sufficient for the stated use case. If a stronger guarantee is needed in future (e.g., for enterprise use), a background integrity check that runs after migration and before a configurable deletion delay would be the preferred approach.

## Consequences

- The managed server must implement an authenticated export API that supports: listing a user's files with their checksums, serving individual ciphertext files by ID, reporting total file count, and issuing a deletion receipt after deletion completes. This API is a new interface contract; its shape must be stable before the migration wizard ships.
- The self-hosted instance must implement: a resumable pull-transfer job, per-file completion state, file count reporting, and receipt storage. These are new capabilities that do not exist in the base self-hosted server.
- The server-to-server transfer requires an authenticated connection from the self-hosted instance to the managed server. The authentication mechanism (e.g., a time-limited migration token scoped to the user's account) must be designed to prevent one user from accessing another user's ciphertext. Token design is not specified here and should be addressed in implementation.
- Resumability means the transfer job must be idempotent: re-requesting a file that was already received must not corrupt the local copy. The self-hosted instance should verify the checksum of received files against the managed server's reported checksum before marking each file complete.
- The 10-file random-sample decryption check is a UX gate, not a cryptographic proof of full-library integrity. Documentation and the wizard UI must not describe it as a guarantee of complete integrity; it is a best-effort check against silent corruption in the common case.
- The deletion receipt stored on the self-hosted instance is a policy record, not a cryptographic proof of deletion. The managed hosting terms of service (FEAT-0005) must include a backup retention policy (e.g., backups purged within 30 days of account deletion) to close the gap between the receipt and actual unrecoverability.
