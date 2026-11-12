# Entra Connect Sync — secure installation baseline

## Confidentiality
This repository must not contain real tenant IDs, server names, internal DNS domains, actual account names, passwords, gMSA principals, SQL hosts, screenshots or architecture documents. Use placeholders and keep the environment-specific mapping in an approved internal vault.

## Separation of duties
1. Installation administrator: authorized local admin on Connect server; temporary SQL provisioning privileges only if required. Entra role Hybrid Identity Administrator when prompted. Remove temporary elevation afterward.
2. ADSync engine: dedicated gMSA; no Domain Admin or Enterprise Admin. Only the Connect server(s) explicitly authorized to retrieve its password. Do not reuse across unrelated services.
3. AD DS connector: separate ordinary AD user with least privileges delegated for chosen sync features. Do not confuse it with ADSync engine identity.
4. Entra connector: provisioned by the Entra Connect wizard, not by the AD user script.

## Prerequisites / approval gates
- Confirm this is a new custom installation, supported Connect Sync version and OS, and correct forest/domain.
- Confirm KDS root key exists and is fully replicated. Do not use the 10-hour backdating shortcut in production.
- Confirm service account OU and short sAMAccountNames (<=20 chars for users; gMSA name including $ must fit).
- Check AD DS schema/DC support for gMSA, connectivity, time sync, DNS, security baselines, SQL topology and firewall.
- Approve PHS, PTA, password writeback, Exchange hybrid, staging mode, OU filtering and source anchor explicitly.
- If remote SQL is used, arrange required SQL login/database ownership with DBA; no permanent SQL sysadmin for runtime.
- Never enable export to production until join rules, source anchor, OU scoping, accidental deletion protection and staging validation are approved.
- Confirm that existing tenant sync state is understood; do not activate an additional exporting sync server accidentally.

## Installer
Custom installation > Install required components > Use an existing service account > Managed Service Account.
Enter DOMAIN\\shortGmsaName$ (no manually managed password).
At Connect your directories, configure the separate AD DS connector user.
Do not change ADSync service identity after installation: unsupported.

## Validation
Run 00-Test-Prerequisites.ps1 and 01-New-Gmsa.ps1 -WhatIf before creation.
Run 03-Test-GmsaOnConnectServer.ps1 on the intended Connect host.
Review connector delegated permissions and audit logs.
After installation check Get-Service ADSync and Get-ADSyncScheduler; validate staging and connector errors before allowing exports.

## Microsoft references
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-accounts-permissions
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/concept-adsync-service-account
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-custom
