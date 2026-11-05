#Requires -Version 7.2
<#
.SYNOPSIS
    Generates the CSV of synthetic BrightKaka Tech staff used by New-LabUsers.ps1.

.DESCRIPTION
    Builds a fictional company of 150 staff across eight departments and five
    offices, and places each person in a rollout ring:

      Ring0  IT department, gets every change first
      Ring1  Pilot users, a few volunteers from each department
      Ring2  Everyone else

    Every person is fictional and clearly labelled as synthetic. A fixed seed
    means the same file is produced every time, so the data can be rebuilt
    and reviewed in Git.

.PARAMETER Path
    Where to write the CSV.

.PARAMETER Seed
    Random seed. Keep the default to reproduce the committed file.

.EXAMPLE
    ./scripts/New-SyntheticUserData.ps1 -Path ./data/synthetic-users.csv
#>
[CmdletBinding()]
param(
    [string] $Path = (Join-Path $PSScriptRoot '..' 'data' 'synthetic-users.csv'),
    [int]    $Seed = 2026
)

$ErrorActionPreference = 'Stop'

# Department sizes add up to 150. Pilot = how many people from that department join Ring1.
$departments = [ordered]@{
    'IT'         = @{ Count = 12; Pilot = 0; Titles = 'IT Support Analyst', 'Systems Administrator', 'Network Engineer', 'IT Manager' }
    'Finance'    = @{ Count = 20; Pilot = 3; Titles = 'Accounts Assistant', 'Financial Analyst', 'Payroll Specialist', 'Finance Manager' }
    'HR'         = @{ Count = 12; Pilot = 2; Titles = 'HR Assistant', 'HR Business Partner', 'Recruiter', 'HR Manager' }
    'Sales'      = @{ Count = 38; Pilot = 4; Titles = 'Sales Executive', 'Account Manager', 'Sales Coordinator', 'Sales Manager' }
    'Marketing'  = @{ Count = 18; Pilot = 3; Titles = 'Marketing Executive', 'Content Specialist', 'Digital Marketing Analyst', 'Marketing Manager' }
    'Operations' = @{ Count = 40; Pilot = 4; Titles = 'Operations Coordinator', 'Logistics Officer', 'Warehouse Supervisor', 'Operations Manager' }
    'Legal'      = @{ Count = 6;  Pilot = 1; Titles = 'Paralegal', 'Legal Counsel' }
    'Executive'  = @{ Count = 4;  Pilot = 1; Titles = 'Executive Assistant', 'Director' }
}

$offices = 'Dublin', 'Cork', 'Galway', 'Limerick', 'London'

$givenNames = @(
    'Aoife', 'Ciara', 'Niamh', 'Saoirse', 'Orla', 'Emma', 'Sophie', 'Grace', 'Hannah', 'Chloe',
    'Laura', 'Megan', 'Rachel', 'Amy', 'Kate', 'Sean', 'Conor', 'Darragh', 'Cian', 'Eoin',
    'Liam', 'Jack', 'James', 'Daniel', 'Adam', 'Ryan', 'Mark', 'David', 'Tom', 'Paul'
)

$surnames = @(
    'Byrne', 'Ryan', 'Walsh', 'Doyle', 'Kelly', 'Brennan', 'Quinn', 'Nolan', 'Lynch', 'Daly',
    'Kennedy', 'Duffy', 'Healy', 'Moran', 'Clarke', 'Hughes', 'Barry', 'Foley', 'Power', 'Burke',
    'Carroll', 'Farrell', 'Keane', 'Maguire', 'Reilly', 'Shaw', 'Fox', 'Hayes', 'Price', 'Wood'
)

$random = [System.Random]::new($Seed)
$usedAliases = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$rows = [System.Collections.Generic.List[object]]::new()
$employeeNumber = 1000

foreach ($department in $departments.Keys) {
    $spec = $departments[$department]

    for ($i = 0; $i -lt $spec.Count; $i++) {
        $given = $givenNames[$random.Next($givenNames.Count)]
        $surname = $surnames[$random.Next($surnames.Count)]

        # Alias such as aoife.byrne, with a number added if the name is already taken.
        $base = ('{0}.{1}' -f $given, $surname).ToLowerInvariant()
        $alias = $base
        $suffix = 2
        while (-not $usedAliases.Add($alias)) {
            $alias = '{0}{1}' -f $base, $suffix
            $suffix++
        }

        # The last title in each list is the manager, so give it to only one person.
        $title = if ($i -eq 0) { $spec.Titles[-1] } else { $spec.Titles[$random.Next($spec.Titles.Count - 1)] }

        $ring = if ($department -eq 'IT') { 'Ring0' } elseif ($i -ge 1 -and $i -le $spec.Pilot) { 'Ring1' } else { 'Ring2' }

        $office = $offices[$random.Next($offices.Count)]

        # Usage location is the country where licences are used: GB for London, IE for the Irish offices.
        $usageLocation = if ($office -eq 'London') { 'GB' } else { 'IE' }

        $employeeNumber++
        $rows.Add([pscustomobject]@{
            GivenName      = $given
            Surname        = $surname
            DisplayName    = ('{0} {1}' -f $given, $surname)
            MailNickname   = $alias
            Department     = $department
            JobTitle       = $title
            OfficeLocation = $office
            UsageLocation  = $usageLocation
            EmployeeId     = ('SYN{0}' -f $employeeNumber)
            RolloutRing    = $ring
        })
    }
}

$folder = Split-Path -Parent $Path
if (-not (Test-Path $folder)) {
    New-Item -ItemType Directory -Path $folder | Out-Null
}

$rows | Export-Csv -Path $Path -NoTypeInformation -Encoding utf8

$summary = $rows | Group-Object RolloutRing | Sort-Object Name | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Count }
Write-Output ('Wrote {0} synthetic users to {1} ({2})' -f $rows.Count, $Path, ($summary -join ', '))
