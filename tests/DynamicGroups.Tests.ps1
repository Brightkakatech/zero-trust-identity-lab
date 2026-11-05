#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
<#
    Checks the dynamic group definitions against the synthetic user data,
    so a typo in a rule is caught before it creates an empty group.
    Run: Invoke-Pester -Path ./tests -Output Detailed
#>

BeforeAll {
    $root = Join-Path $PSScriptRoot '..'
    $script:groups = @((Get-Content (Join-Path $root 'data' 'dynamic-groups.json') -Raw | ConvertFrom-Json).groups)
    $script:users = @(Import-Csv (Join-Path $root 'data' 'synthetic-users.csv'))

    # Simulates a simple rule of the form (user.<attribute> -eq "<value>") against the CSV.
    function Get-RuleMatch {
        param([string] $Rule, [object[]] $Users)

        if ($Rule -notmatch '^\(user\.(?<attr>department|extensionAttribute1) -eq "(?<value>[^"]+)"\)$') {
            throw "Unsupported rule format: $Rule"
        }
        $column = if ($Matches.attr -eq 'department') { 'Department' } else { 'RolloutRing' }
        $value = $Matches.value
        @($Users | Where-Object { $_.$column -ceq $value })
    }
}

Describe 'Dynamic group definitions' {

    It 'defines at least one group' {
        $groups.Count | Should -BeGreaterThan 0
    }

    It 'uses unique group names' {
        $groups | Group-Object displayName | Where-Object Count -gt 1 | Should -BeNullOrEmpty
    }

    It 'follows the naming rule DYN-Dept-Name or DYN-RingN-Name' {
        $groups | Where-Object { $_.displayName -cnotmatch '^DYN-(Dept-[A-Za-z]+|Ring[0-2]-[A-Za-z]+)$' } | Should -BeNullOrEmpty
    }

    It 'gives every group a description that starts with "Dynamic:"' {
        $groups | Where-Object { $_.description -notlike 'Dynamic: *' } | Should -BeNullOrEmpty
    }

    It 'uses only the supported rule format' {
        foreach ($group in $groups) {
            { Get-RuleMatch -Rule $group.membershipRule -Users $users } | Should -Not -Throw -Because $group.displayName
        }
    }

    It 'matches at least one synthetic user with every rule (no empty groups)' {
        foreach ($group in $groups) {
            (Get-RuleMatch -Rule $group.membershipRule -Users $users).Count | Should -BeGreaterThan 0 -Because "$($group.displayName) would be empty"
        }
    }

    It 'has a department group for every department in the data' {
        $departmentsWithGroup = $groups | Where-Object displayName -like 'DYN-Dept-*' | ForEach-Object { $_.displayName -replace '^DYN-Dept-', '' }
        $users.Department | Sort-Object -Unique | Where-Object { $_ -notin $departmentsWithGroup } | Should -BeNullOrEmpty
    }

    It 'puts every synthetic user in exactly one ring group' {
        $ringGroups = $groups | Where-Object displayName -like 'DYN-Ring*'
        foreach ($user in $users) {
            $count = @($ringGroups | Where-Object { (Get-RuleMatch -Rule $_.membershipRule -Users @($user)).Count -gt 0 }).Count
            $count | Should -Be 1 -Because "$($user.MailNickname) must be in one ring"
        }
    }
}
