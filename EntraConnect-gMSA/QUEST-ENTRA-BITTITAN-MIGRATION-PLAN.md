# Quest / Entra ID / BitTitan — Architecture et préparation de migration

> **Document de travail assaini — 23 novembre 2026.** Aucune information d'identification client, capture d'écran, mot de passe ou nom de domaine interne. Les éléments « observés » proviennent des revues de console rapportées ; les options d'architecture sont des propositions à valider.

## 1. Contexte et constats
- Migration entre deux forêts Active Directory et deux tenants Microsoft 365.
- Le domaine cible contient principalement quelques comptes IT préexistants ; la plupart des identités restent à créer.
- Migrator Pro for Active Directory et Directory Sync Pro for Active Directory sont en place.
- Profils Directory Sync observés : Devices, TEST2, Test Groups Sync, Test Users Sync. Des tests ont traité 2 utilisateurs et 12 groupes ; ce n'est pas une preuve de recette de bout en bout.
- Profil utilisateurs inter-forêts actif ; scope sur plusieurs OU source, OU cible définie.
- Matching observé : `sAMAccountName` ↔ `sAMAccountName`; conflits utilisateurs `UPDATE`, groupes `MERGE`, ordinateurs `SKIP`.
- Overrides observés : UPN, TargetAddress, BTCustom et expressions personnalisées. **Ne pas les modifier sans revue des effets.**
- AD cible vers nouveau tenant Entra ID via Entra Connect : **déclaré, mais paramètres exacts non audités**.
- Le mécanisme Quest permettant de sélectionner les utilisateurs par attribut AD n'est pas encore confirmé.

## 2. Modèle de délégation à implémenter

| Couche | Rôle / compte | Principe | Validation |
|---|---|---|---|
| Migrator Pro RBAC | Global Administrator | Administration globale réservée à des responsables habilités | Tester et documenter l'accès |
| Migrator Pro RBAC | Profile Administrator | Gestion de profils selon droits disponibles | Tester actions autorisées |
| Migrator Pro RBAC | Migration Operator | Exécution des migrations approuvées | Tester séparation des fonctions |
| Migrator Pro RBAC | Read Only User | Lecture des statuts et rapports | Vérifier absence d'écriture |
| AD source | Compte de service source | Lecture des OU et attributs nécessaires ; privilèges additionnels uniquement si justifiés | Consultants AD source |
| AD cible | Compte de service cible | Création / mise à jour des objets dans les OU approuvées ; exclusion des comptes privilégiés | Consultants AD cible |
| Entra / BitTitan | Comptes/applications dédiés | Droits minimaux distincts de Quest | Équipe M365 / sécurité |

Les quatre rôles RBAC ont été observés dans la console. Les permissions effectives des comptes techniques **ne sont pas démontrées**. Documenter les ACL OU, les propriétaires, les validations et les tests de moindre privilège. SIDHistory, mots de passe, ReACL et migration des postes nécessitent des décisions et prérequis spécifiques.

## 3. Migration d'identités par attribut
1. Définir **l'attribut de sélection** (nom, disponibilité, propriétaire, valeurs de vague, processus d'alimentation).
2. Distinguer sélection des comptes, matching source/cible et mapping des attributs.
3. Inventorier les comptes source/cible ; protéger les comptes IT déjà créés.
4. Vérifier collisions `sAMAccountName` et rechercher si une clé métier stable est préférable.
5. Confirmer la méthode **prise en charge par la version installée** pour appliquer le filtrage par attribut.
6. Préparer un profil pilote isolé, des tests de création et de mise à jour, puis une recette formelle.
7. Conserver un rapport de correspondance avant/après, des journaux et un rollback testé.

## 4. Synchronisation AD cible → nouveau tenant Entra ID

**Architecture déclarée, à auditer** : les objets créés dans AD cible peuvent être synchronisés vers le nouveau tenant selon le scope Entra Connect. Vérifier :
- OU filtering et population réellement incluse ;
- `sourceAnchor` / `msDS-ConsistencyGuid`, soft/hard match, utilisateurs cloud déjà présents ;
- UPN, `mail`, `proxyAddresses`, `targetAddress`, attributs Exchange hybrides et doublons ;
- séquence de provisioning des utilisateurs et boîtes, licences, comptes IT exclus ;
- éventuelles règles de synchronisation personnalisées, staging mode, santé des exports.

**Ne pas supposer qu'une identité créée dans AD cible possède automatiquement une boîte Exchange Online cible.**

## 5. Coexistence des messageries pendant la migration

| Population | Identité | Boîte active | Routage attendu |
|---|---|---|---|
| Non migrée | Source AD / ancien tenant | Ancien tenant | Messages délivrés à la source |
| Préparée | Cible AD / nouveau tenant | À provisionner selon design | Éviter double livraison et doublons |
| Migrée | Cible AD / nouveau tenant | Nouveau tenant | Messages délivrés à la cible |

### Deux architectures à arbitrer
- **Même domaine SMTP primaire** : un domaine vérifié ne peut pas être simultanément attaché comme domaine accepté principal aux deux tenants de façon ordinaire. Prévoir stratégie de coexistence via domaines de routage techniques, objets MailUser/contacts et, si nécessaire, connecteurs/réécriture ; définir précisément le transfert du domaine, les adresses, les DNS et la bascule.
- **Domaines SMTP différents** : chaque tenant peut recevoir pour son domaine ; prévoir aliases, forwarding ou connecteurs et stratégie d'identité expéditeur/réponse.

Dans les deux cas, définir les chemins **source→cible**, **cible→source**, **externe→source**, **externe→cible**, groupes, réponses et non-remise. Tester anti-boucle et NDR. **BitTitan MigrationWiz copie les données ; il ne met pas en place le routage des messages.**

### Relation directe avec les règles Quest observées
- `UserPrincipalName` : alignement de l'identité de connexion cible, pas nécessairement égal au SMTP principal.
- `TargetAddress` : peut orienter la livraison vers une destination de coexistence **selon le type de destinataire et la configuration Exchange** ; ne pas confondre avec une règle universelle de forwarding.
- `proxyAddresses` et `mail` : unicité et propriété des adresses entre environnements ; revoir la synchronisation Entra.
- `BTCustom` : finalité inconnue ; documenter chaque expression avant modification.
- `UPDATE` et `MERGE` : protéger comptes IT et groupes existants, comparer avant/après.

## 6. Déroulement proposé
1. Baseline Quest et audit des profils, mapping, comptes et journaux.
2. Atelier délégation et validations AD source/cible.
3. Audit Entra Connect et objets cloud existants.
4. Atelier Exchange Online / mail flow : même domaine ou domaines différents, routing domains, connecteurs, MailUsers, transfert de domaine.
5. Choix de l'attribut de sélection et du matching ; export population.
6. Pilote 5–10 utilisateurs non privilégiés et groupes représentatifs.
7. Vérification création AD cible, synchronisation Entra, provisioning boîte et permissions.
8. Pré-stage BitTitan ; tests de coexistence bidirectionnels.
9. Cutover approuvé : delta final, mail routing, postes/ReACL si dans le périmètre.
10. Hypercare, rapprochement et nettoyage après validation.

## 7. Questions bloquantes
1. Which attribute will be used to identify migration waves, and who will populate it?
2. Are the existing IT target accounts to be excluded, matched or migrated separately?
3. Is the existing sAMAccountName matching safe for all populations?
4. What are the exact source and target service account permissions?
5. What OU scope, sourceAnchor and custom rules are configured in Entra Connect?
6. Will both tenants use the same primary SMTP domain, and when will it be transferred?
7. Which coexistence routing domains, recipient objects and connectors will be used?
8. What is the purpose of the current UPN, TargetAddress and BTCustom overrides?
9. Who owns the BitTitan pre-stage, delta and cutover?
10. What are the GO/NO-GO and rollback criteria?

## 8. Décisions P0
- **D01** Valider attribut et mécanisme de sélection.
- **D02** Auditer Entra Connect, sourceAnchor et règles de synchronisation.
- **D03** Valider architecture de routage Exchange intertenant et domaine SMTP.
- **D04** Vérifier matching et conflits Quest, comptes IT et groupes.
- **D05** Documenter les overrides UPN/TargetAddress/BTCustom.
- **D06** Valider délégation RBAC et permissions AD effectives.
- **D07** Autoriser un pilote avec preuves de recette et rollback.

> Aucun changement de production n'est recommandé avant validation conjointe AD, Entra, Exchange, sécurité et chef de projet.


## 9. Annexe opérationnelle — délégation AD source
| Fonction | Droit à vérifier | Preuve |
|---|---|---|
| Découverte Quest | Lecture OU, objets et attributs nécessaires ; compte de service dédié | Inventaire source et test d'accès |
| Synchronisation | Lecture groupes, membres et attributs ; écriture source uniquement si fonction documentée | Journaux + comparaison |
| Mot de passe | Prérequis spécifiques du composant Quest ; un mot de passe AD n'est pas lisible par simple délégation | Pilote authentification |
| SIDHistory | Fonction facultative, prérequis inter-forêts, droits privilégiés et validation sécurité | Décision et test ACL historiques |
| ReACL | Accès aux postes, fichiers et ACL selon agents, distinct de l'AD | Pilote restauration |
| Sélection par attribut | Lecture de l'attribut par Quest, écriture contrôlée par l'équipe source | Valeurs et population validées |

**Important :** la liste des ACL exactes dépend de la version de Quest, des composants activés et des opérations choisies. Ne pas accorder Domain Admin ou Enterprise Admin comme délégation par défaut.

## 10. Annexe opérationnelle — matrice mail flow
| Émetteur | Destinataire | Comportement cible | Test |
|---|---|---|---|
| Internet | Non migré | Livraison source | Trace externe→source |
| Internet | Migré | Livraison cible, éventuellement via tenant source avant transfert SMTP | Trace externe→cible |
| Non migré | Migré | Résolution source vers adresse de routage technique cible | Source→cible |
| Migré | Non migré | Résolution cible vers adresse de routage technique source | Cible→source |
| Migré | Migré | Livraison locale cible | Cible→cible |
| Non migré | Non migré | Livraison locale source | Source→source |

**Décisions obligatoires :** propriétaire du domaine SMTP à chaque phase ; domaine(s) de routage ; MailUser/contact ; accepted domains ; connecteurs éventuels ; transfert du domaine ; MX, SPF/DKIM/DMARC ; retour arrière. **BitTitan migre les données, pas le mail flow.** Le comportement de `targetAddress` dépend du type d'objet et de la configuration Exchange.

## 11. Vérifications techniques en lecture seule
```powershell
# Sur le serveur Entra Connect
Get-ADSyncScheduler | Format-List *
Get-ADSyncRule | Select-Object Name,Direction,Precedence,Disabled

# Exchange Online, dans chaque tenant
Get-AcceptedDomain | Select-Object Name,DomainName,DomainType,Default
Get-InboundConnector
Get-OutboundConnector
Get-TransportRule | Select-Object Name,State,Mode
Get-Recipient -Identity "user@example.com" |
  Format-List RecipientTypeDetails,PrimarySmtpAddress,ExternalEmailAddress,EmailAddresses
```
Adapter identités et accès ; ces commandes ne remplacent pas l'audit complet du tenant.

## 12. Next steps techniques P0/P1
1. **J1** Baseline Quest : profils, scope OU, schedules, matching, overrides, journaux et version.
2. **J1** Atelier AD source : comptes techniques, ACL, exclusions IT/Tier0, mots de passe, SIDHistory.
3. **J2** Audit Entra Connect : OU filtering, sourceAnchor, règles custom, exports et objets cloud existants.
4. **J2** Atelier Exchange : même domaine SMTP ou non, tenant receveur, routage bidirectionnel, MailUsers et connecteurs.
5. **J3** Revue ligne par ligne des overrides Quest UPN/TargetAddress/BTCustom ; définir attribut de vague.
6. **J4** Pilote création AD cible et synchronisation Entra ; contrôles anti-doublon.
7. **J4–J5** Pilote BitTitan + mail flow 2×2 + externe, réponses, DL, NDR, rollback.
8. **Après GO** Préparation des postes, ReACL, cutover par vagues et hypercare.

## 13. Questions bloquantes en atelier
- Which exact source AD service-account permissions are required by the enabled Quest operations, and who grants them?
- Are password migration and SIDHistory required, and which supported Quest mechanisms are selected?
- Which source attribute selects migration waves, and is filtering supported by the installed build?
- Are the existing IT accounts excluded from Quest UPDATE/MERGE operations?
- What OU scope, sourceAnchor and custom sync rules are active in target Entra Connect?
- Which tenant owns the primary SMTP domain now and after each cutover?
- What recipient objects and routing domains implement source-to-target and target-to-source mail flow?
- Who owns the Quest UPN, TargetAddress and BTCustom transformations, and what do they output?
- What is the exact BitTitan pre-stage/final delta/activation sequence?
- What evidence and rollback criteria are required for GO/NO-GO?
