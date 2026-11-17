# Diagnostic — Entra Cloud Sync : échec d'enregistrement de l'agent

## Incident et état connu

Erreur de l'assistant : **Connector registration failed: Make sure your computer is able to connect to Azure Active Directory Application Proxy service.**

Observations confirmées :
- Ancien Entra Connect Sync : service ADSync actif, StagingModeEnabled = True.
- Aucun export effectué par ADSync selon l'opérateur.
- Service AADConnectProvisioningAgent : Running.
- Portail Cloud Sync / Configurations : vide.
- Portail Cloud Sync / Agents : No results.
- Cause racine : inconnue. Hypothèses : DNS, pare-feu, proxy système, TLS/certificats, autorisations tenant, enregistrement gMSA.

L'application ConnectSyncProvisioning est gérée par **Entra Connect Sync** ; elle ne constitue pas une configuration Cloud Sync.

## Mesures de sécurité

Conserver ADSync en Staging Mode. Ne pas lancer d'export, désinstaller ADSync, supprimer ConnectSyncProvisioning, modifier les identifiants cloud, désactiver SmartScreen, le pare-feu ou la vérification TLS. Ne pas créer de configuration Cloud Sync active avant validation des identités pilotes.

**Dépôt public : ne publier aucun nom de client, domaine, serveur, compte, identifiant tenant, secret ou log brut.**

## Étape 1 — Contrôles locaux non destructifs

~~~powershell
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber
Get-CimInstance Win32_ComputerSystem | Select-Object Name,PartOfDomain,Domain
Get-Service ADSync,AADConnectProvisioningAgent -ErrorAction SilentlyContinue | Select-Object Name,Status,StartType
$manifest = 'C:\Program Files\Microsoft Azure AD Sync\Bin\ADSync\ADSync.psd1'
if (Test-Path $manifest) {
  Import-Module $manifest
  Get-ADSyncScheduler | Select-Object StagingModeEnabled,SyncCycleEnabled,SchedulerSuspended
}
~~~

Attendu : StagingModeEnabled = True. Stopper toute modification si ce n'est pas le cas.

## Étape 2 — DNS et TCP 443

~~~powershell
$hostsToTest = @('login.microsoftonline.com','enterpriseregistration.windows.net','graph.microsoft.com')
foreach ($h in $hostsToTest) {
  Resolve-DnsName $h -ErrorAction Continue | Select-Object -First 3 Name,Type,IPAddress
  Test-NetConnection $h -Port 443 | Select-Object ComputerName,RemoteAddress,TcpTestSucceeded
}
~~~

Ces tests ne prouvent pas la connectivité applicative ni l'absence de proxy HTTP 407 ou d'erreur TLS. Les endpoints Application Proxy/Service Bus peuvent être régionaux : relever le FQDN exact dans les logs et comparer aux prérequis Microsoft. Ne pas supposer que servicebus.windows.net est un hôte individuel testable.

## Étape 3 — Proxy et identité du service

~~~powershell
netsh winhttp show proxy
Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' | Select-Object ProxyEnable,ProxyServer,AutoConfigURL
Get-CimInstance Win32_Service -Filter "Name='AADConnectProvisioningAgent'" | Select-Object Name,State,StartMode,StartName
~~~

Le proxy du navigateur peut être différent de celui du service. Vérifier PAC, authentification proxy, inspection TLS et politiques réseau sans les contourner.

## Étape 4 — Horloge et TLS

~~~powershell
Get-Date
w32tm /query /status
Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Schannel';StartTime=(Get-Date).AddHours(-2)} -ErrorAction SilentlyContinue | Select-Object -First 30 TimeCreated,Id,LevelDisplayName,Message
[Net.ServicePointManager]::SecurityProtocol
~~~

La dernière commande montre seulement la configuration de cette session PowerShell, pas celle du service. Rechercher erreurs de chaîne, révocation CRL/OCSP, inspection TLS et décalage d'horloge.

## Étape 5 — Journaux agent

Cliquer sur **Check the logs** dans l'assistant. Relever l'heure, l'étape, le code d'erreur, l'exception interne, l'URL/FQDN et l'éventuel code HTTP.

~~~powershell
Get-WinEvent -ListLog '*Provisioning*','*ApplicationProxy*','*AAD*' -ErrorAction SilentlyContinue | Select-Object LogName,RecordCount
Get-ChildItem "$env:ProgramData\Microsoft" -Directory -ErrorAction SilentlyContinue | Where-Object Name -match 'Provision|Connect|Proxy' | Select-Object FullName
~~~

Une fois le nom exact du journal trouvé :

~~~powershell
$logName = '<NOM EXACT DU JOURNAL>'
Get-WinEvent -FilterHashtable @{LogName=$logName;StartTime=(Get-Date).AddHours(-2)} -MaxEvents 50 | Select-Object TimeCreated,Id,LevelDisplayName,Message | Format-List
~~~

Ne pas déposer de journaux non expurgés dans GitHub.

## Étape 6 — Assistant et tenant

1. Ouvrir **Microsoft Entra Provisioning Agent**, pas l'assistant **Microsoft Entra Connect Sync**.
2. Confirmer le tenant cible et les privilèges appropriés (Hybrid Identity Administrator).
3. Vérifier la configuration AD/gMSA propre à Cloud Sync ; ne pas supposer que le gMSA ADSync est réutilisable.
4. Diagnostiquer le message détaillé avant une nouvelle tentative. Ne pas réinstaller en boucle.
5. Après correction ciblée, vérifier **Cloud Sync > Agents** dans le tenant cible.

## Matrice de décision

| Résultat | Cause possible | Suite |
| --- | --- | --- |
| DNS échoue | Résolution | Corriger DNS |
| TCP 443 échoue | Réseau / pare-feu | Demander ouverture ciblée |
| Edge fonctionne, service échoue | Proxy service | Comparer WinHTTP, PAC et identité |
| HTTP 407 | Authentification proxy | Autoriser le service |
| Schannel / chaîne de certificats | TLS / inspection | Contrôler chaîne, CRL/OCSP |
| HTTP 401/403 | Tenant / permissions | Vérifier rôle et exception |
| Échec gMSA | AD / KDS / droits | Diagnostic gMSA |
| Agent invisible après succès annoncé | Tenant / enregistrement | Comparer tenant et logs |

## Critères de réussite

- Enregistrement terminé sans erreur.
- Agent visible **Healthy** dans Cloud Sync > Agents.
- Aucun échec persistant dans les journaux.
- Préparer ensuite une configuration pilote limitée avec PHS, **sans activation générale**.
- Avant activation, vérifier UPN, SMTP, sourceAnchor, onPremisesImmutableId et matching avec comptes cloud existants, ainsi que les dépendances Exchange/Intune.
- Maintenir ADSync en staging jusqu'au plan de retrait/rollback validé.

## Références Microsoft

- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-install
- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/what-is-cloud-sync
- https://learn.microsoft.com/en-us/entra/identity/hybrid/cloud-sync/how-to-troubleshoot

Vérifier la liste actuelle des endpoints et les chemins des logs propres à la version installée avant tout changement réseau.

## Mise à jour du 17 novembre 2026 — contrôles observés

| Contrôle | Résultat constaté | Interprétation |
| --- | --- | --- |
| WinHTTP | Direct access (no proxy server) | Aucun proxy WinHTTP déclaré ; accès direct réel non prouvé |
| OS | Windows Server 2025 Datacenter, build 26100 | Système identifié |
| w32tm | Leap Indicator 0 (no warning) | Pas d'alerte de synchronisation horaire visible |
| Source horaire | VM IC Time Synchronization Provider | Heure fournie par l'hyperviseur |
| Schannel | Aucun événement affiché dans la capture | Ne prouve pas l'absence de problème TLS |

### Tests suivants, non destructifs

~~~powershell
$endpoints = @('login.microsoftonline.com','enterpriseregistration.windows.net','graph.microsoft.com')
foreach ($endpoint in $endpoints) {
  Test-NetConnection -ComputerName $endpoint -Port 443 |
    Select-Object ComputerName,RemoteAddress,TcpTestSucceeded
}

$urls = @('https://login.microsoftonline.com','https://graph.microsoft.com')
foreach ($url in $urls) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 15
    [pscustomobject]@{Url=$url;HTTP=$r.StatusCode;Error=$null}
  } catch {
    $status = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }
    [pscustomobject]@{Url=$url;HTTP=$status;Error=$_.Exception.Message}
  }
}

Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' |
  Select-Object ProxyEnable,ProxyServer,AutoConfigURL

Get-WinEvent -ListLog '*Provisioning*','*ApplicationProxy*','*AAD*' -ErrorAction SilentlyContinue |
  Select-Object LogName,RecordCount
~~~

Un test TCP réussi ne valide pas l'authentification proxy ni le protocole applicatif. Un HTTP 4xx peut prouver qu'un serveur a répondu mais ne confirme pas l'enregistrement. Si ces tests passent, examiner en priorité le FQDN exact, le code HTTP et l'exception interne via Check the logs de l'assistant Cloud Sync. Ne pas modifier proxy ou TLS sans cause identifiée. Expurger toute donnée interne avant partage.

## Mise à jour — tests TCP observés

La capture PowerShell confirme les trois tests `Test-NetConnection -Port 443` :

| Endpoint | TcpTestSucceeded |
| --- | --- |
| `login.microsoftonline.com` | `True` |
| `enterpriseregistration.windows.net` | `True` |
| `graph.microsoft.com` | `True` |

**Portée de ce résultat :** la résolution DNS et l'établissement TCP 443 fonctionnent pour ces trois hôtes. Cela ne valide ni les requêtes HTTPS complètes ni les endpoints spécifiques utilisés pour l'enregistrement Cloud Sync/Application Proxy.

**Toujours en attente :** sortie des tests `Invoke-WebRequest`, paramètres proxy du profil utilisateur et résultats de la recherche de journaux de l'agent. Ne pas considérer l'absence de sortie visible sur la capture comme une réussite.

**Action suivante :** exécuter les tests HTTPS et relever l'exception interne via « Check the logs » de l'assistant d'enregistrement, en expurgeant tout identifiant privé avant partage. Conserver Entra Connect Sync en Staging Mode.

## Suivi — incident toujours présent (retour « idem »)

L'opérateur signale que le problème persiste, sans nouvelle sortie de diagnostic permettant d'établir si l'échec concerne HTTPS ou l'enregistrement de l'agent. **Ne pas conclure que les tests HTTPS ont échoué.**

### Collecte complémentaire en lecture seule

~~~powershell
Get-ChildItem 'C:\ProgramData\Microsoft' -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'Provisioning|Proxy|Trace' -and $_.Extension -match '\.log|\.txt' } |
  Select-Object -First 30 FullName,LastWriteTime

Get-WinEvent -ListLog * -ErrorAction SilentlyContinue |
  Where-Object { $_.LogName -match 'Provisioning|ApplicationProxy|AAD' } |
  Select-Object LogName,RecordCount

Get-Service *Provisioning* -ErrorAction SilentlyContinue |
  Select-Object Name,Status,StartType
~~~

**Question de qualification :** « idem » signifie-t-il une erreur dans `Invoke-WebRequest`, ou uniquement le message `Connector registration failed` dans l'assistant ? Relever le message complet et l'horodatage. Expurger les chemins utilisateurs, identifiants et journaux avant partage ou commit dans ce dépôt public.

## Suivi — journaux Cloud Sync localisés

La dernière capture confirme la présence de journaux récents sous :

C:\ProgramData\Microsoft\Azure AD Connect Provisioning Agent\Trace

Fichiers observés : AzureADConnectProvisioningAgent_*.log, trace-wizard-*.log et trace-wizard-*.txt. La cause racine reste inconnue.

### Recherche ciblée (lecture seule)

~~~powershell
$LogPath = 'C:\ProgramData\Microsoft\Azure AD Connect Provisioning Agent\Trace'

Get-ChildItem $LogPath -File |
  Where-Object { $_.Extension -in '.log','.txt' } |
  Select-String -Pattern 'error|exception|failed|proxy|403|407|timeout|certificate|servicebus' |
  Select-Object -Last 40 Path,LineNumber,Line | Format-List

$WizardLog = Get-ChildItem $LogPath -File |
  Where-Object { $_.Name -like 'trace-wizard*' } |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1

if ($WizardLog) {
  Write-Host "Journal sélectionné : $($WizardLog.Name)"
  Select-String -Path $WizardLog.FullName -Pattern 'error|exception|failed|registration|proxy' -Context 3,5 |
    Select-Object -Last 15 | Format-List
}
~~~

Ne pas committer les journaux bruts dans ce dépôt public. Expurger les identifiants, noms internes, secrets et jetons avant partage. Lire l'exception interne et le FQDN exact avant toute modification réseau. Conserver ADSync en Staging Mode.

## Suivi du diagnostic — erreur de confirmation RegisterConnector

Nouvelle capture du journal trace-wizard : ligne 531, confirmation step ended with an error, System.InvalidOperationException: Connector registration failed. Les messages GC_WITHOUT_DISPOSE voisins ne suffisent pas à expliquer cet échec. Aucune cause racine démontrée à ce stade.

### Priorité : examiner les logs du service plutôt que répéter le wizard

~~~powershell
$Path = 'C:\ProgramData\Microsoft\Azure AD Connect Provisioning Agent\Trace'
Get-ChildItem $Path -Filter 'AzureADConnectProvisioningAgent_*.log' -File |
  Sort-Object LastWriteTime -Descending |
  Select-Object Name,Length,LastWriteTime

Get-ChildItem $Path -Filter 'AzureADConnectProvisioningAgent_*.log' -File |
  Select-String -Pattern 'error|exception|failed|connection|registration' |
  Select-Object -Last 20 Path,LineNumber,Line |
  Format-List
~~~

Vérifier ensuite les endpoints exacts Application Proxy / Service Bus dans les erreurs détaillées, les restrictions du pare-feu ou d'un éventuel proxy d'entreprise, sans supposer qu'un test TCP 443 vers login.microsoftonline.com, enterpriseregistration.windows.net et graph.microsoft.com suffit.

Question ouverte : le serveur utilise-t-il une sortie Internet directe, Zscaler, un proxy d'entreprise ou un pare-feu filtrant les URL ?

Conserver Entra Connect Sync en Staging Mode ; ne pas réinstaller ni modifier TLS ou le pare-feu sans diagnostic ciblé. Ne pas publier de journaux bruts, noms internes, jetons ou secrets dans ce dépôt public.


## Nouveau constat — chargement DLL et journalisation native (17 novembre 2026)

Les deux journaux \`AzureADConnectProvisioningAgent_*.log\` affichés dans la capture contiennent, à la ligne 1 :

\`\`\`text
RustEventLogger.Initialize: Event Viewer initialization failed 3 consecutive time(s).
Unable to load DLL 'pap_connector_lib.dll': The specified module could not be found.
HRESULT: 0x8007007E
\`\`\`

**Interprétation prudente :** \`0x8007007E\` indique qu'une DLL ou une dépendance native ne peut pas être chargée. Le message porte sur l'initialisation du composant de journalisation ; son lien causal avec l'échec antérieur \`RegisterConnector\` n'est **pas démontré**. Ne pas conclure à un problème réseau ni à une installation corrompue sur cette seule base.

### Contrôles locaux non destructifs

Exécuter dans Windows PowerShell en administrateur, sans publier les chemins contenant des identifiants privés :

\`\`\`powershell
# 1. Localiser la DLL (et relever taille/date)
Get-ChildItem 'C:\Program Files\Microsoft' -Filter 'pap_connector_lib.dll' -Recurse -File -ErrorAction SilentlyContinue |
    Select-Object FullName,Length,LastWriteTime

# 2. Relever les services Provisioning et leurs exécutables
Get-CimInstance Win32_Service |
    Where-Object { $_.Name -match 'Provisioning|AADConnect' -or $_.DisplayName -match 'Provisioning|Cloud Sync' } |
    Select-Object Name,State,StartMode,PathName | Format-List

# 3. Inventaire des composants installés (lecture seule)
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match 'Provisioning|Visual C\+\+' } |
    Select-Object DisplayName,DisplayVersion,Publisher
\`\`\`

**Décision après résultats :** si DLL absente, vérifier la version et l'intégrité du package Microsoft ; si DLL présente, investiguer ses dépendances et l'environnement de chargement. Ne jamais télécharger/coller une DLL isolée depuis une source non officielle. Ne pas modifier le service Entra Connect Sync ni désactiver son Staging Mode. Aucune configuration Cloud Sync ne doit être activée avant validation des correspondances avec les utilisateurs cloud existants.


## Contrôles supplémentaires — service arrêté et composants installés (17 novembre 2026)

Dernière capture PowerShell, sans sortie de données sensibles :
- Service \`AADConnectProvisioningAgent\` : \`Stopped\`, \`StartMode=Auto\`.
- Exécutable : sous \`C:\Program Files\Microsoft Azure AD Connect Provisioning Agent\`.
- \`Microsoft Entra Provisioning Agent Package\` et \`Microsoft Azure AD Connect Provisioning Agent\` : version \`1.1.2507.0\`.
- Runtime Microsoft Visual C++ 2022 x64 et Redistributable 2015–2022 x64 : \`14.42.34438\`.
- Recherche précédente de \`pap_connector_lib.dll\` dans \`C:\Program Files\Microsoft\` : aucun résultat visible ; **ce répertoire ne correspond pas au dossier de l'agent** et n'établit donc pas que la DLL est absente.

### Vérifications à exécuter avant toute réparation

~~~powershell
$AgentPath = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'

# Inventaire du dossier d'installation
Get-ChildItem $AgentPath -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -match 'pap_connector|\.dll$' } |
  Select-Object FullName,Length | Format-Table -AutoSize

# Recherche exacte dans les emplacements pertinents
Get-ChildItem 'C:\Program Files','C:\ProgramData' -Filter 'pap_connector_lib.dll' -Recurse -File -ErrorAction SilentlyContinue |
  Select-Object FullName,Length

# Erreurs du gestionnaire de services
Get-WinEvent -FilterHashtable @{
  LogName='System'
  ProviderName='Service Control Manager'
  StartTime=(Get-Date).AddDays(-2)
} -ErrorAction SilentlyContinue |
  Where-Object { $_.Message -match 'AADConnectProvisioningAgent|Provisioning Agent' } |
  Select-Object -First 15 TimeCreated,Id,Message | Format-List
~~~

**Interprétation attendue :** service arrêté + DLL introuvable au mauvais emplacement ne suffisent pas à conclure à un package corrompu. Si DLL absente du répertoire réel, envisager réparation officielle après validation ; si présente, rechercher ses dépendances natives. Ne pas télécharger de DLL isolée, désactiver la sécurité, ni sortir Entra Connect Sync de son Staging Mode. Les sorties de commandes doivent être expurgées des informations internes avant partage sur le dépôt public.
