# Access review: Project-Team

BrightKaka Tech: Zero Trust identity lab
Status: **First quarterly review completed on 2026-11-09.** Auto-apply stalled, so the reviewer's decision was enforced manually and the gap recorded.

## The problem access reviews solve

People collect access over time. Someone joins a team to help with one task, the task ends, and nobody removes them. An **access review** asks a responsible person, on a schedule, to confirm for every member: does this person still need this? Members marked **Deny** are removed. Auditors (ISO 27001, SOC 2) ask for exactly this evidence.

Access reviews need Microsoft Entra ID P2 (or ID Governance). A 30 day P2 trial was used, see [pim-setup.md](pim-setup.md).

## The scenario

| Item | Value |
|---|---|
| Group | **Project-Team** (Microsoft 365 group, assigned membership) |
| Members before the review | Alice Murphy, Bob Kelly, HelpDesk |
| Story | HelpDesk was added to help with a setup task (ticket INC-001). The task is finished, so he no longer needs access. |
| Owner and reviewer | Admin, acting as the project manager |

## Review design

| Setting | Value | Why |
|---|---|---|
| Reviewers | **Group owner(s)**, with Admin as fallback | Scales: in a company with hundreds of groups, each owner reviews their own group instead of one overloaded admin |
| Duration | 3 days | Time for reviewers to respond |
| Recurrence | Quarterly, no end date | Matches the group description "Membership reviewed quarterly" |
| Auto apply results | On | Denied members should be removed with no manual step |
| If reviewers don't respond | No change | Nobody loses access just because a reviewer forgot |
| Decision helper | No sign-in within 30 days | Gives the reviewer a recommendation based on real activity |
| Justification required | On | Every decision is explained in the audit trail |
| Notifications and reminders | On, with a summary to Admin at the end | |

**Licensing note:** from 15 January 2026, ID Governance features used **on guest users** need a linked Azure subscription and are billed per guest. Project-Team has no guests, so this review was not affected, but a company reviewing external users must budget for it.

## The decisions

The reviewer used **My Access** (myaccess.microsoft.com), the same page a manager or group owner uses in a real company.

| Member | System recommendation | Decision | Reason |
|---|---|---|---|
| Alice Murphy | Approve (signed in within 30 days) | **Approved** | Active project member |
| Bob Kelly | Approve (signed in within 30 days) | **Approved** | Active project member |
| HelpDesk | Approve (signed in within 30 days) | **Denied** | Task completed, access no longer needed |

All three decisions were made by Admin on 2026-11-03.

**The human override is the point of the review.** The system recommended approving HelpDesk because he had signed in recently. Activity only shows that an account is used, not that it still needs this access. The reviewer knew the business context and denied it. The page also offers an "Accept recommendations" button, which would have approved all three in one click and left the unneeded access in place.

## What happened next

| Date (UTC) | Event | Evidence |
|---|---|---|
| 2026-11-03 | Review created, three decisions recorded | Results page: 2 approved, 1 denied, 0 not reviewed |
| 2026-11-04 02:56 | Review stopped early by Admin. Audit log: "Access review ended" | Audit log |
| 2026-11-04 04:44 | Audit log: three "Decision Item Summary" entries, the decisions were processed | Audit log |
| 2026-11-04 to 2026-11-09 | Review status stuck on **Applying**. Apply button greyed out. No "Remove member from group" entry in the audit log. | Review history |
| 2026-11-09 | Members checked after the review end date (6 Nov): **HelpDesk still a member** | [project-team-members-after-review.txt](evidence/project-team-members-after-review.txt) |
| 2026-11-09 | HelpDesk removed manually through Microsoft Graph, enforcing the reviewer's decision | [project-team-members-after-manual-removal.txt](evidence/project-team-members-after-manual-removal.txt) |

The manual removal used only the permission it needed:

```powershell
Connect-MgGraph -Scopes GroupMember.ReadWrite.All, Directory.Read.All -NoWelcome
$team = Get-MgGroup -Filter "displayName eq 'Project-Team'"
$helpdesk = Get-MgUser -UserId "helpdesk@<tenant>.onmicrosoft.com"
Remove-MgGroupMemberDirectoryObjectByRef -GroupId $team.Id -DirectoryObjectId $helpdesk.Id
```

Members after the removal: Alice Murphy, Bob Kelly.

## Findings

- **A recorded decision is not the same as an enforced decision.** The review showed "1 denied", but for six days HelpDesk kept his access, and the portal gave no warning beyond the status "Applying". Without checking the group itself, the review would have been reported as complete while the access it was meant to remove was still in place. This is exactly the kind of gap an auditor looks for.
- **Always verify the outcome, not the status.** The check that found the problem was simple: list the group's members after the review's end date and compare with the decisions. In production this would be a scheduled script that compares access review decisions with actual group membership and alerts on any difference.
- **Stopping a review early may have contributed.** The review was stopped about a day after it started, instead of being left to end on its own. A likely cause is that applying results after an early stop did not complete. The next quarterly instance will be left to end naturally to confirm whether auto-apply works without intervention.
- **The manual fix kept the audit trail.** The removal was done with a narrow permission (`GroupMember.ReadWrite.All`), the before and after membership lists were saved, and the reason is recorded here: enforcing the reviewer's denial after auto-apply stalled.
