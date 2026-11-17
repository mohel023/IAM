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
