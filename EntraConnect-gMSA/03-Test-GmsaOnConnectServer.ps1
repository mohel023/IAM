#Requires -RunAsAdministrator
#Requires -Modules ActiveDirectory
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateLength(1,19)][string]$GmsaName)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
$account=Get-ADServiceAccount -Identity $GmsaName -Properties PrincipalsAllowedToRetrieveManagedPassword
if($account.ObjectClass -ne 'msDS-GroupManagedServiceAccount'){throw 'Specified account is not a gMSA.'}
$computer=Get-ADComputer -Identity $env:COMPUTERNAME
Write-Host "Local server: $($computer.Name)"
Write-Host 'Confirm this computer is authorized to retrieve the managed password.'
Install-ADServiceAccount -Identity $GmsaName
if(-not (Test-ADServiceAccount -Identity $GmsaName)){throw 'gMSA validation failed; stop installation.'}
Write-Host 'PASS: gMSA installation and local test succeeded.'
