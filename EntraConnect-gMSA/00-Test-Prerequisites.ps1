#Requires -Modules ActiveDirectory
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$ConnectServer,
 [Parameter(Mandatory)][ValidateLength(1,19)][string]$GmsaName
)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
$domain=Get-ADDomain
$computer=Get-ADComputer -Identity $ConnectServer -Properties DNSHostName
$keys=@(Get-KdsRootKey)
$existing=Get-ADServiceAccount -Identity $GmsaName -ErrorAction SilentlyContinue
[pscustomobject]@{
 Domain=$domain.DNSRoot
 DomainMode=$domain.DomainMode
 ConnectServer=$computer.DNSHostName
 KdsRootKeyCount=$keys.Count
 GmsaExists=[bool]$existing
}
if($keys.Count -eq 0){Write-Warning 'KDS root key missing: stop and coordinate creation/replication with AD team.'}
