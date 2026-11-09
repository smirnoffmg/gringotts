---
id: MET-0003
status: proposed
problem_hypothesis_id: PROB-0001
---

# Perceived Data Control Score

## Context

PROB-0001 documents a gap between what big-tech cloud platforms structurally permit and what users believe about their own control. Disconfirmation D2 notes that most users have never experienced a loss-of-control incident, and D3 notes that sophisticated users can already opt out. The population that suffers most is non-expert consumers who hold an inaccurate mental model. Any solution that improves structural control without also closing the perception gap may leave users no better equipped to defend themselves in the future, or to evaluate whether the new solution genuinely serves them. This metric measures whether users of the solution correctly understand who controls their data and what would happen in adverse scenarios.

## Decision

**Perceived Data Control Score (PDCS)** = a composite 0–100 score derived from a four-question in-app survey presented at onboarding completion and repeated at 90-day intervals:

| Q#  | Question                                                                       | Correct answer (scores 25 pts)                       |
| --- | ------------------------------------------------------------------------------ | ---------------------------------------------------- |
| 1   | Who holds the encryption key for your stored files?                            | "Only I do" / "My device"                            |
| 2   | If your account were suspended today, what would happen to your files?         | Accurate description of local/export copy retention  |
| 3   | Can [product name] or any government agency read your stored files?            | "No — files are encrypted with a key only I hold"    |
| 4   | If you stop using this service, how do you get your files into another system? | Accurate description of export flow and open formats |

A PDCS of 100 = the user correctly understands all four dimensions. A PDCS < 50 = the user holds materially inaccurate beliefs about their own control, regardless of the structural protections in place.

Target: **median PDCS ≥ 80** across active users at 90 days post-onboarding.

## How we measure

- **Data source:** In-app survey (4 multiple-choice questions, presented non-intrusively via a "How well do you know your data?" prompt). Responses stored per user, linked to cohort and onboarding date.
- **Query:** Median PDCS per monthly cohort at T+90 days, trended over time.
- **Benchmarking:** Administer the same four questions to a control group of current Google Photos / iCloud users (recruited via user research panel) to establish a baseline PDCS for the problem population; target is the solution population median exceeds the control group median by ≥ 30 points.
- **Instrumentation required:** In-app survey component with answer-scoring logic; response events written to analytics pipeline with user pseudonym and cohort ID.

## Consequences

**What this makes easy to optimise for:** Onboarding clarity, in-product education, and UI copy that accurately represents the security model. Teams will be incentivised to make the E2E encryption and export capabilities legible to non-expert users, not just technically present.

**What this makes easy to game or ignore:** The PDCS measures _stated_ beliefs in a low-stakes survey context, not actual comprehension or behaviour under stress. A user could answer correctly at T+90 and still panic and make poor decisions during an account recovery event. High PDCS also does not guarantee users will act on that knowledge (e.g., set up a secondary backup). The metric is a leading indicator of informed use, not a guarantee of it. Survey fatigue and self-selection (engaged users are more likely to respond) may inflate the median; response rate should be tracked alongside PDCS.
