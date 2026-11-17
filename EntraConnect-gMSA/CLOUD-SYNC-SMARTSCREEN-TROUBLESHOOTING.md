# Cloud Sync — SmartScreen inaccessible pendant le lancement de l'installateur

## Observation
Fenêtre Windows : **"SmartScreen can't be reached right now"** pour `AADConnectProvisioningAgentSetup.exe`, éditeur affiché **Microsoft Corporation**. Ce message signale l'impossibilité de contacter SmartScreen, **pas** une détection de malware ni la preuve que SmartScreen est responsable de l'erreur `pap_connector_lib.dll` (`0x8007007E`).

## Procédure sûre
1. Choisir **Don't Run** tant que l'origine et la signature ne sont pas vérifiées.
2. Vérifier que l'installateur provient d'une source Microsoft officielle, puis sa signature Authenticode et son empreinte SHA-256.
3. Contrôler résolution DNS, HTTPS 443 et proxy système (WinHTTP) / utilisateur ; une connexion TCP réussie ne prouve pas l'accès à tous les services SmartScreen.
4. Si les contrôles sont conformes, suivre la procédure d'installation approuvée par l'équipe sécurité, sans désactiver SmartScreen/Defender.
5. Vérifier ensuite le service et les journaux Cloud Sync ; diagnostiquer séparément la DLL native manquante ou sa dépendance.

## Commandes de diagnostic (lecture seule)
Adapter `$installer` au chemin réel de l'exécutable.

```powershell
$installer = 'C:\temp\AADConnectProvisioningAgentSetup.exe'
if (-not (Test-Path -LiteralPath $installer)) {
    throw 'Installer introuvable : adapter $installer.'
}
Get-AuthenticodeSignature -LiteralPath $installer |
    Select-Object Status,StatusMessage,@{N='Signer';E={$_.SignerCertificate.Subject}}
Get-FileHash -LiteralPath $installer -Algorithm SHA256

Get-Item -LiteralPath $installer -Stream * -ErrorAction SilentlyContinue |
    Select-Object FileName,Stream,Length

netsh winhttp show proxy
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
    Select-Object ProxyEnable,ProxyServer,AutoConfigURL

Resolve-DnsName login.microsoftonline.com -ErrorAction SilentlyContinue
Test-NetConnection login.microsoftonline.com -Port 443
Get-Service AADConnectProvisioningAgent -ErrorAction SilentlyContinue |
    Select-Object Name,Status,StartType
```

## Interprétation
- Signature `Valid` et provenance officielle : nécessaires mais ne prouvent pas à elles seules l'intégrité de toute la chaîne de distribution.
- Erreur SmartScreen : investiguer accès réseau, filtrage, proxy et politiques.
- Erreur DLL `0x8007007E` persistante : rechercher fichier et dépendances natives dans le package installé ; traiter séparément.
- Ne pas publier de noms de domaine internes, de comptes, de logs bruts ou de secrets dans ce dépôt public.
