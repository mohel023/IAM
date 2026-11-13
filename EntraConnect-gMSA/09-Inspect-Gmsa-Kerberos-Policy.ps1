#requires -Version 5.1
<#
.SYNOPSIS
 Read-only inspection of gMSA, computer Kerberos encryption attributes, and effective policy.
 Run on the target Entra Connect server in elevated Windows PowerShell 5.1.
.EXAMPLE
 .\09-Inspect-Gmsa-Kerberos-Policy.ps1 -Identity 'gmsaEntraSync01'
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Identity)
$ErrorActionPreference='Stop'
Import-Module ActiveDirectory
function Show-Mask([string]$Label,$Value){
 if($null -eq $Value){Write-Host "$Label : not configured";return}
 $n=[uint32]$Value
 $known=[ordered]@{DES_CBC_CRC=1;DES_CBC_MD5=2;RC4_HMAC=4;AES128_CTS_HMAC_SHA1=8;AES256_CTS_HMAC_SHA1=16}
 $names=@($known.Keys | Where-Object {($n -band [uint32]$known[$_]) -ne 0})
 Write-Host ("{0}: Decimal={1} Hex=0x{2:X8}; Known flags={3}" -f $Label,$n,$n,($names -join ','))
}
Write-Host '=== AD gMSA ==='
$g=Get-ADServiceAccount -Identity $Identity -Properties msDS-SupportedEncryptionTypes,KerberosEncryptionType,PrincipalsAllowedToRetrieveManagedPassword
Write-Host "Name: $($g.Name)"
Show-Mask 'gMSA msDS-SupportedEncryptionTypes' $g.'msDS-SupportedEncryptionTypes'
Write-Host '=== AD computer ==='
$c=Get-ADComputer -Identity $env:COMPUTERNAME -Properties msDS-SupportedEncryptionTypes,KerberosEncryptionType
Write-Host "Computer: $($c.Name)"
Show-Mask 'Computer msDS-SupportedEncryptionTypes' $c.'msDS-SupportedEncryptionTypes'
Write-Host '=== Local Kerberos policy ==='
foreach($p in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Kerberos\Parameters','HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Kerberos\Parameters')){
 if(Test-Path $p){
  $item=Get-ItemProperty $p
  foreach($key in @('SupportedEncryptionTypes','DefaultDomainSupportedEncTypes')){
   $prop=$item.PSObject.Properties[$key]
   if($null -ne $prop){Show-Mask "$p / $key" $prop.Value}
  }
 }
}
Write-Host '=== Netlogon gMSA error IDs (recent) ==='
try {
 Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Security-Netlogon/Operational';StartTime=(Get-Date).AddHours(-4);Id=@(9001,9002)} -MaxEvents 20 -ErrorAction Stop |
 Select-Object TimeCreated,Id,LevelDisplayName,Message | Format-List
}catch{Write-Warning "No matching events or log unavailable: $($_.Exception.Message)"}
Write-Host '=== Computer GPO HTML report ==='
$report=Join-Path $env:TEMP 'Gmsa-Kerberos-Computer-GPO.html'
& gpresult.exe /scope computer /h $report /f
Write-Host "Local report: $report"
Write-Warning 'Read-only. Do not change encryption values automatically. The report and event text can contain confidential internal information; do not commit to public GitHub.'
