#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Identity,[string]$DC,[string]$OutputDirectory="$env:TEMP\EntraConnect-gMSA-Diagnostics")
$ErrorActionPreference='Stop'
$results=@()
function Check($Name,$Block) { try { & $Block } catch { $script:results += [pscustomobject]@{Check=$Name;Status='WARN';Details=$_.Exception.Message} } }
function Resolve-PrincipalDN($Principal) {
 if ($null -eq $Principal) { return $null }
 if ($Principal -is [string]) { return $Principal }
 if ($Principal.PSObject.Properties['DistinguishedName']) { return [string]$Principal.DistinguishedName }
 return [string]$Principal
}
function Add($Name,$Status,$Details) { $script:results += [pscustomobject]@{Check=$Name;Status=$Status;Details=$Details} }
Check 'Domain membership' { $x=Get-CimInstance Win32_ComputerSystem; Add 'Domain membership' $(if($x.PartOfDomain){'PASS'}else{'FAIL'}) "Joined=$($x.PartOfDomain); Domain=$($x.Domain)" }
Check 'Secure channel' { $x=Test-ComputerSecureChannel; Add 'Secure channel' $(if($x){'PASS'}else{'FAIL'}) "Result=$x" }
Check 'AD module' { Import-Module ActiveDirectory -ErrorAction Stop; Add 'AD module' 'PASS' 'Imported' }
if(Get-Module ActiveDirectory) {
 Check 'DC discovery' { if(-not $DC){$DC=(Get-ADDomainController -Discover).HostName}; Add 'DC discovery' 'INFO' $DC }
 if($DC){ foreach($port in @(88,389,9389)){ $p=$port; Check "TCP $p" { $ok=Test-NetConnection $DC -Port $p -InformationLevel Quiet -WarningAction SilentlyContinue; Add "TCP $p" $(if($ok){'PASS'}else{'FAIL'}) "DC=$DC; Reachable=$ok" } } }
 $adArgs=@{}; if($DC){$adArgs.Server=$DC}
 Check 'gMSA AD object' {
  $g=Get-ADServiceAccount -Identity $Identity -Properties Enabled,PrincipalsAllowedToRetrieveManagedPassword,KerberosEncryptionType,msDS-SupportedEncryptionTypes -ErrorAction Stop @adArgs
  $c=Get-ADComputer -Identity $env:COMPUTERNAME -Properties KerberosEncryptionType,msDS-SupportedEncryptionTypes -ErrorAction Stop @adArgs
  $allowed=@($g.PrincipalsAllowedToRetrieveManagedPassword | ForEach-Object { Resolve-PrincipalDN $_ })
  Add 'gMSA enabled' $(if($g.Enabled){'PASS'}else{'FAIL'}) "Enabled=$($g.Enabled); Class=$($g.ObjectClass)"
  $direct = @($allowed | Where-Object { $_ -and ($_.Trim() -ieq $c.DistinguishedName.Trim()) }).Count -gt 0
  Add 'Direct host authorization' $(if($direct){'PASS'}else{'WARN'}) "Direct=$direct; Allowed=$($allowed -join ';'); group-based membership not evaluated"
  Add 'Encryption (informational)' 'INFO' "gMSA=$($g.'msDS-SupportedEncryptionTypes'); Computer=$($c.'msDS-SupportedEncryptionTypes'); blank is not proof of mismatch"
 }
 Check 'KDS keys' { $keys=@(Get-KdsRootKey); Add 'KDS keys' $(if($keys.Count){'PASS'}else{'FAIL'}) "Count=$($keys.Count); check replication separately" }
 Check 'DC consistency' { foreach($item in @(Get-ADDomainController -Filter *)){ try { $g=Get-ADServiceAccount -Identity $Identity -Server $item.HostName -Properties PrincipalsAllowedToRetrieveManagedPassword; $allowed=@($g.PrincipalsAllowedToRetrieveManagedPassword | ForEach-Object { Resolve-PrincipalDN $_ }); Add "DC $($item.HostName)" 'INFO' ($allowed -join ';') } catch { Add "DC $($item.HostName)" 'WARN' $_.Exception.Message } } }
}
Check 'Current computer Kerberos context' {
 $ticketOutput = (& klist.exe -li 0x3e7 2>&1 | Out-String)
 $summary = @($ticketOutput -split "`r?`n" | Where-Object { $_ -match 'Kdc Called:|Client:|Server:' } | Select-Object -First 12)
 Add 'Current computer Kerberos context' 'INFO' ($summary -join ' | ')
}
Check 'Local gMSA test' { $ok=Test-ADServiceAccount -Identity $Identity -WarningAction SilentlyContinue; Add 'Local gMSA test' $(if($ok){'PASS'}else{'FAIL'}) "Result=$ok" }
$events=@()
foreach($log in @('Microsoft-Windows-ManagedServiceAccount/Operational','Microsoft-Windows-Security-Netlogon/Operational','System')){
 $logName=$log
 Check "Log $logName" { $info=Get-WinEvent -ListLog $logName -ErrorAction Stop; $ev=@(Get-WinEvent -FilterHashtable @{LogName=$logName;StartTime=(Get-Date).AddHours(-2)} -MaxEvents 30 -ErrorAction SilentlyContinue); $events+=@($ev | Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message); Add "Log $logName" 'INFO' "Enabled=$($info.IsEnabled); Count=$($ev.Count)" }
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$csv=Join-Path $OutputDirectory "GmsaChecks-$stamp.csv"
$json=Join-Path $OutputDirectory "GmsaEvents-$stamp.json"
$results | Export-Csv $csv -NoTypeInformation -Encoding UTF8
$events | ConvertTo-Json -Depth 5 | Set-Content $json -Encoding UTF8
$results | Format-Table -AutoSize -Wrap
Write-Host "NOTE: missing ManagedServiceAccount log can be normal on this Windows build. Check Security-Netlogon events."
Write-Host "Local reports: $csv ; $json"
Write-Warning 'Reports may contain internal AD names and event messages. Redact before sharing. Do not upload to public GitHub.'