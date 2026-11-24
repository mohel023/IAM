# Préparation générique d'un pilote Quest Directory Sync Pro — sans migration

> Modèle public anonymisé : attribut et valeur fictifs, OU et domaines fictifs. Aucun identifiant ni paramètre client réel.

## Objectif
Lister les utilisateurs éligibles selon un attribut AD, visualiser leur OU source et la destination prévue, puis étudier une simulation Quest **sans écriture dans l'AD cible**.

## Filtre LDAP (exemple fictif)

Attribut fictif : `extensionAttributeX` (à remplacer dans un environnement privé par un attribut réellement existant).
Valeur fictive : `PILOT_VALUE`.

Condition conceptuelle :

```text
(<ATTRIBUT_AD>=<VALEUR_PILOTE>)
```

Exemple syntaxiquement exploitable utilisant un attribut standard fictivement choisi :

```ldap
(&(objectCategory=person)(objectClass=user)(extensionAttribute10=PILOT_VALUE))
```

Lorsqu'un filtre Quest existe déjà, **conserver toutes ses conditions et exclusions** ; ne pas le remplacer par cet exemple. Les conditions réelles doivent être inspectées dans un canal privé avant modification.

## Lecture seule PowerShell

```powershell
Import-Module ActiveDirectory
$SourceOU = 'OU=Pilot,DC=example,DC=invalid'
$TargetOU = 'OU=PilotTarget,DC=example,DC=invalid'
$Attribute = 'extensionAttribute10' # EXEMPLE, pas un attribut client
$Value = 'PILOT_VALUE'             # EXEMPLE
$Filter = "($Attribute=$Value)"

Get-ADUser -SearchBase $SourceOU -SearchScope Subtree `
  -LDAPFilter $Filter -Properties $Attribute,DistinguishedName |
  Select-Object SamAccountName,Name,DistinguishedName,
    @{Name='PlannedTargetOU';Expression={$TargetOU}} |
  Export-Csv '.\Pilot-Candidates.csv' -NoTypeInformation -Encoding UTF8
```

Le CSV décrit une **destination prévue** selon la variable fournie ; il ne prouve pas que Quest effectuera ce placement.

## Contrôles avant toute simulation

1. Vérifier le périmètre exact des OU sources et sous-OU.
2. Vérifier les filtres utilisateurs et groupes existants sans supprimer leurs exclusions.
3. Vérifier la configuration de l'OU cible et les options de création des OU.
4. Confirmer que le mode choisi est explicitement une simulation sans écriture, selon la version installée.
5. Conserver la validation du responsable avant toute synchronisation effective.

**Ne pas lancer `Sync Now` ni modifier un profil de production sur la base de ce modèle.**
