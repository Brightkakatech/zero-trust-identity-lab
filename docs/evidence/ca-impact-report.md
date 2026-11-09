# Conditional Access impact report

Generated: 2026-11-09 14:55 UTC. Sign-in window: last 7 days. Target ring: **DYN-Ring1-Pilot**.

## 1. What the report-only policies did

Interactive sign-ins read: 67.

| Policy | Evaluated | Would succeed | Would interrupt | Would block | Not applied | Users interrupted or blocked |
|---|---|---|---|---|---|---|
| CA01 Require MFA for all users | 58 | 50 | 8 | 0 | 0 | Admin, Bob Kelly, HelpDesk |
| CA02 Block legacy authentication | 58 | 0 | 0 | 0 | 58 | None |
| CA03 Require MFA for admins | 58 | 43 | 2 | 0 | 13 | Admin |
| CA04 Block sign-in from outside Ireland and the UK | 58 | 0 | 0 | 0 | 58 | None |

## 2. Is the target ring ready?

| Members | Enabled | Enabled with MFA registered | Enabled without MFA | Disabled (no sign-in, no impact) |
|---|---|---|---|---|
| 20 | 2 | 2 | 0 | 18 |

**Decision: GO: every enabled user in the ring has MFA registered.**
