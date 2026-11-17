# Cloud Sync — diagnostic du Provisioning Agent (lecture seule)

## Contexte confirmé
- Produit : **Microsoft Entra Cloud Sync**, pas Microsoft Entra Connect Sync/ADSync.
- Agent observé : Microsoft Azure AD Connect Provisioning Agent 1.1.2507.0.
- Symptômes : service `AADConnectProvisioningAgent` arrêté après démarrage ; inscription du connecteur échouée.
- Journal : `Unable to load DLL 'pap_connector_lib.dll'`, HRESULT `0x8007007E`.
- Une recherche dans le répertoire d'installation n'a pas retrouvé la DLL. Cela ne prouve pas qu'elle manque au package : une dépendance native peut aussi être absente.
- L'installation MSI a retourné le statut 0, ce qui ne prouve pas que l'agent fonctionne.

## Contrôles sans modification (PowerShell administrateur)
```powershell
$root = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'
Get-Service -Name AADConnectProvisioningAgent | Select-Object Name,Status,StartType

Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pap|connector_lib' } |
  Select-Object FullName,Length,LastWriteTime

Get-MpThreatDetection -ErrorAction SilentlyContinue |
  Where-Object { $_.Resources -match 'pap_connector_lib' } |
  Select-Object InitialDetectionTime,ThreatID,Resources

Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddHours(-8);Level=1,2,3} -ErrorAction SilentlyContinue |
  Where-Object { $_.Message -match 'Provisioning|ApplicationProxy|pap_connector' } |
  Select-Object -First 20 TimeCreated,Id,ProviderName,Message
```

## Décision
1. Conserver les sorties des contrôles et identifier l'emplacement réel du fichier, s'il existe.
2. Vérifier l'intégrité du programme d'installation officiel et les prérequis du système avant toute nouvelle installation.
3. Si la DLL est présente, analyser ses dépendances et le contexte du service avant d'inférer une absence de fichier.
4. Ne pas télécharger une DLL isolée, ne pas désactiver les protections et ne pas copier de DLL d'un autre serveur.
5. Ne pas enregistrer de noms de domaine, serveurs, comptes, tokens ou traces brutes dans ce dépôt public.

## Sécurité des identités
Cloud Sync ne propose pas le Staging Mode d'Entra Connect Sync classique. Avant d'activer un provisioning vers un tenant contenant des comptes existants, limiter le périmètre pilote et examiner les correspondances UPN, proxyAddresses et identifiants d'ancrage selon les capacités et la configuration Cloud Sync. Ne pas activer une synchronisation générale sans validation.
