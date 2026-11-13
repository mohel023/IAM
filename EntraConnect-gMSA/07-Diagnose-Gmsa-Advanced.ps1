#requires -Version 5.1
<#
.SYNOPSIS
 Read-only advanced gMSA diagnostics after reboot, KDS and direct authorization checks.
.EXAMPLE
 .\07-Diagnose-Gmsa-Advanced.ps1 -Identity 'gmsaEntraSync01'
.NOTES
 Run elevated on target Entra Connect server. Reports are local and may contain internal AD details.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Identity,[string]$OutputDirectory="$env:TEMP\EntraConnect-gMSA-Diagnostics",[int]$Minutes=120)
$ErrorActionPreference='Stop'
$rows=New-Object System.Collections.Generic.List[object]
$events=New-Object System.Collections.Generic.List[object]
function Add-Row([string]$Check,[string]$Status,[string]$Details) { $rows.Add([pscustomobject]@{Check=$Check;Status=$Status;Details=$Details}) }
function Try-Step([string]$Name,[scriptblock]$Action) { try { & $Action } catch { Add-Row $Name 'WARN' $_.Exception.Message } }
Import-Module ActiveDirectory -ErrorAction Stop
Try-Step 'Local gMSA test' { $ok=Test-ADServiceAccount -Identity $Identity -WarningAction SilentlyContinue -ErrorAction Stop; Add-Row 'Local gMSA test' $(if($ok){'PASS'}else{'FAIL'}) "Result=$ok" }
Try-Step 'Computer secure channel' { $ok=Test-ComputerSecureChannel -ErrorAction Stop; Add-Row 'Computer secure channel' $(if($ok){'PASS'}else{'FAIL'}) "Result=$ok" }
Try-Step 'DC discovery' { $dc=Get-ADDomainController -Discover -ErrorAction Stop; Add-Row 'DC discovery' 'INFO' $dc.HostName }
Try-Step 'AD replication summary' { $out=(& repadmin.exe /replsummary 2>&1 | Out-String); Add-Row 'AD replication summary' 'INFO' (($out -split "`r?`n" | Select-Object -Last 12) -join ' | ') }
Try-Step 'Local computer GPO summary' { $out=(& gpresult.exe /scope computer /r 2>&1 | Out-String); Add-Row 'Local computer GPO summary' 'INFO' (($out -split "`r?`n" | Where-Object {$_ -match 'Kerberos|Group Policy|Applied|Filtering|GPO|Strat'} | Select-Object -First 12) -join ' | ') }
Try-Step 'Kerberos registry policy' {
 $paths=@('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters','HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters')
 foreach($p in $paths) { if(Test-Path $p) { $v=Get-ItemProperty $p; $names=@($v.PSObject.Properties | Where-Object {$_.Name -notmatch '^PS'} | ForEach-Object { "$($_.Name)=$($_.Value)" }); Add-Row 'Kerberos registry policy' 'INFO' "$p : $($names -join '; ')" } else { Add-Row 'Kerberos registry policy' 'INFO' "$p not configured" } }
}
Try-Step 'Domain controller consistency' {
 $dcs=@(Get-ADDomainController -Filter * -ErrorAction Stop)
 foreach($dc in $dcs) {
  try {
   $g=Get-ADServiceAccount -Identity $Identity -Server $dc.HostName -Properties PrincipalsAllowedToRetrieveManagedPassword -ErrorAction Stop
   $a=@($g.PrincipalsAllowedToRetrieveManagedPassword | ForEach-Object { if($_ -is [string]){$_}else{$_.DistinguishedName} })
   Add-Row "DC $($dc.HostName)" 'INFO' "Allowed=$($a -join '; ')"
  } catch { Add-Row "DC $($dc.HostName)" 'WARN' $_.Exception.Message }
 }
}
$since=(Get-Date).AddMinutes(-[math]::Abs($Minutes))
foreach($log in @('Microsoft-Windows-Security-Netlogon/Operational','System')) {
 $name=$log
 Try-Step "Events $name" {
  $info=Get-WinEvent -ListLog $name -ErrorAction Stop
  $raw=@(Get-WinEvent -FilterHashtable @{LogName=$name;StartTime=$since} -MaxEvents 250 -ErrorAction SilentlyContinue)
  $filtered=@($raw | Where-Object { $_.Level -le 3 -or $_.ProviderName -match 'Kerberos|Netlogon|LsaSrv' } | Select-Object -First 100)
  foreach($e in $filtered) { $events.Add([pscustomobject]@{Log=$name;TimeCreated=$e.TimeCreated;Id=$e.Id;Level=$e.LevelDisplayName;Provider=$e.ProviderName;Message=$e.Message}) }
  Add-Row "Events $name" 'INFO' "Enabled=$($info.IsEnabled); RecentFiltered=$($filtered.Count)"
 }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$csv=Join-Path $OutputDirectory "GmsaAdvancedChecks-$stamp.csv"
$json=Join-Path $OutputDirectory "GmsaAdvancedEvents-$stamp.json"
$rows | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
$events | ConvertTo-Json -Depth 5 | Set-Content -Path $json -Encoding UTF8
$rows | Format-Table -AutoSize -Wrap
Write-Host "LOCAL REPORTS: $csv ; $json"
Write-Warning 'Do not upload raw reports to public GitHub. Redact domains, hostnames, DNs and event messages before sharing.'