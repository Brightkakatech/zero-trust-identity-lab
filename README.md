# Zero Trust Identity Lab: Conditional Access, PIM and Access Reviews

> **Status: in progress.** This README is filled in as the project is built.

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
docs/
  ca-policy-plan.md      policy design, test cases, rollout record
  diagrams/              architecture diagram
  screenshots/           evidence for each stage
policies/                exported Conditional Access policy JSON (sanitised)
scripts/                 PowerShell used in the project
```

## Author

Bright Amalahu, Systems Administrator
[LinkedIn](https://www.linkedin.com/in/bright-amalahu/) · [Medium](https://medium.com/@brightkakatech) · [GitHub](https://github.com/Brightkakatech)
