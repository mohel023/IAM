# Coexistence Legacy Microsoft LAPS / Windows LAPS — domaine AD avec DC récent

## Situation observée
Sur un **contrôleur de domaine**, l'installation du MSI « Local Administrator Password Solution (LAPS) » affiche une alerte Program Compatibility Assistant : sur **Windows Server 2025** (et Windows 11 23H2+), l'installation du MSI Legacy LAPS est bloquée. **Ne pas contourner ce blocage.**

L'environnement comporte deux branches d'OU, `Tiers0/Servers` et `Tiers1/Servers`, chacune avec des OU régionales. Les DC sont dans `OU=Domain Controllers`, distincte des OU `Servers`.

## Architecture de coexistence

- **Serveurs membres modernes** : Windows LAPS natif, avec GPO Windows LAPS dédiée.
- **Serveurs membres anciens non compatibles** : CSE Legacy LAPS sur ces serveurs, GPO Legacy LAPS dédiée.
- **Contrôleurs de domaine** : pas de CSE Legacy LAPS ; gestion éventuelle du mot de passe DSRM avec Windows LAPS, dans un chantier séparé et validé.
- **Administration Legacy** : outils `AdmPwd.PS` sur une machine d'administration compatible et sécurisée, plutôt que sur ce DC.
- Les attributs AD Legacy (`ms-Mcs-AdmPwd`, `ms-Mcs-AdmPwdExpirationTime`) et Windows LAPS (`msLAPS-*`) peuvent coexister dans le schéma. Éviter que deux politiques gèrent simultanément le même compte local.

## Vérification en lecture seule du schéma Legacy depuis le DC

~~~powershell
Import-Module ActiveDirectory
$SchemaDN = (Get-ADRootDSE).schemaNamingContext
Get-ADObject -SearchBase $SchemaDN `
  -LDAPFilter '(|(lDAPDisplayName=ms-Mcs-AdmPwd)(lDAPDisplayName=ms-Mcs-AdmPwdExpirationTime))' `
  -Properties lDAPDisplayName |
  Select-Object Name,lDAPDisplayName
~~~

**Attendu :** deux attributs. Extension Legacy LAPS déjà réalisée avec succès ; cette commande sert à confirmer sa présence et la réplication. Ne pas réexécuter `Update-AdmPwdADSchema`.

## Vérification du module Windows LAPS sur le DC

~~~powershell
Get-Command -Module LAPS
Get-ADDomainController -Filter * | Select-Object HostName,ComputerObjectDN
Get-ADOrganizationalUnit -Filter 'Name -eq "Servers"' |
  Select-Object DistinguishedName
~~~

Ne pas diffuser les résultats réels (noms de DC, DN internes) dans ce dépôt public.

## Délégations et sécurité

- `Set-LapsADComputerSelfPermission -Identity <DN-OU>` : permissions SELF pour **Windows LAPS**.
- `Set-AdmPwdComputerSelfPermission -OrgUnit <DN-OU>` : permissions SELF pour **Legacy LAPS**, via `AdmPwd.PS` sur une machine compatible.
- Identifier les OU contenant réellement les serveurs Legacy avant toute délégation ; éviter une délégation globale inutile sur tous les serveurs.
- Vérifier l'héritage des ACL vers les OU régionales et les ordinateurs.
- Les DC placés dans `OU=Domain Controllers` ne reçoivent pas directement les délégations effectuées sur les deux OU `Servers`, mais vérifier aussi le ciblage des GPO.
- Limiter strictement les droits de lecture des mots de passe, particulièrement en Tier 0. Les mots de passe Legacy LAPS sont stockés dans AD sans chiffrement applicatif.
- Les cmdlets Windows LAPS ne remplacent pas entièrement le module d'administration Legacy `AdmPwd.PS`.

## Étapes suivantes

1. Confirmer la présence des **deux attributs** Legacy dans le schéma.
2. Inventorier les versions OS des serveurs et distinguer les systèmes compatibles Windows LAPS.
3. Définir des OU/groupes de ciblage et deux GPO distinctes.
4. Installer le CSE Legacy **uniquement** sur les serveurs anciens concernés et compatibles.
5. Appliquer les délégations SELF adaptées après revue, puis vérifier sur un pilote de chaque Tier.
6. Tester sauvegarde et récupération autorisée des mots de passe sans exposer de secrets dans les logs.

Référence Microsoft : https://learn.microsoft.com/en-us/windows-server/identity/laps/laps-overview


## Diagnostic du MSI Legacy LAPS bloqué et module AdmPwd.PS introuvable

Observation : après `msiexec /i <chemin MSI> /quiet`, `Import-Module AdmPwd.PS` renvoie `Modules_ModuleNotFound`. Cela **ne prouve pas** la réussite de l'installation ; le blocage de compatibilité Windows Server 2025 reste applicable. Ne pas contourner le blocage par une installation silencieuse.

### Contrôles non destructifs sur le DC

~~~powershell
Get-Module -ListAvailable AdmPwd.PS
Get-ChildItem 'C:\Program Files\LAPS' -ErrorAction SilentlyContinue
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption,Version,BuildNumber

Get-ItemProperty `
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', `
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' `
    -ErrorAction SilentlyContinue |
    Where-Object DisplayName -Match 'Local Administrator Password Solution' |
    Select-Object DisplayName,DisplayVersion,InstallLocation
~~~

Pour une installation sur un **système compatible uniquement**, utiliser une journalisation MSI et examiner le code de retour, sans supposer qu'un processus silencieux a réussi :

~~~powershell
$p = Start-Process msiexec.exe `
    -ArgumentList '/i "C:\Path\LAPS.x64.msi" /qn /norestart /L*v "C:\Windows\Temp\LegacyLAPS-install.log"' `
    -Wait -PassThru
$p.ExitCode
~~~

**Ne pas exécuter cette commande d'installation sur le DC Windows Server 2025.** Le fichier MSI et les chemins sont des exemples, pas des artefacts à copier depuis un serveur client.

### État du schéma

**Historique :** les deux attributs étaient initialement absents. **État actualisé :** `Update-AdmPwdADSchema -Verbose` a ensuite réussi (`AddSchemaAttribute` pour les deux attributs et `ModifySchemaClass` pour `computer`). Ne pas relancer l'extension ; vérifier la réplication AD et la présence des attributs sur les DC.


## État et décisions — 20 novembre 2026

- Extension du schéma **Legacy LAPS confirmée réussie** via `Update-AdmPwdADSchema -Verbose` : création de `ms-Mcs-AdmPwd`, `ms-Mcs-AdmPwdExpirationTime` et modification de la classe `computer`.
- Permissions SELF Legacy LAPS indiquées comme appliquées aux OU `Servers` de Tier 0 et Tier 1 ; vérifier l'héritage vers les sous-OU régionales.
- Domaine cible avec deux DC ; pas de Central Store ADMX. Les fichiers `AdmPwd.admx` et `AdmPwd.adml` peuvent être installés **localement sur la machine qui édite la GPO** (`C:\Windows\PolicyDefinitions` et sous-dossier de langue). Inutile de copier sur les deux DC si un seul sert à l'édition. Les paramètres GPO enregistrés se répliquent via AD/SYSVOL.
- Legacy LAPS et Windows LAPS : **GPO distinctes**, serveurs membres uniquement, exclusion des DC et de Windows Server 2003.
- Ne pas publier les identifiants réels, mots de passe, DN internes ou sorties d'audit sensibles.

### Nommage selon convention interne (noms candidats, à valider)

Format GPO observé : `{TierLevel}-<Objectif>-{ActionGPO}-{CibleGPO}` (exemple générique : `T1-SMBv1-Disable-Computer`).

| Objet | Nom candidat |
|---|---|
| Legacy Tier 0 GPO | `T0-LegacyLAPS-Configure-Computer` |
| Legacy Tier 1 GPO | `T1-LegacyLAPS-Configure-Computer` |
| Windows Tier 0 GPO | `T0-WindowsLAPS-Configure-Computer` |
| Windows Tier 1 GPO | `T1-WindowsLAPS-Configure-Computer` |

Format groupes de population : `POL-<Department|BU|Purpose>-<Population>-<Grouping>`. Groupes **Global / Security** dans OU `Population Groups` :

- `POL-LAPS-Administrators-T0`, `POL-LAPS-Administrators-T1` (pour accès Legacy, ou population commune uniquement si les mêmes habilitations sont approuvées).
- Variante séparée pour Windows : `POL-LAPS-Windows-Administrators-T0`, `POL-LAPS-Windows-Administrators-T1`.

Format groupes d'accès : `ACC-<T0>-{ResourceType}-[{Site}|{Region}]-<Target Object>-<Sub Object>-<Access|Role>`. Groupes **Domain Local / Security** dans OU `Access Groups` :

- `ACC-T0-SRV-GLOBAL-LAPS-Legacy-Read`
- `ACC-T1-SRV-GLOBAL-LAPS-Legacy-Read`
- `ACC-T0-SRV-GLOBAL-LAPS-Windows-Read`
- `ACC-T1-SRV-GLOBAL-LAPS-Windows-Read`

**Réserve :** `SRV`, `GLOBAL`, `Configure` et les segments de population sont des propositions, non des codes officiellement validés. Adapter les noms à la convention et au site/région réel avant création. Imbrication AGDLP : comptes admin → groupe `POL` global → groupe `ACC` domain local → ACL AD. Ne jamais mélanger T0 et T1. Les groupes Windows LAPS habilités à lire les attributs chiffrés ne peuvent déchiffrer que s'ils sont également désignés comme déchiffreurs dans la GPO ; une séparation lecture/déchiffrement peut être préférable.

### Délégations à valider

**Legacy LAPS :** `Set-AdmPwdComputerSelfPermission -OrgUnit <OU-DN>` (SELF), `Set-AdmPwdReadPasswordPermission -OrgUnit <OU-DN> -AllowedPrincipals <ACC-LEGACY>` (lecture), `Set-AdmPwdResetPasswordPermission` si besoin distinct. Auditer `Find-AdmPwdExtendedRights`. Ne pas accorder directement la lecture aux groupes POL.

**Windows LAPS :** vérifier d'abord les attributs `msLAPS-*` et le niveau fonctionnel AD ; `Set-LapsADComputerSelfPermission -Identity <OU-DN>`, `Set-LapsADReadPasswordPermission -Identity <OU-DN> -AllowedPrincipals <ACC-WINDOWS>`, `Set-LapsADResetPasswordPermission` uniquement si requis. Auditer `Find-LapsADExtendedRights`. Pour le chiffrement AD, niveau fonctionnel Windows Server 2016 minimum et groupe déchiffreur configuré **avant** la première sauvegarde chiffrée. Aucune délégation de lecture/rotation ne doit être supposée déjà appliquée.

### WMI Filters proposés (namespace root\\CIMv2)

Les filtres génériques déjà existants (`Server2008_And_Above`, `Server2016_And_Above`, etc.) sont potentiellement trop larges ; ne pas les modifier s'ils sont utilisés ailleurs. Créer des filtres dédiés et tester sur les serveurs pilotes.

**`LAPS-Legacy-MemberServers-2008To2016`**

Description: *Targets eligible Windows Server 2008 through 2016 member servers. Excludes domain controllers and Windows Server 2003.*

~~~sql
SELECT * FROM Win32_OperatingSystem
WHERE ProductType = 3
AND (
  Version LIKE "6.0%"
  OR Version LIKE "6.1%"
  OR Version LIKE "6.2%"
  OR Version LIKE "6.3%"
  OR Version LIKE "10.0.14393%"
)
~~~

**`LAPS-Windows-MemberServers-2019AndAbove`**

Description: *Targets Windows Server 2019, 2022 and 2025 member servers with required Windows LAPS updates. Excludes domain controllers.*

~~~sql
SELECT * FROM Win32_OperatingSystem
WHERE ProductType = 3
AND (
  Version LIKE "10.0.17763%"
  OR Version LIKE "10.0.20348%"
  OR Version LIKE "10.0.26100%"
)
~~~

**Important :** les WMI filters testent une version OS, **pas** la présence du client, du correctif, de la fonctionnalité ni la compatibilité effective. Vérifier les prérequis Microsoft par version, particulièrement Windows Server 2008/2008 R2 et 2016, avant déploiement. Les Windows Server 2003 ne sont pris en charge ni par Legacy LAPS officiel ni par Windows LAPS : prévoir un traitement PAM distinct. `ProductType = 3` exclut les DC. Les GPO doivent en outre être limitées aux OU et groupes pilotes appropriés pour empêcher tout chevauchement.

### Séquence de validation

1. Contrôler réplication du schéma et héritage SELF sur OU régionales.
2. Valider les noms et membres POL/ACC avec les responsables IAM et Tier.
3. Vérifier ACL existantes avant délégation READ/RESET et configurer les droits Windows LAPS séparément.
4. Créer et tester les deux WMI filters ; contrôler `Get-CimInstance Win32_OperatingSystem` et `gpresult /r /scope computer`.
5. Déployer les GPO pilotes sur serveurs membres compatibles, avec CSE Legacy uniquement là où nécessaire.
6. Vérifier les journaux LAPS et les attributs d'expiration **sans divulguer de mot de passe** ; étendre par vagues après validation.
