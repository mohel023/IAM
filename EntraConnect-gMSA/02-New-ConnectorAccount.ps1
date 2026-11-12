#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess=$true,ConfirmImpact='High')]
param(
 [Parameter(Mandatory)][ValidateLength(1,20)][string]$SamAccountName,
 [Parameter(Mandatory)][string]$TargetOU
)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
$null=Get-ADOrganizationalUnit -Identity $TargetOU
if(Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'"){throw 'Account already exists.'}
if($PSCmdlet.ShouldProcess($SamAccountName,'Create connector user')){
 $secret=Read-Host 'Connector account password' -AsSecureString
 New-ADUser -Name $SamAccountName -SamAccountName $SamAccountName -Path $TargetOU -AccountPassword $secret -Enabled $true -Description 'Entra Connect AD DS connector: permissions delegated separately'
 Write-Warning 'Delegate only Microsoft-documented connector rights; do not use Domain Admin.'
}
