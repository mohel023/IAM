# Quest Directory Sync Pro — questions et mail proposé (modèle anonymisé)

> Document générique. Aucun nom, domaine, attribut réel, valeur de sélection ou identifiant client.

## Questions restantes à valider

1. Quel est le périmètre utilisateur et groupe du pilote, et qui l'approuve ?
2. Le mécanisme de sélection par attribut déjà défini est-il pris en charge et correctement configuré dans le profil Quest installé ?
3. Les groupes étant absents de la cible, quel profil et quelles règles assureront leur création/synchronisation avant la validation des appartenances (portée, type, OU, groupes imbriqués) ?
4. Certains utilisateurs existent-ils déjà dans la cible ? Quelles règles de correspondance et de résolution des conflits appliquer ?
5. Quelle est la stratégie de continuité d'identité Entra ID ? La question de l'ancrage sera traitée séparément.
6. Qui effectuera manuellement les modifications des adresses SMTP, à quel moment et avec quelles validations ?
7. Qui valide les permissions techniques, le pilote, les résultats et l'autorisation de passage en production ?

## Proposed email (English)

**Subject:** Quest Directory Sync Pro — Identity Migration Pilot: Remaining Validations

Hi team,

As the AD attribute used to select identities has already been agreed, and the corresponding groups do not yet exist in the target domain, could you please help confirm the remaining pilot prerequisites?

1. Which users and groups are approved for the initial pilot, and who signs off on the scope?
2. Can we validate how the agreed selection attribute is applied in the current Quest synchronization profile?
3. What is the approved approach for creating or synchronizing the missing groups in the target domain, including group scope, destination OU, nested groups, and membership preservation?
4. Are any pilot users already present in the target AD, and how should matching conflicts be handled?
5. We will review the Entra ID identity-anchor implications separately.
6. Who will manually update the SMTP proxy addresses, at which stage, and how will the changes be validated?
7. Who will validate source and target permissions, approve the pilot, and sign off on the results?

Once these points are confirmed, I can review the existing Quest synchronization profile and prepare the pilot execution and validation checklist. No synchronization will be launched before approval.

Thanks.

## Technical checks

- Review user and group synchronization profiles and source/target OU scope.
- Confirm group object creation/synchronization is configured; enabling group membership alone does not establish that missing group objects will be created.
- Validate selection, matching, mapping and scheduling in the installed Quest version.
- Run a controlled pilot only after approval; verify users, groups and direct/nested memberships.
