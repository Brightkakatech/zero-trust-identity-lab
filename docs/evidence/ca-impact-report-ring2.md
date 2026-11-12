# Conditional Access impact report

Generated: 2026-11-11 23:44 UTC. Sign-in window: last 7 days. Target ring: **DYN-Ring2-Broad**.

## 1. What the report-only policies did

Interactive sign-ins read: 74.

| Policy | Evaluated | Would succeed | Would interrupt | Would block | Not applied | Users interrupted or blocked |
|---|---|---|---|---|---|---|
| CA01 Require MFA for all users | 28 | 26 | 2 | 0 | 0 | Admin |
| CA02 Block legacy authentication | 28 | 0 | 0 | 0 | 28 | None |
| CA03 Require MFA for admins | 28 | 26 | 2 | 0 | 0 | Admin |
| CA04 Block sign-in from outside Ireland and the UK | 28 | 0 | 0 | 0 | 28 | None |

## 2. Is the target ring ready?

| Members | Enabled | Enabled with MFA registered | Enabled without MFA | Disabled (no sign-in, no impact) |
|---|---|---|---|---|
| 120 | 0 | 0 | 0 | 120 |

**Decision: GO: every enabled user in the ring has MFA registered.**
