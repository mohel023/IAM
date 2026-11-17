# Cloud Sync — état après retrait d'Entra Connect Sync

## Décision d'architecture
Le choix confirmé est **Microsoft Entra Cloud Sync uniquement**. L'installation Entra Connect Sync classique a été désinstallée par l'administrateur. Ne pas présumer que ce retrait a corrigé l'erreur de l'agent Cloud Sync.

## Vérifications après désinstallation (lecture seule)
Exécuter en PowerShell administrateur après un redémarrage contrôlé si possible :

```powershell
Get-CimInstance Win32_Service |
  Where-Object { $_.Name -match 'ADSync|ProvisioningAgent' } |
  Select-Object Name,State,StartMode,PathName

Get-Service -Name AADConnectProvisioningAgent -ErrorAction SilentlyContinue |
  Select-Object Name,Status,StartType

$root = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'
Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pap_connector_lib' } |
  Select-Object FullName,Length

Get-WinEvent -FilterHashtable @{
  LogName='System'
  ProviderName='Service Control Manager'
  StartTime=(Get-Date).AddHours(-8)
} -ErrorAction SilentlyContinue |
  Where-Object { $_.Message -match 'AADConnectProvisioningAgent|Provisioning Agent' } |
  Select-Object -First 15 TimeCreated,Id,Message
```

## Lecture des résultats
- `ADSync` absent : moteur classique retiré, sous réserve de vérifier aussi les composants installés.
- `AADConnectProvisioningAgent` en cours d'exécution : contrôler ensuite enregistrement, connectivité et état Cloud Sync.
- Agent arrêté et erreur `pap_connector_lib.dll` / `0x8007007E` : vérifier package officiel, dépendances natives et journaux ; ce code peut désigner une dépendance manquante.
- Agent absent : vérifier si la désinstallation a affecté le package Cloud Sync.

## Précautions
- Ne pas réinstaller Entra Connect Sync par défaut.
- Ne pas copier de DLL depuis une source non officielle ni désactiver antivirus/EDR.
- Ne pas activer le provisioning de production avant contrôle du périmètre pilote et des correspondances avec les utilisateurs cloud existants.
- Ne publier aucune information interne (domaines, serveurs, comptes, journaux bruts) dans ce dépôt public.
