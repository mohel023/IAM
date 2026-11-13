# gMSA Kerberos and log follow-up

After reboot, direct computer authorization and KDS key visibility are confirmed, but the local gMSA test still fails.

Run **elevated Windows PowerShell 5.1** on the intended Entra Connect host:

```powershell
.\08-Check-Gmsa-Kerberos-Logs.ps1 -Identity 'gmsaEntraSync01'
```

This script runs Test-ADServiceAccount -Verbose, prints decimal and hexadecimal Kerberos registry policy values (if present), discovers available Netlogon/Kerberos/gMSA event logs, and displays recent warning/error events.

**Read-only**: no GPO changes, no AD object changes, no gMSA installation, no KDS modifications. The decimal value 2147483640 alone does **not** establish a Kerberos incompatibility; interpret the effective policy and event IDs first.

For replication, run `repadmin /replsummary` and `repadmin /showrepl` on a domain controller with the required tools; absence of repadmin on the Connect host does not prove replication failure.

Redact names, DNs and event messages before sharing. Never commit diagnostic outputs to the public repository.
