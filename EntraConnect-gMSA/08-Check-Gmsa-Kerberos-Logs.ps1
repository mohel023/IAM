#requires -Version 5.1
<#
.SYNOPSIS
 Read-only follow-up diagnostic for failed gMSA Test-ADServiceAccount.
 Run elevated on the target Entra Connect server.
.EXAMPLE
 .\08-Check-Gmsa-Kerberos-Logs.ps1 -Identity 'gmsaEntraSync01'
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Identity,[int]$Minutes=120)
$ErrorActionPreference='Continue'
Write-Host '=== gMSA test (verbose) ==='
Test-ADServiceAccount -Identity $Identity -Verbose
Write-Host '=== Kerberos policy values (read-only) ==='
$paths=@(
 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters',
 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters'
)
foreach($path in $paths){
 if(Test-Path -LiteralPath $path){
  $item=Get-ItemProperty -LiteralPath $path
  Write-Host "Path: $path"
  foreach($name in @('SupportedEncryptionTypes','DefaultDomainSupportedEncTypes')){
   $p=$item.PSObject.Properties[$name]
   if($null -ne $p){
    $raw=[uint32]$p.Value
    Write-Host ("{0}: Decimal={1} Hex=0x{2:X8}" -f $name,$raw,$raw)
   }
  }
 }else{Write-Host "Not configured: $path"}
}
Write-Host '=== Available Kerberos / Netlogon / gMSA logs ==='
$logs=@(Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
 Where-Object {$_.LogName -match 'Kerberos|Netlogon|ServiceAccount|Kds'} |
 Select-Object LogName,IsEnabled)
$logs | Format-Table -AutoSize
Write-Host '=== Recent warnings/errors from available logs ==='
$since=(Get-Date).AddMinutes(-[math]::Abs($Minutes))
foreach($log in @($logs | Where-Object IsEnabled)){
 try {
  Get-WinEvent -FilterHashtable @{LogName=$log.LogName;StartTime=$since;Level=@(2,3)} -MaxEvents 30 -ErrorAction Stop |
   Select-Object TimeCreated,Id,LevelDisplayName,ProviderName,Message | Format-List
 }catch{Write-Verbose "No matching events or log unavailable: $($log.LogName)"}
}
Write-Warning 'Do not publish unredacted output: logs can expose internal AD details. No configuration changes were made.'
