# Entra Connect Sync — gMSA deployment

For a fresh **custom** Entra Connect Sync installation. Do not commit passwords, internal hostnames or tenant identifiers.

## Accounts
- Installation: authorized administrator with local admin rights.
- ADSync service: dedicated gMSA (created by 01-New-Gmsa.ps1).
- AD DS connector: separate least-privileged domain user (02-New-ConnectorAccount.ps1).
- Entra connector: configured separately by the wizard.

## Steps
1. Confirm target Connect server is domain joined, RSAT AD module works and a KDS root key exists and has replicated. Never bypass KDS replication delays in production.
2. Select a short gMSA sAMAccountName (e.g. gmsaEntraSync), the Connect server computer name and the existing service accounts OU.
3. Run 00-Test-Prerequisites.ps1.
4. Run 01-New-Gmsa.ps1 -WhatIf, review, then run without -WhatIf after approval.
5. On the Connect server run Install-ADServiceAccount -Identity gmsaEntraSync and Test-ADServiceAccount -Identity gmsaEntraSync (expect True).
6. In the installer select **Use an existing service account > Managed Service Account**, enter DOMAIN\gmsaEntraSync$; no manually managed password.
7. Prepare the separate AD DS connector user and delegate only documented rights based on PHS/writeback choices.
8. Confirm SQL permissions (especially remote SQL) and validate synchronization before production.

Example:
```powershell
.\00-Test-Prerequisites.ps1 -ConnectServer 'SYNC01' -GmsaName 'gmsaEntraSync'
.\01-New-Gmsa.ps1 -ConnectServer 'SYNC01' -GmsaName 'gmsaEntraSync' -TargetOU 'OU=Service Accounts,DC=example,DC=local' -WhatIf
.\01-New-Gmsa.ps1 -ConnectServer 'SYNC01' -GmsaName 'gmsaEntraSync' -TargetOU 'OU=Service Accounts,DC=example,DC=local'
```

Note: Do not change the ADSync service identity after installation.

Microsoft documentation:
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/concept-adsync-service-account
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-accounts-permissions
