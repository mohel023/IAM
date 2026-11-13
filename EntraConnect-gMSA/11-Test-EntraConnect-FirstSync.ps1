#requires -Version 5.1
<#
.SYNOPSIS
 Read-only preflight for first Entra Connect Sync deployment into a tenant with existing cloud users.
.DESCRIPTION
 Enumerates scoped AD users and tenant users, flags potential soft/hard matches and collisions,
 and generates local CSV/JSON/Markdown recommendations. Does NOT modify AD, Entra, Intune,
 the Entra Connect wizard, or sourceAnchor values. No credentials are stored.
.EXAMPLE
 .\11-Test-EntraConnect-FirstSync.ps1 -SearchBase 'OU=Pilot,DC=example,DC=com'
#>
[CmdletBinding()]
param(
 [Parameter(Mandatory)][string]$SearchBase,
 [string]$AdServer,
 [string]$OutputDirectory = (Join-Path $env:TEMP ("EntraConnect-Preflight-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),
 [switch]$IncludeDisabledADUsers
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

function Norm([object]$v) {
 if($null -eq $v){return ''}
 return ([string]$v).Trim().ToLowerInvariant()
}
function Anchor([object]$guidBytes,[guid]$objectGuid) {
 if($null -ne $guidBytes -and @($guidBytes).Count -eq 16) {
  return [Convert]::ToBase64String([byte[]]$guidBytes)
 }
 return [Convert]::ToBase64String($objectGuid.ToByteArray())
}
function Add-Index([hashtable]$map,[string]$key,[object]$value) {
 if([string]::IsNullOrWhiteSpace($key)){return}
 if(-not $map.ContainsKey($key)){$map[$key]=New-Object System.Collections.ArrayList}
 [void]$map[$key].Add($value)
}
function Get-Matches([hashtable]$map,[string]$key) {
 if($map.ContainsKey($key)){return @($map[$key].ToArray())}
 return @()
}
function Get-GraphAllUsers {
 $uri='/v1.0/users?$select=id,userPrincipalName,mail,proxyAddresses,onPremisesImmutableId,onPremisesSyncEnabled,accountEnabled,assignedLicenses&$top=999'
 $all=New-Object System.Collections.ArrayList
 do {
  $page=Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
  foreach($u in @($page.value)){[void]$all.Add($u)}
  $uri=$page.'@odata.nextLink'
 }while($uri)
 return @($all.ToArray())
}

$ctx=Get-MgContext
if($null -eq $ctx -or -not $ctx.TenantId){throw 'Connect to Microsoft Graph first: Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All"'}
if(-not (@($ctx.Scopes) -contains 'User.Read.All' -or @($ctx.Scopes) -contains 'Directory.Read.All')) {
 throw 'Missing delegated User.Read.All or Directory.Read.All. Reconnect with approved read-only scopes.'
}
Write-Host 'Collecting AD users (read-only)...'
$adArgs=@{SearchBase=$SearchBase;LDAPFilter='(&(objectCategory=person)(objectClass=user))';Properties='*';ResultSetSize=$null}
if($AdServer){$adArgs.Server=$AdServer}
$adUsers=@(Get-ADUser @adArgs | Where-Object {$IncludeDisabledADUsers -or $_.Enabled})
Write-Host 'Collecting cloud users (read-only)...'
$cloudUsers=@(Get-GraphAllUsers)
if($cloudUsers.Count -eq 0){throw 'Cloud inventory returned no users. Refusing to treat this as a safe empty tenant.'}

$cloudByUpn=@{}; $cloudByAddress=@{}; $cloudByAnchor=@{}
foreach($c in $cloudUsers){
 Add-Index $cloudByUpn (Norm $c.userPrincipalName) $c
 Add-Index $cloudByAddress (Norm $c.mail) $c
 foreach($p in @($c.proxyAddresses)){
  if($null -ne $p -and [string]$p -match '^(?i:smtp):(.+)$'){
   Add-Index $cloudByAddress (Norm $Matches[1]) $c
  }
 }
 Add-Index $cloudByAnchor (Norm $c.onPremisesImmutableId) $c
}
$adUpnCounts=@{}; $adAddressCounts=@{}
foreach($a in $adUsers){
 $u=Norm $a.UserPrincipalName
 if($u){if(-not $adUpnCounts.ContainsKey($u)){$adUpnCounts[$u]=0};$adUpnCounts[$u]++}
 $emails=@(Norm $a.mail)
 foreach($p in @($a.proxyAddresses)){
  if($null -ne $p -and [string]$p -match '^(?i:smtp):(.+)$'){$emails+=Norm $Matches[1]}
 }
 foreach($e in @($emails | Where-Object {$_} | Select-Object -Unique)){
  if(-not $adAddressCounts.ContainsKey($e)){$adAddressCounts[$e]=0};$adAddressCounts[$e]++
 }
}

$rows=New-Object System.Collections.ArrayList
foreach($a in $adUsers){
 $upn=Norm $a.UserPrincipalName
 $addresses=@(Norm $a.mail)
 foreach($p in @($a.proxyAddresses)){
  if($null -ne $p -and [string]$p -match '^(?i:smtp):(.+)$'){$addresses+=Norm $Matches[1]}
 }
 $addresses=@($addresses | Where-Object {$_} | Select-Object -Unique)
 $candidates=@{}
 foreach($c in @(Get-Matches $cloudByUpn $upn)){ $candidates[[string]$c.id]=$c }
 foreach($email in $addresses){
  foreach($c in @(Get-Matches $cloudByAddress $email)){ $candidates[[string]$c.id]=$c }
 }
 $anchor=Anchor $a.'msDS-ConsistencyGuid' $a.ObjectGUID
 $anchorMatches=@(Get-Matches $cloudByAnchor (Norm $anchor))
 foreach($c in $anchorMatches){$candidates[[string]$c.id]=$c}
 $candidateList=@($candidates.Values)
 $adDup=($upn -and $adUpnCounts[$upn] -gt 1)
 foreach($email in $addresses){if($adAddressCounts[$email] -gt 1){$adDup=$true}}
 $state='NO_CLOUD_MATCH';$recommend='Review intended creation and OU scope before export.'
 if($adDup){$state='AD_DUPLICATE';$recommend='NO-GO: duplicate AD UPN/SMTP in selected scope.'}
 elseif($candidateList.Count -gt 1){$state='MULTIPLE_CLOUD_CANDIDATES';$recommend='NO-GO: multiple cloud accounts share identifiers; investigate manually.'}
 elseif($candidateList.Count -eq 1){
  $c=$candidateList[0]
  if($c.onPremisesSyncEnabled -eq $true){$state='CLOUD_ALREADY_SYNCED';$recommend='NO-GO: investigate existing sync authority/connector.'}
  elseif($c.onPremisesImmutableId -and (Norm $c.onPremisesImmutableId) -ne (Norm $anchor)){
   $state='IMMUTABLE_ID_CONFLICT';$recommend='NO-GO: cloud immutable ID differs from proposed anchor. Do not overwrite.'
  }
  elseif($anchorMatches.Count -eq 1){
   $state='ANCHOR_MATCH_REVIEW';$recommend='Validate ownership and join rules; existing anchor match is not an approval to export.'
  }else{
   $state='SOFT_MATCH_CANDIDATE';$recommend='Validate UPN/SMTP, admin status, licenses, PHS impact and takeover of cloud-managed attributes.'
  }
 }
 if(-not $upn -and $state -eq 'NO_CLOUD_MATCH'){$state='MISSING_AD_UPN';$recommend='NO-GO: no UPN for AD object.'}
 $c=$null
 if($candidateList.Count -eq 1){$c=$candidateList[0]}
 [void]$rows.Add([pscustomobject]@{
  AdSamAccountName=$a.SamAccountName;AdDistinguishedName=$a.DistinguishedName
  AdUPN=$a.UserPrincipalName;AdMail=$a.mail
  AdObjectGuid=[string]$a.ObjectGUID
  AdConsistencyGuidPopulated=($null -ne $a.'msDS-ConsistencyGuid' -and @($a.'msDS-ConsistencyGuid').Count -eq 16)
  ProposedAnchorBase64=$anchor
  CloudCandidateCount=$candidateList.Count
  CloudId=$(if($c){$c.id}else{''})
  CloudUPN=$(if($c){$c.userPrincipalName}else{''})
  CloudOnPremisesImmutableId=$(if($c){$c.onPremisesImmutableId}else{''})
  CloudOnPremisesSyncEnabled=$(if($c){$c.onPremisesSyncEnabled}else{$null})
  CloudLicensed=$(if($c){@($c.assignedLicenses).Count -gt 0}else{$null})
  Finding=$state;Recommendation=$recommend
 })
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$csv=Join-Path $OutputDirectory 'User-Matching-Review-CONFIDENTIAL.csv'
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
$groups=@($rows | Group-Object Finding | Sort-Object Name | ForEach-Object {
 [pscustomobject]@{Finding=$_.Name;Count=$_.Count}
})
$blockers=@($rows | Where-Object {$_.Finding -in @('AD_DUPLICATE','MULTIPLE_CLOUD_CANDIDATES','CLOUD_ALREADY_SYNCED','IMMUTABLE_ID_CONFLICT','MISSING_AD_UPN')})
$summary=[ordered]@{
 Timestamp=(Get-Date).ToString('o')
 TenantId=$ctx.TenantId
 Scope=$SearchBase
 AdUsers=$adUsers.Count
 CloudUsers=$cloudUsers.Count
 Findings=$groups
 Blockers=$blockers.Count
 Decision='NO-GO UNTIL MANUAL CLOUD MATCHING AND EXPORT REVIEW'
 Caveats=@(
  'Read-only analysis; no proof of actual Entra Connect join outcomes.',
  'No evaluation of cloud role/PIM membership, device Intune assignments, Exchange recipient conflicts, all forests, or existing sync engines.',
  'Proposed sourceAnchor assumes msDS-ConsistencyGuid when populated, otherwise objectGUID; confirm actual wizard behavior.',
  'Staging mode prevents cloud exports but does not guarantee no AD-side writes.',
  'A soft match can change cloud account source of authority and PHS may change cloud password behavior.'
 )
}
$summaryPath=Join-Path $OutputDirectory 'Summary-CONFIDENTIAL.json'
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryPath -Encoding UTF8
$md=Join-Path $OutputDirectory 'Recommendations-CONFIDENTIAL.md'
$lines=@(
 '# First-sync preflight — preliminary, not an approval',
 '',
 "AD users in scope: $($adUsers.Count)",
 "Cloud users: $($cloudUsers.Count)",
 "Blocking findings: $($blockers.Count)",
 '',
 '## Findings'
)
foreach($g in $groups){$lines+=("- {0}: {1}" -f $g.Finding,$g.Count)}
$lines+=@(
 '',
 '## Mandatory manual checks',
 '- Confirm there is no other active Entra Connect or Cloud Sync instance.',
 '- Confirm one-person-one-AD-object versus multi-forest topology and sourceAnchor in HLD.',
 '- Validate all existing cloud identities, especially admin/PIM, licensed and Intune-enrolled users.',
 '- Confirm UPN/SMTP matches, cloud immutable IDs, Exchange proxy address collisions and AD OU exclusions.',
 '- Confirm PHS impact on sign-in/passwords and protect cloud-only admin accounts.',
 '- Save pre-change attribute snapshots securely; test staging and inspect pending exports before enabling export.',
 '- Staging mode is not a complete rollback: AD writes may occur and cloud exports are not automatically reversible.',
 '',
 '**Decision: NO-GO until manual review and approved change plan.**'
)
$lines | Set-Content -Path $md -Encoding UTF8
$groups | Format-Table -AutoSize
Write-Host "AD users: $($adUsers.Count) | Cloud users: $($cloudUsers.Count) | Blockers: $($blockers.Count)"
Write-Host "Local confidential outputs: $OutputDirectory"
Write-Warning 'DO NOT commit local outputs to public GitHub. No AD/Entra changes were made.'
