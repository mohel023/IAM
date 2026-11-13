# AD DS Connector account + PHS delegation

This guide applies to Entra Connect Sync with **a separate gMSA for the ADSync Windows service** and a **normal AD user for the AD DS connector**. The connector account is not a gMSA and must not be Domain Admin.

## Before you begin
- Use a secured AD admin machine with RSAT ActiveDirectory, domain connectivity and ADWS (TCP 9389) access to a DC for the AD module.
- Verify target OU, account naming, and whether PHS is approved. If the forest contains multiple domains, review the full delegation scope with AD security owners.
- The script is designed to avoid publishing passwords or environment-specific names in this public repository.
- Obtain the official `ADSyncConfig.psm1` from your installed Entra Connect package; validate its source and dependencies. It can be run from an authorized AD admin host if needed.

## 1. Preview account creation
```powershell
.\05-New-ADDSConnector-PHS.ps1 -SamAccountName 'svcEntraAD' -AccountName 'SVC-T0-SFC-PRD-EntraConnect' -OU 'OU=ServiceAccounts,DC=example,DC=local' -CreateAccount -WhatIf
```

## 2. Create the account
```powershell
.\05-New-ADDSConnector-PHS.ps1 -SamAccountName 'svcEntraAD' -AccountName 'SVC-T0-SFC-PRD-EntraConnect' -OU 'OU=ServiceAccounts,DC=example,DC=local' -CreateAccount
```
The script securely prompts for a password. Store it in an approved vault. Follow your organization's password expiration and rotation policies; avoid unexpected password expiration without a rotation procedure.

## 3. Preview PHS delegation
```powershell
$module = 'C:\Program Files\Microsoft Azure Active Directory Connect\AdSyncConfig\ADSyncConfig.psm1'
.\05-New-ADDSConnector-PHS.ps1 -SamAccountName 'svcEntraAD' -DelegatePHS -ADSyncConfigPath $module -WhatIf
```

## 4. Apply PHS delegation (requires AD ACL modification rights)
```powershell
.\05-New-ADDSConnector-PHS.ps1 -SamAccountName 'svcEntraAD' -DelegatePHS -ADSyncConfigPath $module
```
Review confirmation carefully. `Set-ADSyncPasswordHashSyncPermissions` grants **Replicating Directory Changes** and **Replicating Directory Changes All** at domain roots; this is sensitive and may span domains in the forest. Do not grant broad admin roles as a substitute.

## 5. Inspect permissions (read-only)
```powershell
$root=(Get-ADDomain).DistinguishedName
$account=Get-ADUser svcEntraAD
$ids=@(
 '1131f6aa-9c07-11d1-f79f-00c04fc2dcd2', # Replicating Directory Changes
 '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2'  # Replicating Directory Changes All
)
(Get-Acl "AD:\$root").Access |
 Where-Object { $_.AccessControlType -eq 'Allow' -and $ids -contains $_.ObjectType.ToString().ToLowerInvariant() } |
 Select-Object IdentityReference,ObjectType,ActiveDirectoryRights
```
Check the identity matches the connector account. Repeat for every relevant domain. ACL inspection does not replace effective permission and PHS functional validation.

## 6. Entra Connect wizard
In **Connect your directories**, choose **Use existing account**, enter `DOMAIN\svcEntraAD` and the vault password. Verify PHS status separately from object synchronization.

## Notes
- No automatic password writeback, Exchange writeback or `msDS-ConsistencyGuid` permissions are granted by this script. Assess these features separately.
- If ADWS is unavailable on the admin host, resolve connectivity or run from an authorized host; don't weaken DC firewall rules globally.
- `-WhatIf` for delegation requires the installed ADSyncConfig cmdlet to support it; the script stops if it does not.
- Official Microsoft references:
  - https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-configure-ad-ds-connector-account
  - https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-adsyncconfig
