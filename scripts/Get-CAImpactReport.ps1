#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Builds a go/no-go impact report before a Conditional Access policy is switched On for a rollout ring.

.DESCRIPTION
    Answers two questions and writes the answers to a Markdown report:

    1. What did the report-only policies actually do?
       Reads the sign-in logs for the last few days and counts, per policy,
       how many sign-ins would have succeeded, been interrupted (for example
       an MFA prompt) or been blocked, and which users were interrupted or blocked.

    2. Is the target ring ready?
       Lists the members of the ring group and checks each enabled account
       for a registered MFA method. An enabled user with no MFA method would
       be stopped at their next sign-in once an MFA policy is On.

    Read only: needs AuditLog.Read.All and Directory.Read.All, and changes nothing.
    Only display names are written to the report, no sign-in names or IDs.

.PARAMETER Days
    How many days of sign-in logs to read.

.PARAMETER TargetGroup
    The rollout ring group the policies would be switched On for.

.PARAMETER OutputPath
    Where to write the Markdown report.

.EXAMPLE
    ./scripts/Get-CAImpactReport.ps1 -TargetGroup DYN-Ring1-Pilot
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 30)]
    [int] $Days = 7,

    [string] $TargetGroup = 'DYN-Ring1-Pilot',

    [string] $OutputPath = (Join-Path $PSScriptRoot '..' 'docs' 'evidence' 'ca-impact-report.md')
)

$ErrorActionPreference = 'Stop'

function Get-GraphCollection {
    param([string] $Uri)
    $items = [System.Collections.Generic.List[object]]::new()
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        foreach ($item in $page.value) { $items.Add($item) }
        $Uri = $page.'@odata.nextLink'
    }
    $items
}

Connect-MgGraph -Scopes 'AuditLog.Read.All', 'Directory.Read.All' -NoWelcome

$since = (Get-Date).ToUniversalTime().AddDays(-$Days).ToString('yyyy-MM-ddTHH:mm:ssZ')
$generated = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm') + ' UTC'

# ---------- Part 1: what the report-only policies did ----------

$signIns = @(Get-GraphCollection -Uri "v1.0/auditLogs/signIns?`$filter=createdDateTime ge $since&`$top=500")
Write-Output ('Read {0} interactive sign-ins from the last {1} days.' -f $signIns.Count, $Days)

$evaluations = foreach ($signIn in $signIns) {
    foreach ($policy in $signIn.appliedConditionalAccessPolicies) {
        if ($policy.result -like 'reportOnly*') {
            [pscustomobject]@{
                Policy = $policy.displayName
                Result = $policy.result
                User   = $signIn.userDisplayName
            }
        }
    }
}

$policyRows = foreach ($group in ($evaluations | Group-Object Policy | Sort-Object Name)) {
    $results = $group.Group
    $affected = $results | Where-Object Result -in 'reportOnlyInterrupted', 'reportOnlyFailure' |
        Select-Object -ExpandProperty User -Unique | Sort-Object
    [pscustomobject]@{
        Policy      = $group.Name
        Evaluated   = $results.Count
        Success     = @($results | Where-Object Result -eq 'reportOnlySuccess').Count
        Interrupted = @($results | Where-Object Result -eq 'reportOnlyInterrupted').Count
        Blocked     = @($results | Where-Object Result -eq 'reportOnlyFailure').Count
        NotApplied  = @($results | Where-Object Result -eq 'reportOnlyNotApplied').Count
        Affected    = if ($affected) { $affected -join ', ' } else { 'None' }
    }
}

# ---------- Part 2: is the target ring ready? ----------

$group = @(Get-GraphCollection -Uri "v1.0/groups?`$filter=displayName eq '$TargetGroup'&`$select=id,displayName")
if ($group.Count -ne 1) {
    throw "Expected exactly one group named '$TargetGroup', found $($group.Count)."
}

$members = @(Get-GraphCollection -Uri "v1.0/groups/$($group[0].id)/members/microsoft.graph.user?`$select=id,displayName,accountEnabled")

$registration = @{}
foreach ($detail in Get-GraphCollection -Uri 'v1.0/reports/authenticationMethods/userRegistrationDetails') {
    $registration[$detail.id] = $detail
}

$readiness = foreach ($member in $members) {
    $detail = $registration[$member.id]
    [pscustomobject]@{
        User          = $member.displayName
        Enabled       = [bool] $member.accountEnabled
        MfaRegistered = [bool] ($detail -and $detail.isMfaRegistered)
    }
}

$enabled = @($readiness | Where-Object Enabled)
$disabled = @($readiness | Where-Object { -not $_.Enabled })
$notReady = @($enabled | Where-Object { -not $_.MfaRegistered })
$decision = if ($notReady.Count -eq 0) { 'GO: every enabled user in the ring has MFA registered.' } else { "REVIEW: $($notReady.Count) enabled user(s) in the ring have no MFA method and would be stopped at their next sign-in." }

# ---------- Write the report ----------

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('# Conditional Access impact report')
$lines.Add('')
$lines.Add("Generated: $generated. Sign-in window: last $Days days. Target ring: **$TargetGroup**.")
$lines.Add('')
$lines.Add('## 1. What the report-only policies did')
$lines.Add('')
$lines.Add("Interactive sign-ins read: $($signIns.Count).")
$lines.Add('')
$lines.Add('| Policy | Evaluated | Would succeed | Would interrupt | Would block | Not applied | Users interrupted or blocked |')
$lines.Add('|---|---|---|---|---|---|---|')
foreach ($row in $policyRows) {
    $lines.Add("| $($row.Policy) | $($row.Evaluated) | $($row.Success) | $($row.Interrupted) | $($row.Blocked) | $($row.NotApplied) | $($row.Affected) |")
}
if (-not $policyRows) {
    $lines.Add('| No report-only evaluations in this window | | | | | | |')
}
$lines.Add('')
$lines.Add('## 2. Is the target ring ready?')
$lines.Add('')
$lines.Add('| Members | Enabled | Enabled with MFA registered | Enabled without MFA | Disabled (no sign-in, no impact) |')
$lines.Add('|---|---|---|---|---|')
$lines.Add("| $($readiness.Count) | $($enabled.Count) | $($enabled.Count - $notReady.Count) | $($notReady.Count) | $($disabled.Count) |")
$lines.Add('')
if ($notReady) {
    $lines.Add('Enabled users without MFA: ' + (($notReady.User | Sort-Object) -join ', ') + '.')
    $lines.Add('')
}
$lines.Add("**Decision: $decision**")

$folder = Split-Path -Parent $OutputPath
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder | Out-Null
}
$lines | Set-Content -Path $OutputPath -Encoding utf8NoBOM

Write-Output ('Report written to {0}' -f (Resolve-Path $OutputPath))
Write-Output "Decision: $decision"
