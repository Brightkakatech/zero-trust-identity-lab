# Zero Trust Identity Lab: Conditional Access, PIM and Access Reviews

> **Status: in progress.** This README is filled in as the project is built.

![Tests](https://github.com/Brightkakatech/zero-trust-identity-lab/actions/workflows/test.yml/badge.svg)

## Summary

BrightKaka Tech is a fictional company used for my labs. This project secures sign-ins to its Microsoft 365 tenant using Zero Trust principles: verify every sign-in, give admins power only when they need it, and regularly check who still needs access.

It replaces Security Defaults (used in my [hybrid AD lab](https://github.com/Brightkakatech/hybrid-ad-homelab)) with:

- **Conditional Access** policies, each tested in report-only mode before being enforced
- **Privileged Identity Management (PIM)** for just-in-time admin access
- **Access reviews** so group owners confirm who keeps access
- **Break-glass accounts** and a lockout recovery plan

## Architecture

![Architecture diagram](docs/diagrams/architecture.png)

## What you need

| Item | Detail |
|---|---|
| Licences | Microsoft Entra ID P1 (Conditional Access), Entra ID P2 (PIM, access reviews). Used here through a Microsoft 365 Business Premium trial and an Entra ID P2 trial. |
| Tools | A browser, PowerShell 7, Microsoft Graph PowerShell SDK |
| Cost | Free (trial licences) |

## Policy design

The full plan, with the reason for each policy and every test case, is in [docs/ca-policy-plan.md](docs/ca-policy-plan.md).

| ID | Policy | Grant |
|---|---|---|
| CA01 | Require MFA for all users | Require MFA |
| CA02 | Block legacy authentication | Block |
| CA03 | Require MFA for admins | Require MFA |
| CA04 | Block sign-in from outside Ireland and the UK | Block |
| CA05 | Require compliant device | Require compliant device |

## How it was built

_Step-by-step setup, written as each stage is completed._

## Results

_Screenshots and report-only results, added during testing._

## What broke and what I learned

_Added during the build._

## Teardown

_Added at the end._

## Next steps

_Added at the end._

## Repository layout

```
README.md
data/
  synthetic-users.csv    150 fictional staff, departments and rollout rings
  dynamic-groups.json    department and ring group rules (configuration as code)
docs/
  ca-policy-plan.md      policy design, test cases, rollout record
  pim-setup.md           just in time admin access with PIM
  access-review.md       quarterly access review: decisions, stalled auto-apply, manual enforcement
  synthetic-users.md     the synthetic workforce: design, safety, results
  dynamic-groups.md      dynamic department and rollout ring groups
  policies-as-code.md    policy export, CI guardrails and the pull request proof
  demos/                 short recordings of key moments
  evidence/              test and script output
  diagrams/              architecture diagram
  screenshots/           evidence for each stage
policies/
  CA01.json ... CA04.json     exported Conditional Access policies (sanitised)
  rollout-approvals.json      approvals required before a policy can be switched On
scripts/
  New-SyntheticUserData.ps1   builds the CSV (fixed seed, reproducible)
  New-LabUsers.ps1            creates the users through Microsoft Graph
  Remove-LabUsers.ps1         deletes only users carrying all synthetic labels
  New-LabDynamicGroups.ps1    creates the dynamic groups from the JSON
  Export-CAPolicies.ps1       exports the policies as sanitised JSON (read only)
tests/
  SyntheticUsers.Tests.ps1    Pester checks on the data before it reaches the tenant
  DynamicGroups.Tests.ps1     runs every group rule against the data before it is created
  ConditionalAccess.Tests.ps1 guardrails every policy must pass (break-glass excluded, approvals)
.github/workflows/
  test.yml                    style check and all tests on every push and pull request
```

## Author

Bright Amalahu, Systems Administrator
[LinkedIn](https://www.linkedin.com/in/bright-amalahu/) · [Medium](https://medium.com/@brightkakatech) · [GitHub](https://github.com/Brightkakatech)
