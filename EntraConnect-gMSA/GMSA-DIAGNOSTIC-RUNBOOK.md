# gMSA diagnostic
Run in elevated Windows PowerShell 5.1 on the intended Entra Connect host:

    .\06-Diagnose-Gmsa.ps1 -Identity 'gmsaEntraSync01'

Optionally specify -DC 'dc01.example.local'. The script is read-only and checks AD membership, secure channel, DC connectivity, gMSA permissions, encryption attributes, KDS key visibility, DC consistency, Test-ADServiceAccount and logs. It does not change AD, install a service account, or retrieve password material.

Reports are written to the local TEMP directory. They contain internal names and possibly sensitive event messages: do not publish them to the public repository. Review and redact before sharing.

PASS on secure channel or KDS visibility does not prove managed password retrieval. Blank Kerberos encryption values alone do not prove incompatibility. Direct computer authorization does not evaluate group membership. This script has not been tested on your production host.