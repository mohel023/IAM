# Cloud Sync Provisioning Agent — diagnostic ciblé (2026-11-17)

> Documentation générique et partageable. Ne pas publier de noms de domaines, serveurs, comptes, locataires, IP privées, journaux bruts ou secrets dans ce dépôt public.

## Contexte et constats observés
- Projet distinct de **Microsoft Entra Connect Sync**, dont le **Staging Mode doit rester activé** pendant les validations.
- Installation de **Microsoft Entra Cloud Sync Provisioning Agent** sur Windows Server 2025.
- L'inscription du connecteur a échoué avec : `Connector registration failed` et référence au service **Microsoft Entra Application Proxy**.
- Le journal de l'agent indique : `Unable to load DLL 'pap_connector_lib.dll': The specified module could not be found (0x8007007E)`.
- Les tests TCP 443 vers quelques services Microsoft ont réussi ; cela **ne prouve pas** que tous les endpoints, la négociation TLS ou le contexte de service fonctionnent.
- Le service `AADConnectProvisioningAgent` a été observé **Stopped**, en démarrage **Automatic**, avec un **compte de service gMSA**.
- Les DLL .NET de l'agent et les modules de registration PowerShell sont visibles. La présence de `pap_connector_lib.dll` et de ses dépendances **n'est pas confirmée**.
- Des journaux de diagnostics de provisioning existent ; les traces d'initialisation Event Viewer échouent également.

## Hypothèses à départager (non confirmées)
1. **Priorité :** DLL native `pap_connector_lib.dll` absente du package installé, ou dépendance native absente / chemin de chargement. La recherche précédente n'a retourné aucun fichier visible.
2. Droits ou disponibilité du gMSA pour le service.
3. Installation incomplète ou composants incompatibles.
4. Problème de connectivité Application Proxy dans le contexte de l'agent, malgré TCP 443 OK.

## Vérifications en lecture seule (PowerShell administrateur)

### 1. État et identité du service
```powershell
$svc = Get-CimInstance Win32_Service -Filter "Name='AADConnectProvisioningAgent'"
$svc | Select-Object Name,State,StartMode,StartName,PathName | Format-List
Get-Service -Name AADConnectProvisioningAgent | Select-Object Name,Status,StartType
```

### 2. Tester le gMSA si le module ActiveDirectory est disponible
```powershell
Import-Module ActiveDirectory
$gmsa = ($svc.StartName -split '\\')[-1].TrimEnd('$')
if ($gmsa -and $svc.StartName -match '\$$') {
    Test-ADServiceAccount -Identity $gmsa
} else {
    Write-Warning 'Compte non identifié comme gMSA : vérifier StartName manuellement.'
}
```
`False` oriente vers une investigation des autorisations de récupération du mot de passe gMSA, KDS, Kerberos et du contexte machine. Ne pas changer l'identité du service sans plan de remédiation.

### 3. Localiser la DLL native
```powershell
$root = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'
Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object Name -eq 'pap_connector_lib.dll' |
    Select-Object FullName,Length,LastWriteTime
```
Si le fichier est absent dans le répertoire d'installation, vérifier la version et l'intégrité du package officiel Microsoft, puis planifier une réparation/réinstallation contrôlée si nécessaire. Si le fichier existe, `0x8007007E` peut signaler **une dépendance** manquante. La recherche antérieure sur les volumes ne retournait aucun résultat visible, mais utilisait `-ErrorAction SilentlyContinue`. Ne jamais télécharger une DLL isolée depuis une source non officielle.

### 4. Examiner les événements de service
```powershell
$since = (Get-Date).AddHours(-4)
Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$since} -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -eq 'Service Control Manager' -and $_.Message -match 'Provisioning' } |
    Select-Object TimeCreated,Id,Message | Format-List
```

### 5. Extraire les erreurs pertinentes des traces (en local uniquement)
```powershell
$trace = 'C:\ProgramData\Microsoft\Azure AD Connect Provisioning Agent\Trace'
Get-ChildItem -LiteralPath $trace -File -Filter '*.log' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name,Length,LastWriteTime
Get-ChildItem -LiteralPath $trace -File -Filter '*.log' -ErrorAction SilentlyContinue |
    Select-String -Pattern 'pap_connector_lib|0x8007007E|registration failed|exception' |
    Select-Object -Last 25 Path,LineNumber,Line
```
**Avant tout partage**, masquer les identifiants, noms d'hôtes, domaines, adresses et jetons.

## Séquence de décision
- **gMSA échoue** : diagnostiquer la récupération du mot de passe gMSA avant tout changement.
- **DLL principale absente** : vérifier l'installation à partir de packages Microsoft officiels ; envisager une réparation contrôlée après collecte des preuves.
- **DLL présente** : examiner les dépendances natives et le chargement par le processus (outils Microsoft signés / logs appropriés).
- **Service démarre puis s'arrête** : corréler l'heure précise avec System/Application et les traces de l'agent.
- **Service stable, inscription échoue** : tester proxy WinHTTP, TLS, résolution DNS, filtrage sortant et endpoints requis **dans le contexte du service**.

## Garde-fous
- Ne pas désactiver le Staging Mode d'Entra Connect Sync.
- Ne pas activer deux mécanismes de synchronisation sur un même périmètre d'objets sans architecture et périmètre explicitement validés.
- Ne pas désactiver TLS/contrôles réseau ou modifier le compte du service comme test rapide.
- Aucun résultat des contrôles ci-dessus n'est présumé positif tant qu'il n'a pas été collecté.

## Complément de diagnostic — recherche DLL et état du service

Une nouvelle capture montre la commande de recherche sur les volumes accessibles de `pap_connector_lib.dll`, sans résultat visible, suivie d'un inventaire du service. Ce résultat **renforce** la suspicion d'absence de DLL mais ne la démontre pas exhaustivement car les erreurs de parcours ont été masquées.

**Contrôle ciblé à exécuter sans masquer les erreurs :**

```powershell
$root = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'
Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Stop |
  Where-Object { $_.Name -like '*connector*lib*' -or $_.Name -like '*pap*' } |
  Select-Object FullName,Length
```

Interprétation : aucun résultat **sans erreur** signifie qu'aucun fichier correspondant n'a été trouvé dans **ce répertoire d'installation**, pas nécessairement dans tous les chemins de chargement. En cas d'erreur d'accès, corriger d'abord la portée du contrôle. Ne pas remplacer manuellement la DLL ; conserver les traces et vérifier l'installateur officiel avant toute réparation. Le service reste observé à l'arrêt et son démarrage est automatique. Ne pas modifier le gMSA ni désactiver le Staging Mode de Connect Sync.
