#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users
<#
.SYNOPSIS
    Creates the synthetic BrightKaka Tech staff in Microsoft Entra ID from a CSV file.

.DESCRIPTION
    Reads data/synthetic-users.csv and creates one cloud user per row through
    Microsoft Graph. The script is safe to run more than once: users that
    already exist are skipped, not duplicated.

    Every account is created:
      - DISABLED, because nobody signs in as these users. They exist to test
        dynamic groups, rollout rings and reports at a realistic scale.
      - With a long random password that is never shown or saved.
      - Labelled as synthetic in three places (company name, employee type
        and an SYN employee ID), so they can never be mistaken for real
        staff and can be removed in one step by Remove-LabUsers.ps1.

    The rollout ring is stored in extensionAttribute1, so dynamic groups can
    use it: Ring0 (IT), Ring1 (pilot), Ring2 (everyone else).

    Use -WhatIf first to see what would be created without changing anything.

.PARAMETER Domain
    The tenant domain for sign-in names, for example contoso.onmicrosoft.com.

.PARAMETER Path
    The CSV produced by New-SyntheticUserData.ps1.

.EXAMPLE
    ./scripts/New-LabUsers.ps1 -Domain contoso.onmicrosoft.com -WhatIf

.EXAMPLE
    ./scripts/New-LabUsers.ps1 -Domain contoso.onmicrosoft.com
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string] $Domain,

    [string] $Path = (Join-Path $PSScriptRoot '..' 'data' 'synthetic-users.csv')
)

$ErrorActionPreference = 'Stop'

$SyntheticCompanyName = 'BrightKaka Tech (synthetic)'
$SyntheticEmployeeType = 'Synthetic'
$RequiredColumns = 'GivenName', 'Surname', 'DisplayName', 'MailNickname', 'Department',
                   'JobTitle', 'OfficeLocation', 'UsageLocation', 'EmployeeId', 'RolloutRing'

function Get-RandomPassword {
    # 32 characters from a cryptographic random source. Never displayed or stored.
    $characters = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%&*?'
    -join (1..32 | ForEach-Object { $characters[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($characters.Length)] })
}

# 1. Read and check the CSV before touching the tenant.
if (-not (Test-Path $Path)) {
    throw "CSV not found: $Path. Run New-SyntheticUserData.ps1 first."
}

$rows = @(Import-Csv -Path $Path)
if ($rows.Count -eq 0) {
    throw "CSV is empty: $Path"
}

$missing = $RequiredColumns | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
if ($missing) {
    throw "CSV is missing columns: $($missing -join ', ')"
}

$notSynthetic = $rows | Where-Object { $_.EmployeeId -notlike 'SYN*' }
if ($notSynthetic) {
    throw "Every row must have an EmployeeId starting with SYN. Refusing to continue."
}

Write-Output ('Read {0} users from {1}' -f $rows.Count, $Path)

# 2. Sign in with only the permission this script needs.
if (-not $WhatIfPreference) {
    Connect-MgGraph -Scopes 'User.ReadWrite.All' -NoWelcome
}

# 3. Create each user, skipping any that already exist.
$created = 0
$skipped = 0
$failed = 0

foreach ($row in $rows) {
    $upn = '{0}@{1}' -f $row.MailNickname, $Domain

    if (-not $WhatIfPreference) {
        $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -Property Id -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Verbose "Skipped (already exists): $upn"
            $skipped++
            continue
        }
    }

    if (-not $PSCmdlet.ShouldProcess($upn, "Create synthetic user in $($row.Department), $($row.RolloutRing)")) {
        continue
    }

    $body = @{
        accountEnabled              = $false
        displayName                 = $row.DisplayName
        givenName                   = $row.GivenName
        surname                     = $row.Surname
        mailNickname                = $row.MailNickname
        userPrincipalName           = $upn
        department                  = $row.Department
        jobTitle                    = $row.JobTitle
        officeLocation              = $row.OfficeLocation
        usageLocation               = $row.UsageLocation
        employeeId                  = $row.EmployeeId
        employeeType                = $SyntheticEmployeeType
        companyName                 = $SyntheticCompanyName
        onPremisesExtensionAttributes = @{ extensionAttribute1 = $row.RolloutRing }
        passwordProfile             = @{
            password                      = Get-RandomPassword
            forceChangePasswordNextSignIn = $true
        }
    }

    try {
        New-MgUser -BodyParameter $body | Out-Null
        Write-Verbose "Created: $upn"
        $created++
    }
    catch {
        Write-Warning "Failed: $upn. $($_.Exception.Message)"
        $failed++
    }
}

Write-Output ('Done. Created: {0}. Skipped (already existed): {1}. Failed: {2}.' -f $created, $skipped, $failed)
if ($failed -gt 0) {
    exit 1
}
