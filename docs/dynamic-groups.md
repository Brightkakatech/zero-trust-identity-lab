# Dynamic department and rollout ring groups

BrightKaka Tech: Zero Trust identity lab
Status: **11 dynamic groups created and verified on 2026-11-05.** The ring groups will be the targets for the Conditional Access rollout.

## Why dynamic groups

A normal (assigned) group only changes when someone edits it. People who move team or leave keep their memberships until somebody notices. A **dynamic group** has a rule, such as `user.department -eq "Finance"`, and Microsoft Entra ID adds and removes members automatically when a user's attributes change. In a company of hundreds or thousands, that is how group membership stays correct without manual work.

Dynamic membership needs Microsoft Entra ID P1, included in Microsoft 365 Business Premium.

## The groups

The definitions live in [data/dynamic-groups.json](../data/dynamic-groups.json) and are created by [scripts/New-LabDynamicGroups.ps1](../scripts/New-LabDynamicGroups.ps1). Changing a rule means editing one line, reviewed in Git and checked by tests.

| Group | Rule | Purpose |
|---|---|---|
| DYN-Dept-IT, Finance, HR, Sales, Marketing, Operations, Legal, Executive | `(user.department -eq "<department>")` | One group per department, for access to team resources |
| DYN-Ring0-IT | `(user.extensionAttribute1 -eq "Ring0")` | Rollout ring 0: gets every change first |
| DYN-Ring1-Pilot | `(user.extensionAttribute1 -eq "Ring1")` | Rollout ring 1: pilot users from every department |
| DYN-Ring2-Broad | `(user.extensionAttribute1 -eq "Ring2")` | Rollout ring 2: everyone else |

Naming rule: `DYN-Dept-Name` or `DYN-RingN-Name`, so anyone can tell from the name that membership is automatic and must not be edited by hand.

## Tests before the tenant

[tests/DynamicGroups.Tests.ps1](../tests/DynamicGroups.Tests.ps1) runs every rule against the synthetic user CSV before anything is created. It checks the naming rule, that every rule uses a supported format, that **no group would be empty** (which catches a typo such as "Finanse"), that every department has a group, and that every user lands in **exactly one** ring.

Result: 20 of 20 tests passed (8 for groups, 12 for the user data).

## Results

| Group | Members | Expected from the CSV | Difference |
|---|---|---|---|
| DYN-Dept-Executive | 4 | 4 | |
| DYN-Dept-Finance | 21 | 20 | Alice Murphy (test user, department Finance) |
| DYN-Dept-HR | 12 | 12 | |
| DYN-Dept-IT | 13 | 12 | HelpDesk (test user, department IT) |
| DYN-Dept-Legal | 6 | 6 | |
| DYN-Dept-Marketing | 18 | 18 | |
| DYN-Dept-Operations | 40 | 40 | |
| DYN-Dept-Sales | 39 | 38 | Bob Kelly (test user, department Sales) |
| DYN-Ring0-IT | 12 | 12 | |
| DYN-Ring1-Pilot | 18 | 18 | |
| DYN-Ring2-Broad | 120 | 120 | |

Evidence: [creation run](evidence/new-labdynamicgroups-run.txt), [member counts](evidence/dynamic-group-members.txt), [non-synthetic members](evidence/dynamic-group-non-synthetic-members.txt).

Every difference is explained: the three original test users already had a department, so the department rules included them. That is correct behaviour, and they stay in their department groups. None of them has a ring yet, which is why the ring groups match the CSV exactly. They are placed in rings before enforcement.

## What I learned

- **Dynamic groups fill in the background, not instantly.** Two minutes after creation, 5 groups were complete and 6 were still empty. All 11 were complete about ten minutes later, with "Dynamic rules processing status: Succeeded". A new dynamic group must never be used in a policy until its member count has been checked.
- **A rule matches everyone with the attribute, not only the users you had in mind.** Three groups had one more member than the data predicted. Checking counts against an expected number, then listing the members that were not expected, found the reason in minutes. In a real tenant, this check is what stops an unexpected person gaining access through a broad rule.
