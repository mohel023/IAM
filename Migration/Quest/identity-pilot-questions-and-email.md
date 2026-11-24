# Quest Directory Sync Pro — questions et mail proposé

> Document de travail générique et anonymisé. Ne pas y ajouter de noms, domaines, identifiants, captures ou configurations client.

## Les 7 questions à poser

1. **Périmètre pilote :** quels utilisateurs et groupes devons-nous migrer en premier ? Qui valide la liste ?
2. **Attribut de sélection :** quel attribut AD permettra d'identifier les utilisateurs à migrer ? Quelles valeurs utiliser pour chaque vague ?
3. **Group Membership :** faut-il conserver toutes les appartenances, y compris les groupes imbriqués et les groupes de sécurité ? Les groupes seront-ils créés dans la cible ou déjà présents ?
4. **Identités existantes :** certains utilisateurs existent-ils déjà dans le domaine cible ? Comment gérer les correspondances et les conflits ?
5. **SourceAnchor :** confirmer uniquement, pour l'instant, qu'il ne sera pas repris. La stratégie Entra ID sera étudiée séparément.
6. **Adresses SMTP :** qui modifiera manuellement les `proxyAddresses`, à quel moment et selon quelle procédure de validation ?
7. **Exécution :** qui fournit les droits source et cible, approuve le pilote, valide les résultats et autorise le passage en production ?

## Mail proposé à l'équipe (anglais)

**Subject:** Quest Directory Sync Pro — Identity Migration Pilot Prerequisites

Hi team,

To move forward with the Quest Directory Sync Pro identity migration pilot, could you please help confirm the following points?

1. Which users and groups should be included in the initial pilot?
2. Which AD attribute and values should be used to identify users for each migration wave?
3. Should all group memberships be preserved, including nested groups? Will the corresponding groups already exist in the target domain?
4. Are any of the pilot users already present in the target AD, and how should matching conflicts be handled?
5. We have agreed that SourceAnchor will not be migrated. We will review the Entra ID implications separately.
6. Who will be responsible for manually updating the SMTP proxy addresses, and at which stage?
7. Who will validate the source and target permissions, approve the pilot scope, and sign off on the results?

Once these points are confirmed, I can review the existing Quest synchronization profile and prepare the pilot execution and validation checklist.

Thanks.

## Travail technique à mener en parallèle

Examiner le profil **Test Users Sync** : OU source, OU cible, matching `sAMAccountName`, règles de mapping et options de synchronisation. Vérifier précisément le périmètre des OU avant toute exécution pour éviter la synchronisation d'utilisateurs hors pilote.

**Priorité :** obtenir la liste des utilisateurs pilotes et l'attribut de sélection.

> Ce document reprend les questions et le texte du mail proposés. Il ne constitue ni une approbation client ni une autorisation de lancer une synchronisation.
