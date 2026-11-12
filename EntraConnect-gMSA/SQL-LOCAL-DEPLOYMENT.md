# Local SQL deployment — Entra Connect Sync

## Confirmed design
- Microsoft Entra Connect Sync: custom installation.
- SQL database: local to the Connect server (not remote SQL).
- ADSync service identity: dedicated gMSA.
- AD DS connector: separate least-privilege AD user.
- Do not commit environment-specific information or secrets.

## Important distinction
"Local SQL" does not identify the SQL edition or topology by itself. Confirm whether setup uses the bundled SQL Server Express/LocalDB option or an already installed full SQL Server instance. The wizard's **Use an existing SQL Server** option is for a separately provided instance, including one on the same machine.

## Before installing
1. Confirm OS/version prerequisites for the current supported Entra Connect Sync build.
2. Confirm the chosen SQL edition and capacity limits are appropriate for the AD object count and supported product configuration.
3. Confirm KDS root key replication and that the Connect server computer can retrieve the gMSA password.
4. Install and test the gMSA on the Connect server with 03-Test-GmsaOnConnectServer.ps1.
5. Use the installer's custom installation, select **Use an existing service account > Managed Service Account** and specify DOMAIN\\gmsaName$.
6. Do not select **Use an existing SQL Server** unless connecting to a separately installed SQL instance. For bundled SQL, leave it unchecked.
7. Use the installer to configure ADSync database permissions; do not grant Domain Admin, Enterprise Admin or permanent SQL sysadmin to the runtime gMSA.
8. Configure the separate AD DS connector account and delegate permissions only for the features approved by the identity architecture.
9. Check ADSync service start, scheduler, synchronization errors and accidental deletion protection before enabling exports.
10. Store database backup, encryption key and recovery procedures securely; test restore under change control.

## Stop conditions
- gMSA Test-ADServiceAccount fails.
- SQL choice/edition is unconfirmed.
- Existing active sync server or export topology is unknown.
- AD connector permissions or OU filtering not approved.

## Official references
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-custom
https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/reference-connect-accounts-permissions
