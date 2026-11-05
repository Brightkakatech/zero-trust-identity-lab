#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Groups
<#
.SYNOPSIS
    Creates the dynamic department and rollout ring groups defined in data/dynamic-groups.json.

.DESCRIPTION
    Each group is a security group with dynamic membership: Microsoft Entra ID
    adds and removes members automatically based on a rule, such as
    user.department -eq "Finance". When someone changes department or ring,
    their group membership follows without anyone editing a group.

    The group definitions live in a JSON file, so changes are reviewed in Git
    and checked by tests/DynamicGroups.Tests.ps1 before they reach the tenant.

    Safe to run more than once: groups that already exist are skipped.
    Use -WhatIf first to preview.

    Dynamic membership needs Microsoft Entra ID P1 or higher.

.PARAMETER Path
    The JSON file with the group definitions.

.EXAMPLE
    ./scripts/New-LabDynamicGroups.ps1 -WhatIf

.EXAMPLE
    ./scripts/New-LabDynamicGroups.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $Path = (Join-Path $PSScriptRoot '..' 'data' 'dynamic-groups.json')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Path)) {
    throw "Group definitions not found: $Path"
}

$definitions = @((Get-Content -Path $Path -Raw | ConvertFrom-Json).groups)
if ($definitions.Count -eq 0) {
    throw "No groups defined in $Path"
}

Write-Output ('Read {0} group definitions from {1}' -f $definitions.Count, (Resolve-Path $Path))

if (-not $WhatIfPreference) {
    Connect-MgGraph -Scopes 'Group.ReadWrite.All' -NoWelcome
}

$created = 0
$skipped = 0
$failed = 0

foreach ($group in $definitions) {
    if (-not $WhatIfPreference) {
        $existing = Get-MgGroup -Filter "displayName eq '$($group.displayName)'" -Property Id -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Verbose "Skipped (already exists): $($group.displayName)"
            $skipped++
            continue
        }
    }

    if (-not $PSCmdlet.ShouldProcess($group.displayName, "Create dynamic group with rule $($group.membershipRule)")) {
        continue
    }

    $body = @{
        displayName                   = $group.displayName
        description                   = $group.description
        mailNickname                  = $group.displayName.ToLowerInvariant()
        mailEnabled                   = $false
        securityEnabled               = $true
        groupTypes                    = @('DynamicMembership')
        membershipRule                = $group.membershipRule
        membershipRuleProcessingState = 'On'
    }

    try {
        New-MgGroup -BodyParameter $body | Out-Null
        Write-Verbose "Created: $($group.displayName)"
        $created++
    }
    catch {
        Write-Warning "Failed: $($group.displayName). $($_.Exception.Message)"
        $failed++
    }
}

Write-Output ('Done. Created: {0}. Skipped (already existed): {1}. Failed: {2}.' -f $created, $skipped, $failed)
Write-Output 'Entra ID fills dynamic groups in the background. Members can take several minutes to appear.'
if ($failed -gt 0) {
    exit 1
}
