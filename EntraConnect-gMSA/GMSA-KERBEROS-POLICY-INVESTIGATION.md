# Kerberos encryption mismatch — gMSA follow-up

The target server logged Netlogon events **9001** (gMSA encryption compatibility) and **9002** (managed service account add failed: context did not match target). These are diagnostic clues, not permission to weaken Kerberos settings.

## Run (elevated Windows PowerShell 5.1 on Entra Connect server)

```powershell
.\09-Inspect-Gmsa-Kerberos-Policy.ps1 -Identity 'gmsaEntraSync01'
```

The script:
- Reads `msDS-SupportedEncryptionTypes` from the gMSA and local computer in AD.
- Displays decimal and hexadecimal values and standard DES/RC4/AES bit flags.
- Reads local Kerberos policy registry values without modifying them.
- Reads recent Netlogon events 9001 and 9002.
- Generates a **local** computer GPO HTML report under `%TEMP%\Gmsa-Kerberos-Computer-GPO.html`.

Interpretation: gMSA value `28` (`0x1C`) includes RC4, AES128, AES256. Computer value `24` (`0x18`) includes AES128 and AES256. The policy value `2147483640` (`0x7FFFFFF8`) has additional bits and should **not** be blindly replaced with `24`. Netlogon event 9001 is evidence of a compatibility check failing, but the exact cause requires effective-policy inspection. Do not enable RC4 or alter domain GPOs without security review.

**Confidentiality:** Do not upload the HTML report, event messages, domain names, host names, or unredacted outputs to this public repository.
