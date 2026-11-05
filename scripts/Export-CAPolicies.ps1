#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication
<#
.SYNOPSIS
    Exports every Conditional Access policy to a sanitised JSON file in policies/.

.DESCRIPTION
    Reads the policies from Microsoft Graph and writes one file per policy,
    named after its ID (CA01.json, CA02.json ...). Before saving, the export
    is sanitised so it is safe to publish:

      - Tenant specific object IDs for groups, users and named locations are
        replaced with readable names, for example group:CA-Exclude-BreakGlass.
      - Directory role IDs are replaced with role names, for example
        role:Global Administrator.
      - The policy ID and created/modified timestamps are removed, so a file
        only changes in Git when the policy itself changes.

    The files are then checked by tests/ConditionalAccess.Tests.ps1, which
    enforces the guardrails (break-glass excluded, naming, report-only first).

    Read only: the script needs Policy.Read.All and Directory.Read.All, and
    changes nothing in the tenant.

.PARAMETER OutputPath
    Folder for the JSON files.

.EXAMPLE
    ./scripts/Export-CAPolicies.ps1
#>
[CmdletBinding()]
param(
    [string] $OutputPath = (Join-Path $PSScriptRoot '..' 'policies')
)

$ErrorActionPreference = 'Stop'

# Values Microsoft uses instead of object IDs. These are kept as they are.
$SpecialValues = 'All', 'None', 'GuestsOrExternalUsers', 'AllTrusted'

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

function Resolve-ObjectName {
    param([string] $Kind, [string] $Id)

    if ($Id -in $SpecialValues) { return $Id }

    $cacheKey = "$Kind/$Id"
    if ($script:nameCache.ContainsKey($cacheKey)) { return $script:nameCache[$cacheKey] }

    $name = switch ($Kind) {
        'group'         { (Invoke-MgGraphRequest -Method GET -Uri "v1.0/groups/$Id`?`$select=displayName" -OutputType PSObject).displayName }
        'user'          { (Invoke-MgGraphRequest -Method GET -Uri "v1.0/users/$Id`?`$select=displayName" -OutputType PSObject).displayName }
        'role'          { $script:roleNames[$Id] }
        'namedLocation' { $script:locationNames[$Id] }
    }

    if (-not $name) {
        Write-Warning "Could not resolve $Kind $Id. It may have been deleted. Exported as unresolved."
        $name = 'UNRESOLVED'
    }

    $result = '{0}:{1}' -f $Kind, $name
    $script:nameCache[$cacheKey] = $result
    $result
}

function Clear-ODataMetadata {
    # Graph adds properties such as "authenticationStrength@odata.context",
    # which contain the policy's own ID. Remove them at every level.
    param([object] $InputObject)

    if ($InputObject -isnot [System.Management.Automation.PSCustomObject]) { return }

    foreach ($property in @($InputObject.PSObject.Properties)) {
        if ($property.Name -like '*@odata.*') {
            $InputObject.PSObject.Properties.Remove($property.Name)
        }
        else {
            foreach ($child in @($property.Value)) { Clear-ODataMetadata -InputObject $child }
        }
    }
}

function ConvertTo-NameList {
    param([string] $Kind, [object[]] $Ids)
    , @($Ids | Where-Object { $_ } | ForEach-Object { Resolve-ObjectName -Kind $Kind -Id $_ } | Sort-Object)
}

Connect-MgGraph -Scopes 'Policy.Read.All', 'Directory.Read.All' -NoWelcome

$script:nameCache = @{}

# Role IDs in policies are role template IDs, which are the same in every tenant.
$script:roleNames = @{}
foreach ($role in Get-GraphCollection -Uri 'v1.0/directoryRoleTemplates?$select=id,displayName') {
    $script:roleNames[$role.id] = $role.displayName
}

$script:locationNames = @{}
foreach ($location in Get-GraphCollection -Uri 'v1.0/identity/conditionalAccess/namedLocations') {
    $script:locationNames[$location.id] = $location.displayName
}

$policies = @(Get-GraphCollection -Uri 'v1.0/identity/conditionalAccess/policies')
Write-Output ('Found {0} Conditional Access policies.' -f $policies.Count)

if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

foreach ($policy in $policies) {
    $users = $policy.conditions.users
    foreach ($pair in @(
            @('includeUsers', 'user'), @('excludeUsers', 'user'),
            @('includeGroups', 'group'), @('excludeGroups', 'group'),
            @('includeRoles', 'role'), @('excludeRoles', 'role'))) {
        $users.($pair[0]) = ConvertTo-NameList -Kind $pair[1] -Ids $users.($pair[0])
    }

    $locations = $policy.conditions.locations
    if ($locations) {
        $locations.includeLocations = ConvertTo-NameList -Kind 'namedLocation' -Ids $locations.includeLocations
        $locations.excludeLocations = ConvertTo-NameList -Kind 'namedLocation' -Ids $locations.excludeLocations
    }

    # Remove fields that are tenant specific or change on every save.
    $policy.PSObject.Properties.Remove('id')
    $policy.PSObject.Properties.Remove('createdDateTime')
    $policy.PSObject.Properties.Remove('modifiedDateTime')
    $policy.PSObject.Properties.Remove('deletedDateTime')
    Clear-ODataMetadata -InputObject $policy

    $policyId = if ($policy.displayName -match '^(CA\d{2})\b') { $Matches[1] } else { ($policy.displayName -replace '[^A-Za-z0-9]+', '-').Trim('-') }
    $file = Join-Path $OutputPath "$policyId.json"

    $policy | ConvertTo-Json -Depth 20 | Set-Content -Path $file -Encoding utf8NoBOM
    Write-Output ('Exported {0} to {1}' -f $policy.displayName, (Split-Path $file -Leaf))
}
