---
id: SOL-0002
status: proposed
metric_ids:
  - MET-0002
  - MET-0003
---

# Cloud Control Audit and Continuous Export Assistant

## Context

PROB-0001 identifies a perception gap as well as a structural control gap: non-expert users hold an inaccurate mental model of who controls their data, and existing export tools are too cumbersome for most people to use. SOL-0001 addresses the problem structurally by replacing the big-tech platform. This solution addresses a different question: **for users unwilling or unable to migrate, can partial control be meaningfully restored without leaving the existing platform?**

This hypothesis is the minimal-intervention option. It works within the current provider relationship rather than replacing it, making it maximally reversible — a user can install it, benefit from it, and uninstall it without touching their primary cloud library. It is appropriate as a standalone product for a segment of the target persona (those who accept the structural tradeoffs of big-tech but want to understand and mitigate the risks they can mitigate), and as a lower-friction entry point that can funnel users toward SOL-0001 once they have experienced a "control audit moment."

**Why this approach over alternatives:**

_Alternative — Do nothing / public awareness campaign (rejected):_ Publish documentation about the control-loss mechanisms and let users make their own decisions. This has zero ongoing product risk but zero measurable impact on any of the five control dimensions. Rejected because it produces no measurable improvement in MET-0002 or MET-0003.

_Alternative — Lobby providers to change defaults (rejected as primary):_ Engage with providers or regulators to mandate E2E-by-default and pre-termination export windows. This could produce systemic change (the disconfirmation D1 analysis shows this is already happening at the margin) but is not within a product team's control, operates on a multi-year timeline, and does not help users today. Retained as a complementary external-affairs activity, not a product solution.

_Chosen approach:_ A lightweight desktop/mobile application that:

1. Audits the user's current cloud storage settings and surfaces concrete, actionable control gaps with one-click remediation where possible
2. Runs a continuous, incremental export of the user's cloud library to a local drive or user-specified destination (NAS, external disk, second cloud provider), normalising metadata to open standards in the process

This does not change who holds the encryption keys or who governs the ToS. It directly addresses the Portability dimension (giving users an always-current local copy) and the perception gap (via the audit report). It partially addresses the Access dimension (a local copy survives account termination). It is honest about what it cannot fix.

## Decision

Build a desktop-first (macOS, Windows) application with the following mechanisms:

**1. Control audit report**
At first launch, the app connects to the user's Google, Apple, and/or Microsoft account via official APIs and OAuth. It checks:

- Whether E2E / Advanced Data Protection is enabled (where available)
- Whether the user has an active, recent export on file
- Whether the account has an active recovery method (phone/email)
- What the current ToS data-use clauses say about content scanning and licensing (pulled from a maintained plain-language translation database)

The result is a one-page "Your Cloud Control Score" report with a letter grade (A–F) per control dimension and one-click links to enable available protections (e.g., "Enable iCloud Advanced Data Protection →").

**2. Continuous incremental export**
After the audit, the app offers to set up a background sync job that:

- Uses the provider's official export APIs (Google Photos Library API, iCloud PhotoKit via local macOS Photos library, OneDrive Graph API) to pull any new or modified files since the last sync
- Embeds sidecar metadata into EXIF/XMP fields using the same normalisation pipeline as SOL-0001's migration assistant
- Writes files to a user-specified destination: local folder, external drive, or a self-hosted instance (if the user also runs SOL-0001)

The export runs automatically in the background, daily by default, and is incremental — only new and changed files are processed. The user always has an up-to-date local copy.

**3. Honest limitation disclosure**
The app explicitly communicates what it cannot fix: provider key custody, ToS changes, content scanning of existing cloud copies, and compelled government disclosure of provider-held data. For each unfixable limitation, it surfaces an educational one-liner and a link to learn about SOL-0001 as the structural alternative.

## Experiments

**Experiment 1 — Audit report comprehension and action rate (usability test)**

- _Action:_ Recruit 10 non-technical users currently on Google Photos or iCloud. Show them a static mock-up of the "Your Cloud Control Score" report for their (actual or representative) account. Measure: (a) can they correctly interpret their grade on each dimension without explanation? (b) do they click any remediation link?
- _Pass criterion:_ ≥ 8 of 10 correctly interpret all four dimension grades without prompting; ≥ 5 of 10 click at least one remediation link within 3 minutes.
- _Fail criterion:_ Fewer than 7 interpret correctly → the report language or grade metaphor must be redesigned. Fewer than 4 click a remediation link → the report is informative but not motivating; consider redesigning CTA framing.

**Experiment 2 — Continuous export reliability test (technical spike)**

- _Action:_ Run the incremental export agent against a live 5,000-photo Google Photos library for 30 days. Measure: files missed per sync cycle, metadata embedding accuracy (exiftool diff), and CPU/network overhead on a mid-range laptop.
- _Pass criterion:_ Zero files missed across 30 days of incremental sync; metadata embedding accuracy ≥ 99.5% of files; background CPU usage < 5% average on a 2020-era laptop.
- _Fail criterion:_ Any missed files attributable to application logic (not API rate limits); metadata accuracy < 99%; CPU > 10% average → indicates the sync agent needs architectural work before it can run invisibly in the background.

**Experiment 3 — Willingness to grant OAuth access (survey + prototype)**

- _Action:_ Present the OAuth permission screen (read-only access to Google Photos / iCloud) to 20 non-technical users in the target persona, with a one-sentence explanation of why access is needed. Measure: what percentage approve access?
- _Pass criterion:_ ≥ 14 of 20 (70%) approve OAuth access after reading the explanation.
- _Fail criterion:_ Fewer than 14 approve → trust is the primary barrier, not feature value; the app must invest heavily in trust-building UX (open-source audit, privacy policy plain-language, etc.) before launch.

## Success criteria

Measured at 6 months post-general-availability:

| Metric                                    | Target                                                                                                                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| MET-0002: Successful Portable Export Rate | ≥ 95% of incremental sync cycles complete with zero missed files and open-standard metadata embedded                                                         |
| MET-0003: Perceived Data Control Score    | Median PDCS ≥ 75 at T+90 days post-onboarding (slightly lower than SOL-0001 target, because structural gaps remain and the audit communicates them honestly) |
| Audit remediation action rate             | ≥ 40% of users who view the audit report take at least one recommended remediation action within 7 days                                                      |
| Export destination setup rate             | ≥ 60% of users who complete onboarding configure and successfully complete a first continuous export within 14 days                                          |
| 90-day retention                          | ≥ 50% of users who set up continuous export have had a successful sync in the past 7 days at T+90                                                            |

## Consequences

**Tradeoffs and risks:**

- **This solution does not fix the structural problem.** Provider key custody, ToS instability, content scanning, and compelled disclosure remain entirely in place. A user who relies on this solution is better informed and has a local copy of their data, but is not structurally more in control. The "honest limitation disclosure" mechanism is essential — if users believe this tool has solved the custody problem, it creates false confidence that could be worse than the status quo. The gap between MET-0003 target (75) and the full solution target (80) reflects this intentional limitation.

- **API dependency creates fragility.** Continuous export depends on Google, Apple, and Microsoft APIs that are owned by the same providers the solution critiques. API deprecation, rate limiting, or OAuth scope changes could break the core feature at any time with no recourse. This is an inherent limitation of staying within the provider ecosystem. Mitigation: design the sync agent to degrade gracefully (pause, notify, resume) rather than silently fail.

- **This solution is reversible but shallow.** A user can uninstall the app with zero disruption to their primary library. This is a feature, not a bug — it is why this solution is positioned as the minimal-intervention option. But it also means its impact on the structural control-loss dimensions (Custody, Terms Stability, Disclosure Boundary) is zero. It should be evaluated against what it claims to improve (Portability, perception gap), not against what SOL-0001 achieves structurally.

- **Funnel to SOL-0001 must be authentic, not coercive.** The "honest limitation disclosure" section will surface SOL-0001 as a structural alternative. This must be presented as information, not upselling. If users feel manipulated into a more complex product, trust in both solutions is damaged.

**Follow-up work introduced:**

- Maintain a plain-language ToS translation database across major providers (ongoing editorial effort)
- Monitor provider API changes and deprecation notices (ongoing operational risk)
- Instrument funnel from SOL-0002 audit report to SOL-0001 trial to understand conversion rate and persona overlap
- Evaluate whether the audit report alone (without export) has measurable PDCS impact — this could become a standalone free-tier feature to drive acquisition
