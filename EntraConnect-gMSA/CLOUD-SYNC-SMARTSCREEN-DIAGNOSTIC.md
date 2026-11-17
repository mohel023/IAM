# Cloud Sync — SmartScreen et agent Provisioning

Guide générique. Ne pas publier de noms de domaine, serveurs, comptes ou journaux bruts d'un client dans ce dépôt public.

## Constats

- « SmartScreen can't be reached right now » indique une indisponibilité du service de réputation, pas une preuve de corruption du programme.
- « Direct access (no proxy server) » dans WinHTTP ne garantit pas la connectivité Internet.
- Le code MSI 0 indique que l'installation MSI a réussi, mais ne confirme pas l'enregistrement Cloud Sync.
- « Unable to load DLL pap_connector_lib.dll » peut désigner le fichier ou une dépendance native manquante.
- Microsoft Entra Cloud Sync Provisioning Agent et Microsoft Entra Connect Sync sont deux composants distincts.

## Vérifications non destructives

Exécuter dans PowerShell administrateur, adapter le chemin :

```powershell
$installer = 'C:\temp\AADConnectProvisioningAgentSetup.exe'
if (Test-Path -LiteralPath $installer) {
  Get-AuthenticodeSignature -LiteralPath $installer |
    Select-Object Status,StatusMessage,@{Name='Signer';Expression={$_.SignerCertificate.Subject}}
  Get-FileHash -LiteralPath $installer -Algorithm SHA256
} else { Write-Warning 'Installer path not found' }

netsh winhttp show proxy
Resolve-DnsName login.microsoftonline.com
Test-NetConnection login.microsoftonline.com -Port 443
try {
  (Invoke-WebRequest 'https://login.microsoftonline.com' -UseBasicParsing -TimeoutSec 15).StatusCode
} catch { $_.Exception.Message }

Get-Service AADConnectProvisioningAgent -ErrorAction SilentlyContinue |
  Select-Object Name,Status,StartType

$root = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'
if (Test-Path -LiteralPath $root) {
  Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Continue |
    Where-Object Name -Match 'pap_connector_lib|connector.*lib' |
    Select-Object FullName,Length
}
Get-WinEvent -ListLog '*ProvisioningAgent*' -ErrorAction SilentlyContinue |
  Select-Object LogName,IsEnabled,RecordCount
```

## Décision

1. Signature non valide : arrêter et récupérer l'installateur depuis la source Microsoft officielle.
2. DNS/TCP/HTTPS défaillant : vérifier proxy, pare-feu, inspection TLS et points de terminaison Microsoft autorisés. Un test sur login.microsoftonline.com ne prouve pas l'accessibilité de SmartScreen ni d'Application Proxy.
3. DLL absente ou non chargeable : examiner package, dépendances et éventuelle quarantaine de sécurité ; ne pas télécharger de DLL isolée depuis un site tiers.
4. Service arrêté : analyser journaux horodatés et erreurs d'enregistrement avant réparation ou réinstallation approuvée.
5. Ne pas désactiver SmartScreen ou Defender pour contourner l'alerte.
6. Avant toute synchronisation : vérifier le périmètre pilote et le rapprochement des identités cloud existantes. Ne pas supposer que Cloud Sync dispose du même staging que Connect Sync.

Ne jamais déclarer l'incident résolu sans tests réels du service, de l'enregistrement et d'un provisioning pilote.
