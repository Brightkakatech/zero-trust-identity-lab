# Conditional Access policy plan

BrightKaka Tech — Zero Trust identity lab
Status: **Draft (pre-trial)**. Results are filled in during trial week 1.

## How to read this plan

Every Conditional Access (CA) policy answers one question:
**"When _these users_ access _these resources_ under _these conditions_, what must happen?"**

| Part of a policy | What it means | Example |
|---|---|---|
| **Users** (assignment) | Who the policy applies to, and who is excluded | All users, except break-glass accounts |
| **Target resources** | Which apps or services | All resources (all cloud apps) |
| **Conditions** | Extra filters | Location, client app type, device platform |
| **Grant** (access control) | What is required, or block | Require MFA, require compliant device, block |
| **State** | Report-only, On or Off | Report-only first, always |

Every policy below excludes the group **CA-Exclude-BreakGlass**, so the emergency accounts can always sign in.

## Test accounts and groups

| Name | Type | Purpose |
|---|---|---|
| alice | Standard user | Pilot user |
| bob | Standard user | Pilot user |
| helpdesk-test | Admin (via PIM, eligible only) | Tests admin policies and PIM activation |
| breakglass01, breakglass02 | Cloud-only Global Administrators (active permanent, not PIM eligible) | Emergency access, excluded from all CA policies that block or restrict sign-in |
| CA-Exclude-BreakGlass | Security group | Holds both break-glass accounts |
| CA-Pilot-Users | Security group | alice and bob, first rollout target |

## Break-glass account design

Based on Microsoft's guidance, "Manage emergency access accounts in Microsoft Entra ID".

| Decision | Choice | Reason |
|---|---|---|
| Number | Two accounts | Redundancy: if one fails, the other still works |
| Account type | Cloud-only, on the `onmicrosoft.com` domain | No dependency on on-premises AD, federation or a custom domain that could fail |
| Role | Global Administrator, **active permanent** | An eligible (PIM) assignment needs activation, which could fail during an outage |
| Sign-in method | Phishing-resistant MFA: a passkey (FIDO2) | Satisfies Microsoft's mandatory MFA for admin portals, so the accounts still work even though they are excluded from Conditional Access |
| Different method from daily admins | Yes | An outage affecting the admins' usual method (e.g. Microsoft Authenticator) does not also lock out the emergency accounts |
| Not tied to a person | Yes | No personal phone, personal MFA registration or employee device |
| Conditional Access | Excluded through the group CA-Exclude-BreakGlass | One group to manage, instead of editing every policy |
| Monitoring | Alert on **any** sign-in (critical severity) via Log Analytics | Any use is either a drill or an emergency, and both must be reviewed |
| Testing | Sign in every 90 days, and after staff or licence changes | Proves the accounts still work against current policies |
| Credential storage | Passkeys and passwords stored offline, in separate secure places | No single point of loss |

**Lab limitation:** in a real company the FIDO2 keys are hardware keys kept in separate safes. In this lab, [record what was used, e.g. one hardware security key, or a passkey, and why]. This is noted as a deviation from production practice.

## Policies

| ID | Name | Users | Target resources | Conditions | Grant | Why this policy exists |
|---|---|---|---|---|---|---|
| CA01 | Require MFA for all users | All users, excl. CA-Exclude-BreakGlass | All resources | None | Require MFA | Passwords alone are the most common way accounts are taken over. MFA stops most of these attacks. |
| CA02 | Block legacy authentication | All users, excl. CA-Exclude-BreakGlass | All resources | Client apps: Exchange ActiveSync, Other clients | Block | Legacy protocols (old mail clients, basic auth) cannot do MFA, so they would let attackers bypass CA01. |
| CA03 | Require MFA for admins | Directory roles (see list below), excl. CA-Exclude-BreakGlass | All resources | None | Require MFA | Defence in depth: admins stay protected even if CA01 is changed or someone is excluded from it by mistake. Can later be tightened to phishing-resistant MFA. |
| CA04 | Block sign-in from outside Ireland and the UK | All users, excl. CA-Exclude-BreakGlass | All resources | Locations: include Any, exclude named location "Allowed countries – IE, UK" | Block | BrightKaka Tech staff only work from Ireland and the UK, so sign-ins from elsewhere are suspicious. |
| CA05 | Require compliant device | CA-Pilot-Users first | All resources | Device platform: Windows | Require device to be marked as compliant | Only managed, healthy devices (Intune) can access company data. **Built after Project 5.** |

**Admin roles for CA03:** Global Administrator, Privileged Role Administrator, Security Administrator, Conditional Access Administrator, User Administrator, Helpdesk Administrator, Exchange Administrator, SharePoint Administrator, Intune Administrator, Application Administrator, Cloud Application Administrator, Authentication Administrator, Billing Administrator.

## Test cases and expected results

Report-only results appear on the **Report-only** tab of each sign-in log entry. The possible values are: *Success*, *Failure*, *User action required* (for example, an MFA prompt) and *Not applied*.

| Test | Who | How | Expected report-only result | Actual result | Notes |
|---|---|---|---|---|---|
| T1 | alice | Browser sign-in to office.com from Ireland | CA01: User action required. CA04: Not applied. | | |
| T2 | bob | Browser sign-in, MFA completed | CA01: Success | | |
| T3 | alice | What If: client app "Exchange ActiveSync" | CA02: applies, Block | | Real legacy sign-ins are hard to create because Microsoft has already switched off basic authentication for most Exchange Online protocols, so use What If. |
| T4 | helpdesk-test | Sign-in after activating an admin role in PIM | CA03: User action required or Success | | |
| T5 | alice | What If: location outside Ireland/UK (e.g. United States) | CA04: applies, Block | | |
| T6 | breakglass01 | Browser sign-in | No CA policy applies | | Proves the exclusion works |
| T7 | alice | Sign-in from a compliant Intune device (after Project 5) | CA05: Success | | |

## Rollout record

| ID | Report-only from | Pilot (CA-Pilot-Users) from | Everyone from | Issues found |
|---|---|---|---|---|
| CA01 | | | | |
| CA02 | | | | |
| CA03 | | | | |
| CA04 | | | | |
| CA05 | | | | |

## Lockout recovery plan

1. Keep one browser window signed in as a Global Administrator for the whole testing session.
2. If a policy locks users out, sign in with **breakglass01** (excluded from every policy) and set the policy to Report-only or Off.
3. Check the sign-in log entry for the failed user to see which policy blocked them.
4. Every sign-in by a break-glass account is investigated (see the optional alert in the README).
