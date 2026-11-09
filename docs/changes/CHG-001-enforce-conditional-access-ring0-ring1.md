# CHG-001: Enforce Conditional Access for Ring 0 and Ring 1

| Field | Value |
|---|---|
| Change ID | CHG-001 |
| Type | Normal change |
| Requested and approved by | Bright Amalahu (lab: one person holds both roles, see limitations) |
| Planned date | 2026-11-09 |
| Systems | Microsoft Entra ID tenant (lab), Conditional Access policies CA01 to CA04, Security Defaults |
| Rollback time | Under 5 minutes |

## What changes

| Policy | Before | After | Scope after the change | Reason for the scope |
|---|---|---|---|---|
| CA01 Require MFA for all users | Report-only, all users | **On** | DYN-Ring0-IT and DYN-Ring1-Pilot, break-glass excluded | Staged rollout: IT first, then pilot users, then everyone in a later change |
| CA02 Block legacy authentication | Report-only, all users | **On** | All users, break-glass excluded | Zero legacy sign-ins in 7 days, so no one is affected and there is no reason to stage it |
| CA03 Require MFA for admins | Report-only, admin roles | **On** | Admin directory roles, break-glass excluded | Every account holding an admin role is already in Ring 0 |
| CA04 Block sign-in from outside Ireland and the UK | Report-only, all users | **On** | DYN-Ring0-IT and DYN-Ring1-Pilot, break-glass excluded | Staged rollout, same as CA01 |
| Security Defaults | On | **Off** | Tenant | Required by Microsoft before any Conditional Access policy can be On |

## Evidence for the decision

From the [impact report](../evidence/ca-impact-report.md), generated 2026-11-09 over 7 days and 67 interactive sign-ins:

| Policy | Would interrupt | Would block | Reading |
|---|---|---|---|
| CA01 | 8 (Admin, Bob Kelly, HelpDesk) | 0 | Interruptions are MFA prompts, which is the policy working as intended. No one would be blocked. |
| CA02 | 0 | 0 | No legacy authentication in use |
| CA03 | 2 (Admin) | 0 | MFA prompts for an admin, as intended |
| CA04 | 0 | 0 | Every sign-in came from Ireland |

Ring readiness for DYN-Ring1-Pilot: 20 members, 2 enabled, **both with MFA registered**, 18 disabled synthetic accounts with no sign-in. Decision: **GO**.

Every policy has been in report-only mode since 2026-11-01, **8 days**, above the 7 day minimum enforced by the CI guardrail test.

## Risk

| Risk | Likelihood | Mitigation |
|---|---|---|
| Admins locked out | Low | Break-glass accounts excluded from every policy, tested, with passkeys. Admin keeps a signed-in session during the change. |
| Gap in protection for users outside the rings when Security Defaults is switched off | Low in the lab | Users outside Ring 0 and Ring 1 are the 120 disabled synthetic accounts in Ring 2, which cannot sign in. In production, Ring 2 would be scheduled within days, or the change would keep a baseline MFA policy for all users. |
| A user travelling abroad is blocked by CA04 | Low | Only pilot users are in scope, and they were told about the change |

## Implementation steps

1. Confirm the impact report decision is GO.
2. Add the four approvals to `policies/rollout-approvals.json` with reference CHG-001.
3. In the portal, set the scope of CA01 and CA04 to DYN-Ring0-IT and DYN-Ring1-Pilot.
4. Turn off Security Defaults.
5. Switch CA01 to CA04 to **On**.
6. Export the policies, run the guardrail tests, commit and push. CI must pass.

## Verification

Carried out on 2026-11-09 after all four policies were switched On.

| Test | Expected | Result | Evidence |
|---|---|---|---|
| Alice (Ring 1) signs in from Ireland | MFA prompt, then access | **Passed.** "Approve sign in request" with number matching, then Microsoft 365 home | [Recording 3](../demos/03-ca01-mfa-prompt.gif) |
| Alice signs in through a VPN in the United States | Blocked by CA04 | **Passed.** "You cannot access this right now", error 53003. Sign-in log: CA04 Failure (block), CA01 Failure, CA02 and CA03 Not applied | [Recording 4](../demos/04-ca04-vpn-blocked.gif) |
| CI guardrails after the change | All pass, approvals checked | **Passed.** 62 passed, 0 failed, 3 skipped. The approval test ran for all four policies instead of being skipped | [pester-after-enforcement.txt](../evidence/pester-after-enforcement.txt) |
| breakglass01 signs in | No policy applies | Pending, covered by the break-glass monitoring work | |

**Why CA01 also shows Failure on the blocked sign-in:** Alice was never prompted for MFA. When any policy blocks, Entra ID stops evaluating and does not ask for MFA, because the result cannot change. CA01's requirement was therefore never met. This is "block always wins", first seen in the What If test, now confirmed on a real sign-in.

**Outcome: change successful.** No rollback needed.

## Rollback

Set the affected policy back to **Report-only**. If an admin cannot sign in, use breakglass01. If several policies cause problems, set all four to Report-only and turn Security Defaults back on.

## Limitations

- In a company, the requester and the approver would be different people, and the approval would be recorded in a change management system. In this lab, one person holds both roles.
