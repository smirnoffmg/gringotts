---
id: MET-0002
status: accepted
---
# Self-Hosted Primary Adoption Rate

## Definition

The percentage of active users whose authoritative copy of their primary personal data store (photos and/or files) resides on user-controlled hardware, with any big-tech cloud demoted to an optional, replaceable replica rather than the source of truth.

## Rationale

This metric directly measures whether the access and terms-stability dimensions of HYP-0001 are addressed. If the authoritative copy lives on hardware the user controls, provider termination (Evidence §2) cannot revoke access to the data, and unilateral pricing or terms changes (Evidence §6) affect only a replica the user can drop or swap without loss. Adoption rate determines whether the solution reaches meaningful scale — a self-hosted model that only experts can stand up does not move the dimension for the typical user the problem statement targets.

## Measurement

- **Numerator:** Count of users whose primary store is configured as local-primary (authoritative copy on user-controlled hardware), independent of whether any cloud replica is also configured.
- **Denominator:** Count of all active users with at least one file stored.
- **Frequency:** Monthly snapshot, reported as 30-day trailing average.
- **Source:** Client and primary-store telemetry (primary-store provisioning and authoritative-write events). A user is counted only while the primary store has reported a successful authoritative write within the trailing window — configuration alone, without active use, does not qualify.

## Thresholds

| Level        | Value | Meaning                                                        |
| ------------ | ----- | -------------------------------------------------------------- |
| Baseline     | 0%    | No users have a user-controlled authoritative copy             |
| Minimum      | 15%   | Solution is being adopted but hasn't crossed mainstream use    |
| Target       | 50%   | Majority of active users hold their own authoritative copy     |
| Aspirational | 70%   | Self-hosted primary is the effective default for the user base |
