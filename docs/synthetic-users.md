# Synthetic staff at scale

BrightKaka Tech: Zero Trust identity lab
Status: **150 synthetic users created on 2026-11-05.** Used for dynamic groups, rollout rings and impact reports.

## Why

Policies that work for three test users can still fail for a real company. Groups, rollout rings and impact reports only mean something with a realistic number of people across real departments and offices. So the lab tenant gets a fictional workforce of 150 staff, created by script rather than by hand.

## What was created

| Department | Staff | Pilot (Ring1) |
|---|---|---|
| IT | 12 | All in Ring0 |
| Finance | 20 | 3 |
| HR | 12 | 2 |
| Sales | 38 | 4 |
| Marketing | 18 | 3 |
| Operations | 40 | 4 |
| Legal | 6 | 1 |
| Executive | 4 | 1 |
| **Total** | **150** | **18** |

Offices: Dublin, Cork, Galway, Limerick and London. London staff have usage location GB, everyone else IE.

### Rollout rings

| Ring | Who | Size | Purpose |
|---|---|---|---|
| Ring0 | IT department | 12 | Gets every change first. IT can fix what breaks. |
| Ring1 | Pilot volunteers, at least one per department | 18 (12%) | Finds problems that only appear in a particular team's work |
| Ring2 | Everyone else | 120 | Gets the change once Ring0 and Ring1 are stable |

The ring is stored in `extensionAttribute1` on each user, so dynamic groups can build the rings automatically.

## Safety design

| Decision | Reason |
|---|---|
| Every account is **disabled** | Nobody signs in as these users. A disabled account cannot be attacked. |
| 32 character random password, never shown or saved | Nobody needs it |
| Labelled synthetic in three places: company name "BrightKaka Tech (synthetic)", employee type "Synthetic", employee ID starting SYN | They can never be mistaken for real staff |
| `Remove-LabUsers.ps1` checks **all three** labels before deleting each user | A real account cannot be deleted by mistake, even if someone copies the company name |
| No licences assigned | Groups and rings do not need licences, and trial licences stay free for real test users |
| Script asks only for `User.ReadWrite.All` | Least privilege |
| Data is tested before it reaches the tenant | 12 Pester tests check uniqueness, labels, departments, rings and usage location |

## How it was run

```powershell
# 1. Check the data (no tenant needed)
Invoke-Pester -Path ./tests -Output Detailed

# 2. Preview: shows every user that would be created, changes nothing
./scripts/New-LabUsers.ps1 -Domain <tenant>.onmicrosoft.com -WhatIf

# 3. Sign in with one permission, then create
Connect-MgGraph -Scopes User.ReadWrite.All -NoWelcome
./scripts/New-LabUsers.ps1 -Domain <tenant>.onmicrosoft.com

# Teardown at the end of the project
./scripts/Remove-LabUsers.ps1 -WhatIf
./scripts/Remove-LabUsers.ps1
```

The data file is produced by `scripts/New-SyntheticUserData.ps1` with a fixed seed, so it can be rebuilt exactly.

## Results

| Check | Result | Evidence |
|---|---|---|
| Data tests | 12 passed, 0 failed | [pester-synthetic-users.txt](evidence/pester-synthetic-users.txt) |
| Dry run | 150 users previewed, 0 created | |
| Real run | Created 150, failed 0 | [new-labusers-run.txt](evidence/new-labusers-run.txt) |
| Count in tenant | 150 users with company name "BrightKaka Tech (synthetic)" | |
| Spot check (SYN1001) | IT, IT Manager, London, GB, Synthetic, disabled, Ring0, all as in the CSV | |
| Second run | Created 0, skipped 150 | [new-labusers-rerun.txt](evidence/new-labusers-rerun.txt) |

The second run proves the script is **idempotent**: running it again does not create duplicates, so it is safe to rerun after a partial failure.

## What broke and what I learned

- **Windows PowerShell 5.1 and PowerShell 7 keep modules separately.** Pester 5 and the Graph modules had to be installed again for PowerShell 7, and running Invoke-Pester before importing Pester 5 loaded the old built in Pester 3.4.
- **Downloaded scripts were blocked by the RemoteSigned execution policy** because Windows marks files from the internet. The fix was `Unblock-File` on the reviewed files, not lowering the execution policy for the whole machine.
- **Device code sign-in was blocked by Security Defaults (error 530035).** Device code flow is a common phishing technique, so the tenant treated it as unsafe. A normal interactive sign-in worked. Blocking device code flow deliberately with a Conditional Access policy is a candidate for a later policy.
