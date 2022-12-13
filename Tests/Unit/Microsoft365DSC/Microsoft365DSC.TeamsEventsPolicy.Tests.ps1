[CmdletBinding()]
param(
)
$M365DSCTestFolder = Join-Path -Path $PSScriptRoot `
    -ChildPath '..\..\Unit' `
    -Resolve
$CmdletModule = (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\Stubs\Microsoft365.psm1' `
        -Resolve)
$GenericStubPath = (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\Stubs\Generic.psm1' `
        -Resolve)
Import-Module -Name (Join-Path -Path $M365DSCTestFolder `
        -ChildPath '\UnitTestHelper.psm1' `
        -Resolve)

$Global:DscHelper = New-M365DscUnitTestHelper -StubModule $CmdletModule `
    -DscResource 'TeamsEventsPolicy' -GenericStubModule $GenericStubPath

Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope

        BeforeAll {
            $secpasswd = ConvertTo-SecureString 'Pass@word1' -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential ('tenantadmin', $secpasswd)

            $Global:PartialExportFileName = 'c:\TestPath'
            Mock -CommandName Update-M365DSCExportAuthenticationResults -MockWith {
                return @{}
            }

            Mock -CommandName Get-M365DSCExportContentForResource -MockWith {
                return 'FakeDSCContent'
            }

            Mock -CommandName Save-M365DSCPartialExport -MockWith {
            }

            Mock -CommandName New-M365DSCConnection -MockWith {
                return 'Credentials'
            }

            Mock -CommandName New-CsTeamsEventsPolicy -MockWith {
            }

            Mock -CommandName Set-CsTeamsEventsPolicy -MockWith {
            }

            Mock -CommandName Remove-CsTeamsEventsPolicy -MockWith {
            }

            # Mock Write-Host to hide output during the tests
            Mock -CommandName Write-Host -MockWith {
            }
        }

        # Test contexts
        Context -Name "When Policy doesn't exist but should" -Fixture {
            BeforeAll {
                $testParams = @{
                    Description     = 'Desc'
                    Ensure          = 'Present'
                    Credential      = $Credential
                    Identity        = 'TestPolicy'
                    EventAccessType = 'EveryoneInCompanyExcludingGuests'
                    AllowWebinars   = 'Enabled'
                }

                Mock -CommandName Get-CsTeamsEventsPolicy -MockWith {
                    return $null
                }
            }

            It 'Should return absent from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Absent'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should create the policy in the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName New-CsTeamsEventsPolicy -Exactly 1
            }
        }

        Context -Name 'Policy exists but is not in the Desired State' -Fixture {
            BeforeAll {
                $testParams = @{
                    Description     = 'Desc'
                    Ensure          = 'Present'
                    Credential      = $Credential
                    Identity        = 'TestPolicy'
                    EventAccessType = 'EveryoneInCompanyExcludingGuests'
                    AllowWebinars   = 'Enabled'
                }

                Mock -CommandName Get-CsTeamsEventsPolicy -MockWith {
                    return @{
                        Description     = 'Desc'
                        Identity        = 'TestPolicy'
                        EventAccessType = 'EveryoneInCompanyExcludingGuests'
                        AllowWebinars   = 'Disabled'; #Drift
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should update the settings from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Set-CsTeamsEventsPolicy -Exactly 1
                Should -Invoke -CommandName New-CsTeamsEventsPolicy -Exactly 0
            }
        }

        Context -Name 'Policy exists and is already in the Desired State' -Fixture {
            BeforeAll {
                $testParams = @{
                    Description     = 'Desc'
                    Ensure          = 'Present'
                    Credential      = $Credential
                    Identity        = 'TestPolicy'
                    EventAccessType = 'EveryoneInCompanyExcludingGuests'
                    AllowWebinars   = 'Enabled'
                }

                Mock -CommandName Get-CsTeamsEventsPolicy -MockWith {
                    return @{
                        Description     = 'Desc'
                        Identity        = 'TestPolicy'
                        EventAccessType = 'EveryoneInCompanyExcludingGuests'
                        AllowWebinars   = 'Enabled'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should -Be $true
            }
        }

        Context -Name 'Policy exists but it should not' -Fixture {
            BeforeAll {
                $testParams = @{
                    Description     = 'Desc'
                    Ensure          = 'Absent'
                    Credential      = $Credential
                    Identity        = 'TestPolicy'
                    EventAccessType = 'EveryoneInCompanyExcludingGuests'
                    AllowWebinars   = 'Enabled'
                }

                Mock -CommandName Get-CsTeamsEventsPolicy -MockWith {
                    return @{
                        Description     = 'Desc'
                        Identity        = 'TestPolicy'
                        EventAccessType = 'EveryoneInCompanyExcludingGuests'
                        AllowWebinars   = 'Enabled'
                    }
                }
            }

            It 'Should return Present from the Get method' {
                (Get-TargetResource @testParams).Ensure | Should -Be 'Present'
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should -Be $false
            }

            It 'Should remove the policy from the Set method' {
                Set-TargetResource @testParams
                Should -Invoke -CommandName Remove-CsTeamsEventsPolicy -Exactly 1
            }
        }

        Context -Name 'ReverseDSC Tests' -Fixture {
            BeforeAll {
                $Global:CurrentModeIsExport = $true
                $testParams = @{
                    Credential = $Credential
                }

                Mock -CommandName Get-CsTeamsEventsPolicy -MockWith {
                    return @{
                        Description     = 'Desc'
                        Identity        = 'TestPolicy'
                        EventAccessType = 'EveryoneInCompanyExcludingGuests'
                        AllowWebinars   = 'Enabled'
                    }
                }
            }

            It 'Should Reverse Engineer resource from the Export method' {
                Export-TargetResource @testParams
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
