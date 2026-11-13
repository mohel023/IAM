#requires -Version 5.1
<#
.SYNOPSIS
 Read-only AD inventory for Entra Connect sourceAnchor decision.
 No writes, no export, no files generated.
.EXAMPLE
 .\10-ReadOnly-SourceAnchor-Inventory.ps1 -SearchBase 'OU=Pilot,DC=example,DC=com'
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$SearchBase,
 [string]$Server,
 [int]$SampleSize=10
)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
$params=@{SearchBase=$SearchBase;LDAPFilter='(&(objectCategory=person)(objectClass=user))';Properties=@('msDS-ConsistencyGuid','userPrincipalName','mail','proxyAddresses');ResultSetSize=$null}
if($Server){$params.Server=$Server}
$users=@(Get-ADUser @params)
$populated=@($users | Where-Object {$null -ne $_.'msDS-ConsistencyGuid' -and @($_.'msDS-ConsistencyGuid').Count -gt 0})
$missing=@($users | Where-Object {$null -eq $_.'msDS-ConsistencyGuid' -or @($_.'msDS-ConsistencyGuid').Count -eq 0})
$duplicateUpn=@($users | Where-Object {$_.UserPrincipalName} | Group-Object UserPrincipalName | Where-Object Count -gt 1)
Write-Host 'READ-ONLY INVENTORY. Output contains aggregate counts only.'
[pscustomobject]@{
 UsersInScope=$users.Count
 ConsistencyGuidPopulated=$populated.Count
 ConsistencyGuidBlank=$missing.Count
 DuplicateUpnGroups=$duplicateUpn.Count
 ScopeWasExplicitlyProvided=$true
} | Format-List
Write-Warning 'Scope counts are not a cloud matching validation. Review all forests, tenant users, current sourceAnchor and intended OU filters before proceeding.'
