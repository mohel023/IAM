# Diagnostic — Provisioning Agent: DLL native introuvable (lecture seule)

## Constat vérifié (captures du 17 novembre 2026)
- Le programme d'installation du **Microsoft Entra Provisioning Agent** a été relancé avec `/quiet`; aucun code de sortie n'a encore été fourni.
- Le service `AADConnectProvisioningAgent` a été observé en état **Stopped**, avec démarrage automatique.
- Les traces mentionnent `Unable to load DLL 'pap_connector_lib.dll': The specified module could not be found (0x8007007E)`.
- Une recherche récursive de fichiers `*connector*lib*` ou `*pap*` sous le dossier d'installation de l'agent ne retourne aucun résultat.
- Une erreur de **connector registration / Application Proxy** apparaît dans l'assistant. Les tests TCP 443 réussis sur quelques hôtes Microsoft ne prouvent pas la connectivité complète de l'agent.

**Interprétation** : la DLL attendue semble absente du répertoire contrôlé. Le code 0x8007007E peut également désigner une dépendance manquante. La cause de l'échec de registration n'est pas encore établie. Ne pas attribuer automatiquement ce problème au proxy, au gMSA ou à TLS.

## Étape suivante : preuves sans modification

Ouvrir PowerShell administrateur sur le serveur concerné :

```powershell
# 1. Si la variable existe encore dans cette même session :
if (Get-Variable installerProcess -ErrorAction SilentlyContinue) {
    $installerProcess | Select-Object Id,HasExited,ExitCode
} else {
    Write-Warning 'Objet installerProcess indisponible : relancer uniquement une collecte de logs, pas une installation.'
}

# 2. État et chemin du service
Get-CimInstance Win32_Service -Filter "Name='AADConnectProvisioningAgent'" |
    Select-Object Name,State,StartMode,PathName

# 3. Recherche exacte dans les chemins Microsoft usuels
$paths = @(
 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent',
 'C:\Program Files (x86)\Microsoft',
 'C:\ProgramData\Microsoft'
)
foreach ($path in $paths) {
    if (Test-Path -LiteralPath $path) {
        Get-ChildItem -LiteralPath $path -Filter 'pap_connector_lib.dll' -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object FullName,Length,LastWriteTime
    }
}

# 4. Journaux d'installation et de service récents
Get-ChildItem 'C:\ProgramData\Microsoft\Azure AD Connect Provisioning Agent\Trace' -Filter '*.log' -File -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 10 Name,Length,LastWriteTime

Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Service Control Manager';StartTime=(Get-Date).AddDays(-2)} -ErrorAction SilentlyContinue |
    Where-Object { $_.Message -match 'AADConnectProvisioningAgent|Provisioning Agent' } |
    Select-Object -First 20 TimeCreated,Id,Message
```

## Arbre de décision
1. **ExitCode non nul** : analyser d'abord les logs de l'installateur et les événements Windows Installer, avant toute nouvelle tentative.
2. **ExitCode 0, DLL absente** : vérifier le package installé, son intégrité, la version, les éventuelles quarantaines EDR et la présence de composants natifs requis. Un succès d'installateur n'est pas une preuve de package fonctionnel.
3. **DLL présente mais erreur 0x8007007E** : investiguer les dépendances natives et l'architecture x64, sans télécharger une DLL isolée sur Internet.
4. **Service fonctionnel mais registration échoue** : reprendre les traces de registration, l'authentification, le proxy effectif du compte de service, les URLs documentées et les restrictions réseau.

## Garde-fous
- Ne pas copier manuellement `pap_connector_lib.dll` depuis un serveur tiers.
- Ne pas modifier les droits du gMSA, le proxy, TLS ou les stratégies de sécurité sans preuve.
- Ne pas désinstaller/réinstaller en boucle avant collecte des codes de sortie et logs.
- **Entra Connect Sync** et **Cloud Sync / Provisioning Agent** sont des composants différents. Le staging mode de Connect Sync doit rester activé jusqu'à validation explicite des exports et du matching des identités.
- Ne jamais publier de logs bruts, noms de domaines, noms de serveurs, comptes, tokens, tenant IDs ou chemins de profil internes dans ce dépôt public.

## Données attendues pour poursuivre
- `ExitCode` de l'installation silencieuse (si encore disponible).
- État du service après l'installation.
- Résultat de la recherche exacte de la DLL.
- Extrait **expurgé** du premier échec dans les logs de l'installateur et de registration.

## Mise à jour — contrôle du processus d'installation silencieuse

Capture suivante : le processus d'installation (PID observé) a `HasExited=True`, mais la colonne `ExitCode` est vide. **Cela ne prouve ni succès ni échec**. Les événements SCM 7036 (changement d'état) et 7045 (installation de service) ne valident pas le fonctionnement de l'agent.

Contrôles complémentaires **en lecture seule** :

```powershell
# Même session uniquement, si l'objet existe encore :
if (Get-Variable installerProcess -ErrorAction SilentlyContinue) {
    try {
        $installerProcess.Refresh()
        [pscustomobject]@{
            HasExited = $installerProcess.HasExited
            ExitCode = if ($installerProcess.HasExited) { $installerProcess.ExitCode } else { $null }
        }
    } catch {
        Write-Warning "Code de sortie non disponible : $($_.Exception.Message)"
    }
}

Get-WinEvent -FilterHashtable @{
    LogName='Application'
    StartTime=(Get-Date).AddDays(-1)
} -ErrorAction SilentlyContinue |
    Where-Object { $_.ProviderName -eq 'MsiInstaller' -and $_.Message -match 'Provisioning|Connect' } |
    Select-Object -First 15 TimeCreated,Id,Message |
    Format-List
```

Ne pas relancer l'installation pour obtenir uniquement un code de retour. Examiner d'abord les logs existants. Avant partage ou commit, expurger identifiants, noms internes et chemins de profils.

## Mise à jour — preuves MSI du 17 novembre 2026

Les événements **MsiInstaller 1033 et 11707** confirment que Windows Installer a enregistré l'installation de **Microsoft Azure AD Connect Provisioning Agent, version 1.1.2507.0**, comme réussie (**installation success or error status: 0**). L'événement 1042 signale la fin de la transaction. Le `ExitCode` de l'objet PowerShell reste vide et ne doit pas être interprété comme un succès.

**Conséquence diagnostique :** un échec déclaré par MSI est écarté pour cette transaction, mais ni la présence de `pap_connector_lib.dll`, ni la résolution de ses dépendances natives, ni la registration du connecteur ne sont validées. Les erreurs antérieures `0x8007007E` et registration restent à investiguer.

Prochain contrôle, **lecture seule** :

```powershell
$root = 'C:\Program Files\Microsoft Azure AD Connect Provisioning Agent'
Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction Stop |
    Group-Object Extension |
    Select-Object Name,Count |
    Sort-Object Name
```

Ce comptage inventorie les types de fichiers, mais **ne prouve pas** que la DLL attendue est présente. Compléter ensuite par la recherche exacte de la DLL et, si nécessaire, l'analyse de dépendances. Ne pas réinstaller ni copier une DLL isolée avant d'avoir établi la cause.
