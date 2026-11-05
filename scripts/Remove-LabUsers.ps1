#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication, Microsoft.Graph.Users
<#
.SYNOPSIS
    Deletes the synthetic BrightKaka Tech staff created by New-LabUsers.ps1.

.DESCRIPTION
    Finds users whose company name is "BrightKaka Tech (synthetic)", then
    checks each one again before deleting it: the employee type must be
    "Synthetic" and the employee ID must start with SYN. A user that fails
    any check is left alone, so real accounts are never touched.

    Deleted users go to the Entra recycle bin and can be restored for 30 days.

    Run with -WhatIf first. Without -WhatIf, PowerShell asks before each
    deletion unless -Confirm:$false is given.

.EXAMPLE
    ./scripts/Remove-LabUsers.ps1 -WhatIf

.EXAMPLE
    ./scripts/Remove-LabUsers.ps1 -Confirm:$false
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param()

$ErrorActionPreference = 'Stop'

$SyntheticCompanyName = 'BrightKaka Tech (synthetic)'

Connect-MgGraph -Scopes 'User.ReadWrite.All' -NoWelcome

# companyName filters are an "advanced query", which needs ConsistencyLevel eventual and a count.
$candidates = Get-MgUser -All `
    -Filter "companyName eq '$SyntheticCompanyName'" `
    -ConsistencyLevel eventual -CountVariable candidateCount `
    -Property Id, UserPrincipalName, CompanyName, EmployeeType, EmployeeId

Write-Output ('Found {0} users labelled as synthetic.' -f $candidateCount)

$deleted = 0
$refused = 0

foreach ($user in $candidates) {
    # Second, independent check on every user before deleting.
    $isSynthetic = $user.CompanyName -eq $SyntheticCompanyName -and
                   $user.EmployeeType -eq 'Synthetic' -and
                   $user.EmployeeId -like 'SYN*'

    if (-not $isSynthetic) {
        Write-Warning "Not deleting $($user.UserPrincipalName): it does not carry all three synthetic labels."
        $refused++
        continue
    }

    if ($PSCmdlet.ShouldProcess($user.UserPrincipalName, 'Delete synthetic user')) {
        Remove-MgUser -UserId $user.Id
        $deleted++
    }
}

Write-Output ('Done. Deleted: {0}. Left alone: {1}.' -f $deleted, $refused)
