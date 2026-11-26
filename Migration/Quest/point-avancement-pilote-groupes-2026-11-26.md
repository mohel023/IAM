# Point d'avancement — Pilote Quest AD et groupes

**Date : 26 novembre 2026**  
**Statut : pilote groupes en cours — résultats non encore validés**

> Document générique et anonymisé. Aucune donnée d'identification du client, DN réel, domaine, nom de compte ou attribut métier confidentiel.

## 1. Contexte et architecture
Deux environnements Active Directory et deux tenants Microsoft 365. Quest Directory Sync Pro / Migrator Pro for Active Directory est utilisé pour les identités et les groupes. L'AD cible synchronise les identités vers Entra ID cible via Entra ID Connect. La migration des boîtes Exchange Online tenant-à-tenant via BitTitan est hors périmètre de validation du pilote groupes.

## 2. Travaux réalisés — utilisateurs
- Périmètre d'utilisateurs sélectionné à partir d'une OU source et d'un attribut de migration.
- Comptes synchronisés dans l'AD cible ; synchronisation des mots de passe activée pour le lot concerné.
- Comptes marqués « Migrated » dans Quest.
- Présence d'au moins un utilisateur pilote vérifiée dans Entra ID cible.

## 3. Contrôles Exchange sur un pilote
- `msExchMailboxGuid` et `msExchRecipientTypeDetails` non renseignés.
- Nouvelle adresse SMTP principale, ancienne adresse en alias et adresse historique X500.
- Nouveau domaine SMTP vérifié dans le tenant cible.
- **Provisionnement de la boîte cible non confirmé** ; ces contrôles ne valent pas validation globale.

## 4. Pilote groupes — configuration envisagée
- Deux familles de groupes réparties dans deux OU sources distinctes.
- Deux profils « Groups Only » envisagés, un par périmètre et destination.
- Les chemins et nomenclatures d'OU cibles diffèrent de ceux de la source : le placement réel doit être validé dans les simulations.
- Aucun filtre LDAP additionnel nécessaire à ce stade si les OU délimitent correctement le périmètre.

## 5. Appartenances et coexistence
- Vérifier la correspondance de chaque groupe source avec son groupe cible.
- Vérifier les appartenances des utilisateurs déjà migrés, les membres et les groupes imbriqués.
- Formaliser le choix One Time / Continuous Sync selon la durée de coexistence et les changements à propager.

## 6. État des validations
**Confirmé :** utilisateurs synchronisés dans l'AD cible, contrôles Exchange sur un pilote, OU sources des groupes identifiées.  
**En cours :** création et synchronisation pilote des groupes.  
**À confirmer :** résultats de simulation et d'exécution, DN cibles, appartenances, groupes imbriqués et absence de doublons.

## 7. Prochaines étapes
1. Examiner les simulations des profils groupes et valider les destinations avant exécution.
2. Réaliser la synchronisation pilote des groupes après approbation.
3. Comparer les appartenances source/cible sur un échantillon représentatif et documenter les écarts.
4. Définir les waves, les règles d'activation, les cadences One Time / Continuous, les rapports et le retour arrière.

**Critère de réussite :** groupes attendus présents dans les bonnes OU cibles, sans doublons, avec appartenances conformes pour les utilisateurs migrés.
