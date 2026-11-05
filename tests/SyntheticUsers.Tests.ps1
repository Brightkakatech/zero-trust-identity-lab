#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
<#
    Checks the synthetic user data before it ever reaches the tenant.
    Run: Invoke-Pester -Path ./tests -Output Detailed
#>

BeforeAll {
    $csvPath = Join-Path $PSScriptRoot '..' 'data' 'synthetic-users.csv'
    $script:users = @(Import-Csv -Path $csvPath)
}

Describe 'Synthetic user data' {

    It 'contains 150 users' {
        $users.Count | Should -Be 150
    }

    It 'has a unique sign-in alias for every user' {
        $duplicates = $users | Group-Object MailNickname | Where-Object Count -gt 1
        $duplicates | Should -BeNullOrEmpty
    }

    It 'has a unique employee ID for every user' {
        $duplicates = $users | Group-Object EmployeeId | Where-Object Count -gt 1
        $duplicates | Should -BeNullOrEmpty
    }

    It 'labels every user as synthetic with an SYN employee ID' {
        $users | Where-Object { $_.EmployeeId -notmatch '^SYN\d+$' } | Should -BeNullOrEmpty
    }

    It 'uses only lowercase letters, digits and dots in aliases' {
        $users | Where-Object { $_.MailNickname -cnotmatch '^[a-z0-9.]+$' } | Should -BeNullOrEmpty
    }

    It 'uses only the approved departments' {
        $approved = 'IT', 'Finance', 'HR', 'Sales', 'Marketing', 'Operations', 'Legal', 'Executive'
        $users | Where-Object { $_.Department -notin $approved } | Should -BeNullOrEmpty
    }

    It 'uses only Ireland or the UK as usage location' {
        $users | Where-Object { $_.UsageLocation -notin 'IE', 'GB' } | Should -BeNullOrEmpty
    }

    It 'gives London staff a GB usage location and everyone else IE' {
        $users | Where-Object { ($_.OfficeLocation -eq 'London') -ne ($_.UsageLocation -eq 'GB') } | Should -BeNullOrEmpty
    }

    It 'puts every user in exactly one valid rollout ring' {
        $users | Where-Object { $_.RolloutRing -notin 'Ring0', 'Ring1', 'Ring2' } | Should -BeNullOrEmpty
    }

    It 'puts all of IT, and only IT, in Ring0' {
        $users | Where-Object { ($_.Department -eq 'IT') -ne ($_.RolloutRing -eq 'Ring0') } | Should -BeNullOrEmpty
    }

    It 'keeps the pilot ring small: between 5 and 15 percent of staff' {
        $pilot = @($users | Where-Object RolloutRing -eq 'Ring1').Count
        $pilot | Should -BeGreaterOrEqual ([math]::Ceiling($users.Count * 0.05))
        $pilot | Should -BeLessOrEqual ([math]::Floor($users.Count * 0.15))
    }

    It 'includes at least one pilot user from every department outside IT' {
        $departmentsWithoutPilot = $users |
            Where-Object Department -ne 'IT' |
            Group-Object Department |
            Where-Object { -not ($_.Group | Where-Object RolloutRing -eq 'Ring1') }
        $departmentsWithoutPilot | Should -BeNullOrEmpty
    }
}
