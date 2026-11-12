#Requires -Modules ActiveDirectory
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SamAccountName)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
$u=Get-ADUser -Identity $SamAccountName -Properties Enabled,PasswordNeverExpires,MemberOf,Description
[pscustomobject]@{
 Name=$u.Name; SamAccountName=$u.SamAccountName; Enabled=$u.Enabled
 PasswordNeverExpires=$u.PasswordNeverExpires
 IsDomainAdminsMember=([bool](@($u.MemberOf) | Where-Object {$_ -match '^CN=Domain Admins,'}))
 Description=$u.Description
}
Write-Warning 'This is not a complete effective-permissions audit. Review nested groups and delegated ACLs separately.'
