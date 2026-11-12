#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [Parameter(Mandatory)][string]$ConnectServer,
 [Parameter(Mandatory)][ValidateLength(1,19)][string]$GmsaName,
 [Parameter(Mandatory)][string]$TargetOU
)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
if(-not @(Get-KdsRootKey).Count){throw 'KDS root key missing; coordinate with AD team.'}
$computer=Get-ADComputer -Identity $ConnectServer
$null=Get-ADOrganizationalUnit -Identity $TargetOU
if(Get-ADServiceAccount -Identity $GmsaName -ErrorAction SilentlyContinue){throw 'Account exists: inspect manually.'}
$dns=(Get-ADDomain).DNSRoot
if($PSCmdlet.ShouldProcess($GmsaName,'Create restricted gMSA')){
 New-ADServiceAccount -Name $GmsaName -SamAccountName "$GmsaName`$" -DNSHostName "$GmsaName.$dns" -Path $TargetOU -PrincipalsAllowedToRetrieveManagedPassword $computer -Description 'Entra Connect ADSync service'
 Write-Host 'On Connect server: Install-ADServiceAccount and Test-ADServiceAccount'
}
