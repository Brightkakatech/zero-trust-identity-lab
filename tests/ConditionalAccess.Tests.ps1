#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }
<#
    Guardrail tests for the exported Conditional Access policies in policies/.

    These run in GitHub Actions on every push. If someone changes a policy in a
    way that breaks a rule below, the build fails before the change is accepted.

    Run: Invoke-Pester -Path ./tests -Output Detailed
#>

BeforeDiscovery {
    $policyFolder = Join-Path $PSScriptRoot '..' 'policies'
    $script:policyFiles = @(Get-ChildItem -Path $policyFolder -Filter 'CA*.json' | ForEach-Object {
        @{ Name = $_.BaseName; Path = $_.FullName }
    })
}

BeforeAll {
    $script:BreakGlassGroup = 'group:CA-Exclude-BreakGlass'
    $policyFolder = Join-Path $PSScriptRoot '..' 'policies'
    $script:approvals = Get-Content (Join-Path $policyFolder 'rollout-approvals.json') -Raw | ConvertFrom-Json
    $script:policyCount = @(Get-ChildItem -Path $policyFolder -Filter 'CA*.json').Count
}

Describe 'Policy export' {
    It 'contains at least one exported policy' {
        $policyCount | Should -BeGreaterThan 0
    }
}

Describe 'Policy <Name>' -ForEach $policyFiles {

    BeforeAll {
        $policy = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $users = $policy.conditions.users
        $grant = $policy.grantControls
        $isBlock = $grant.builtInControls -contains 'block'
    }

    It 'is named CAnn followed by a description' {
        $policy.displayName | Should -Match '^CA\d{2} \S.+'
    }

    It 'matches its file name' {
        $policy.displayName | Should -BeLike "$Name *"
    }

    It 'excludes the break-glass group' {
        $users.excludeGroups | Should -Contain $BreakGlassGroup -Because 'emergency access accounts must never be locked out'
    }

    It 'does not include the break-glass group' {
        $users.includeGroups | Should -Not -Contain $BreakGlassGroup
    }

    It 'is report-only or on, never left switched off' {
        $policy.state | Should -BeIn @('enabledForReportingButNotEnforced', 'enabled') -Because 'a disabled policy protects nobody and should be deleted or documented'
    }

    It 'is only switched on after an approved report-only period' {
        if ($policy.state -ne 'enabled') {
            Set-ItResult -Skipped -Because 'the policy is in report-only mode'
            return
        }

        $approval = $approvals.approvals | Where-Object policy -eq $Name
        $approval | Should -Not -BeNullOrEmpty -Because "$Name is on, so it needs an entry in rollout-approvals.json"

        $days = ([datetime]$approval.approvedOn - [datetime]$approval.reportOnlyFrom).Days
        $days | Should -BeGreaterOrEqual $approvals.minimumReportOnlyDays -Because 'policies must run in report-only mode first'
        $approval.approvedBy | Should -Not -BeNullOrEmpty
        $approval.change | Should -Not -BeNullOrEmpty -Because 'every enforcement needs a change record'
    }

    It 'contains no tenant object IDs outside the application list' {
        # Application IDs are the same in every tenant (for example Exchange Online), so they may stay.
        $guid = '[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}'
        $copy = Get-Content -Path $Path -Raw | ConvertFrom-Json
        $copy.conditions.PSObject.Properties.Remove('applications')
        ($copy | ConvertTo-Json -Depth 20) | Should -Not -Match $guid
    }

    It 'contains no Graph metadata' {
        Get-Content -Path $Path -Raw | Should -Not -Match '@odata\.'
    }

    It 'has no unresolved names' {
        ($policy | ConvertTo-Json -Depth 20) | Should -Not -Match 'UNRESOLVED'
    }

    It 'has a grant control' {
        $grant.builtInControls | Should -Not -BeNullOrEmpty
    }

    It 'does not block all users from all locations' {
        if (-not $isBlock -or -not $policy.conditions.locations) {
            Set-ItResult -Skipped -Because 'not a location based block'
            return
        }
        $policy.conditions.locations.excludeLocations | Should -Not -BeNullOrEmpty -Because 'a block on all locations with no exclusion locks everyone out'
    }
}
