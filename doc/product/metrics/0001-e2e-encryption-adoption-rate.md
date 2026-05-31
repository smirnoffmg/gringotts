---
id: MET-0001
status: accepted
---
# E2E Encryption Adoption Rate

## Definition

The percentage of active users who have successfully configured client-side, user-held end-to-end encryption for their primary personal data store (photos and/or files), such that the service operator cannot decrypt stored content.

## Rationale

This metric directly measures whether the custody dimension of HYP-0001 is addressed. If users hold their own keys, provider-compelled disclosure and behavioral profiling of stored content are structurally prevented. Adoption rate determines whether the solution reaches meaningful scale.

## Measurement

- **Numerator:** Count of users with at least one active E2E-encrypted storage vault (user-generated key, not escrowed with the service).
- **Denominator:** Count of all active users with at least one file stored.
- **Frequency:** Monthly snapshot, reported as 30-day trailing average.
- **Source:** Client telemetry (key creation and vault activation events); server cannot verify content, only presence of encrypted blob headers.

## Thresholds

| Level      | Value  | Meaning                                                        |
| ---------- | ------ | -------------------------------------------------------------- |
| Baseline   | 0%     | No users have configured E2E encryption                        |
| Minimum    | 20%    | Solution is being adopted but hasn't crossed mainstream use    |
| Target     | 60%    | Majority of active users hold their own keys                   |
| Aspirational | 80%  | E2E encryption is the effective default for the user base      |
