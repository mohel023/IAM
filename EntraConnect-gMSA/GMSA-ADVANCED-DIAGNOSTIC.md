# Advanced gMSA diagnostics after reboot

Use when the target host was rebooted, its secure channel works, the gMSA exists, direct authorization is confirmed, a KDS root key exists, but Test-ADServiceAccount still returns False.

Run in elevated Windows PowerShell 5.1 on the **target Entra Connect server**:

```powershell
.\07-Diagnose-Gmsa-Advanced.ps1 -Identity 'gmsaEntraSync01'
```

Checks: local gMSA test, secure channel, DC discovery, read-only repadmin replication summary, computer GPO summary, Kerberos policy registry values, gMSA authorization on each reachable DC, and recent Netlogon/System events.

Local CSV and JSON files are saved under `%TEMP%\EntraConnect-gMSA-Diagnostics`. They may contain sensitive internal hostnames, domain names, DNs and event text. Do **not** commit or upload these reports to this public repository. Review and redact before sharing.

An event log with no matching errors does not establish success. Replication summary and KDS presence do not prove password retrieval works. The script makes no configuration changes and does not install or reset accounts.

Recommended next action: inspect redacted warning/failure rows and relevant event IDs before considering any AD/Kerberos change.