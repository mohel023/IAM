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

**Attendu :** deux attributs. S'ils existent, ne pas réétendre le schéma sans nécessité. S'ils sont absents, préparer un changement de schéma approuvé, exécuté depuis une machine compatible avec les outils requis.

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

La vérification en lecture seule des deux attributs `ms-Mcs-AdmPwd` et `ms-Mcs-AdmPwdExpirationTime` a retourné `False` pour les deux. L'extension Legacy n'est donc pas constatée. Toute extension de schéma via LDIFDE ou autre méthode requiert des définitions officielles vérifiées, une revue de sécurité, une sauvegarde et un changement approuvé. Ne pas inventer les OID ni appliquer un LDIF non vérifié.
