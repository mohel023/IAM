#requires -Version 5.1
<#
.SYNOPSIS
  Create a dedicated AD DS Connector user and optionally delegate PHS permissions.
.DESCRIPTION
  Run on a secured AD administration host with RSAT/ActiveDirectory and access to ADWS.
  Creation and delegation are separate explicit operations. No secrets are stored in this script.
  This script does not configure Entra Connect itself.
.EXAMPLE
  .\05-New-ADDSConnector-PHS.ps1 -SamAccountName svcEntraAD -AccountName 'SVC-T0-SFC-PRD-EntraConnect' -OU 'OU=ServiceAccounts,DC=example,DC=local' -CreateAccount -WhatIf
.EXAMPLE
  .\05-New-ADDSConnector-PHS.ps1 -SamAccountName svcEntraAD -AccountName 'SVC-T0-SFC-PRD-EntraConnect' -OU 'OU=ServiceAccounts,DC=example,DC=local' -CreateAccount
.EXAMPLE
  .\05-New-ADDSConnector-PHS.ps1 -SamAccountName svcEntraAD -DelegatePHS -ADSyncConfigPath 'C:\Program Files\Microsoft Azure Active Directory Connect\AdSyncConfig\ADSyncConfig.psm1' -WhatIf
#>
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [Parameter(Mandatory)][ValidateLength(1,20)][string]$SamAccountName,
 [string]$AccountName = 'AD DS Connector for Entra Connect',
 [string]$OU,
 [switch]$CreateAccount,
 [switch]$DelegatePHS,
 [string]$ADSyncConfigPath
)
$ErrorActionPreference='Stop'
if (-not ($CreateAccount -or $DelegatePHS)) { throw 'Specify -CreateAccount and/or -DelegatePHS.' }
if ($CreateAccount -and [string]::IsNullOrWhiteSpace($OU)) { throw '-OU is required with -CreateAccount.' }
Import-Module ActiveDirectory -ErrorAction Stop
$domain=Get-ADDomain
$existing=Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -ErrorAction Stop
if ($existing -is [array]) { throw 'Multiple users matched. Stop and investigate.' }
if ($CreateAccount) {
  $null=Get-ADOrganizationalUnit -Identity $OU -ErrorAction Stop
  if ($existing) { Write-Warning "Account already exists: $($existing.DistinguishedName). No changes made." }
  elseif ($PSCmdlet.ShouldProcess("$SamAccountName in $OU",'Create AD DS Connector account')) {
    $password=Read-Host 'Enter strong vault-managed connector password' -AsSecureString
    New-ADUser -Name $AccountName -SamAccountName $SamAccountName -Path $OU -AccountPassword $password -Enabled $true -Description 'Microsoft Entra Connect AD DS Connector; PHS' -ErrorAction Stop
    Write-Host 'Account created. Record the secret securely and apply your approved password rotation policy.'
  }
}
if ($DelegatePHS) {
  # Resolve account after creation, unless this is a WhatIf-only run.
  $account=Get-ADUser -Identity $SamAccountName -ErrorAction SilentlyContinue
  if (-not $account) {
    if ($WhatIfPreference -and $CreateAccount) { Write-Warning 'WhatIf: account not created; skipping PHS delegation simulation. Run delegation separately after account exists.'; return }
    throw "Account $SamAccountName not found. Create it first."
  }
  if ([string]::IsNullOrWhiteSpace($ADSyncConfigPath)) { throw 'Provide -ADSyncConfigPath to a verified ADSyncConfig.psm1 file.' }
  if (-not (Test-Path -LiteralPath $ADSyncConfigPath -PathType Leaf)) { throw "ADSyncConfig module not found: $ADSyncConfigPath" }
  Import-Module -Name $ADSyncConfigPath -ErrorAction Stop
  $cmd=Get-Command Set-ADSyncPasswordHashSyncPermissions -ErrorAction Stop
  if (-not $cmd.Parameters.ContainsKey('ADConnectorAccountDN')) { throw 'Installed ADSyncConfig does not expose -ADConnectorAccountDN. Check the version and adapt using Microsoft documentation.' }
  $args=@{ADConnectorAccountDN=$account.DistinguishedName; ErrorAction='Stop'}
  if ($WhatIfPreference) {
    if (-not $cmd.Parameters.ContainsKey('WhatIf')) { throw 'This ADSyncConfig version has no -WhatIf; refusing to simulate.' }
    $args.WhatIf=$true
    Write-Host 'Simulating PHS delegation (review forest/domain scope and output):'
    & $cmd @args
  } elseif ($PSCmdlet.ShouldProcess("AD forest containing $($domain.DNSRoot)",'Delegate PHS replication permissions to connector account')) {
    Write-Warning 'PHS grants sensitive replication permissions at domain roots. Confirm forest-wide scope and authorization.'
    & $cmd @args
    Write-Host 'Delegation command completed. Verify effective ACLs and PHS function before production.'
  }
}
