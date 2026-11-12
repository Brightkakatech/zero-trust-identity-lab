# CHG-002: Extend CA01 and CA04 to all users

| Field | Value |
|---|---|
| Change ID | CHG-002 |
| Type | Normal change |
| Requested and approved by | Bright Amalahu (lab: one person holds both roles) |
| Date | 2026-11-11 |
| Depends on | [CHG-001](CHG-001-enforce-conditional-access-ring0-ring1.md), verified successful |
| Rollback time | Under 5 minutes |

## What changes

| Policy | Before | After |
|---|---|---|
| CA01 Require MFA for all users | On for DYN-Ring0-IT and DYN-Ring1-Pilot | On for **All users**, break-glass excluded |
| CA04 Block sign-in from outside Ireland and the UK | On for DYN-Ring0-IT and DYN-Ring1-Pilot | On for **All users**, break-glass excluded |
| CA02, CA03 | Unchanged (already all users / admin roles) | Unchanged |

**Why "All users" and not DYN-Ring2-Broad:** the target state is that every account is covered, including accounts that will never be in a ring group, such as new starters before their attributes are set. Scoping to the three ring groups would leave anyone without a ring unprotected. Ring 2 is how the rollout was staged, not how the policy should stay.

## Evidence for the decision

- **Ring 0 and Ring 1 ran enforced for two days with no issues.** CHG-001 verification passed: MFA prompt from Ireland, block from the United States, break-glass unaffected.
- **Impact report for DYN-Ring2-Broad:** see [ca-impact-report-ring2.md](../evidence/ca-impact-report-ring2.md).
- Report-only since 2026-11-01: 10 days, above the 7 day minimum enforced by CI.

## Risk

| Risk | Mitigation |
|---|---|
| Users without MFA registered are stopped at their next sign-in | Impact report lists every enabled user without MFA before the change |
| Lockout | Break-glass accounts excluded from every policy, monitored and tested on 2026-11-11 |

## Implementation steps

1. Run the impact report against DYN-Ring2-Broad and confirm the decision.
2. Update `policies/rollout-approvals.json` (CA01 and CA04 now reference CHG-002).
3. In the portal, change CA01 and CA04 Include to **All users**. Check the break-glass exclusion is still there.
4. Export the policies, run the guardrail tests, commit and push. CI must pass.

## Verification

Carried out on 2026-11-12 (UTC) after the change.

| Test | Expected | Result | Evidence |
|---|---|---|---|
| Impact report for DYN-Ring2-Broad | GO | **GO**: 74 interactive sign-ins read, every enabled user in the ring has MFA registered | [ca-impact-report-ring2.md](../evidence/ca-impact-report-ring2.md) |
| Exported CA01 and CA04 | Include "All", no ring groups, break-glass excluded | **Passed**: both include "All", no DYN-Ring groups remain, group:CA-Exclude-BreakGlass excluded | [CA01.json](../../policies/CA01.json), [CA04.json](../../policies/CA04.json) |
| Guardrail tests | All pass, approvals checked against CHG-002 | **Passed**: 62 passed, 0 failed, 3 skipped | CI on the commit |

**Outcome: change successful.** No rollback needed. CA01 to CA04 now cover every account in the tenant except the two monitored break-glass accounts.

## Rollback

Set CA01 and CA04 Include back to DYN-Ring0-IT and DYN-Ring1-Pilot, or to Report-only.
