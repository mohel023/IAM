# Rapport d'activité hebdomadaire — Semaine 47 (16–20 novembre 2026)

> Version technique assainie pour dépôt GitHub. Ne pas publier de noms de clients, identifiants, domaines, captures ni secrets. Les durées non confirmées restent à renseigner.

## Répartition des journées

| Activité | Lun 16/11 | Mar 17/11 | Mer 18/11 | Jeu 19/11 | Ven 20/11 |
|---|---|---|---|---|---|
| Préparation domaine cible / LAPS | À compléter | À compléter | À compléter | À compléter | À compléter |
| Migration AD / Quest | À compléter | À compléter | À compléter | À compléter | **0,5 J** (état des lieux) |
| Accès à l'environnement / AVD | À compléter | À compléter | À compléter | À compléter | À compléter |

## Détail du travail réalisé

### Projet / sujet 1 — Préparation domaine cible : LAPS
- Préparation d'une documentation d'exploitation PowerPoint pour Legacy LAPS et Windows LAPS.
- Formalisation des procédures de configuration, délégation, GPO et filtres WMI.
- Documentation des contrôles de fonctionnement et de la consultation sécurisée des mots de passe.

### Projet / sujet 2 — Migration AD : Quest
- Diagnostic des difficultés d'accès à l'environnement via Windows App / AVD : méthodes Windows Hello, clé d'accès et Microsoft Authenticator.
- Vérification de l'authentification réussie sur Microsoft Security Info et analyse du blocage dans Windows App.
- **Vendredi 20/11 (0,5 J)** : état des lieux de Migrator Pro for Active Directory et Directory Sync Pro.
- Revue des quatre rôles RBAC existants et des références de connexion source/cible.
- Analyse des profils de synchronisation, OU source/cible, règles de matching et transformations d'attributs.
- Identification des prérequis pour une migration d'identités pilotée par attribut AD.

## Points en cours
- Validation du modèle de délégation Quest et préparation de la communication.
- Confirmation de l'attribut de sélection et définition du pilote de migration.
- Poursuite du diagnostic AVD avec l'équipe cliente.
- Finalisation et revue de la documentation d'exploitation LAPS.

## Précautions
- L'inventaire RBAC ne constitue pas une validation des permissions AD effectives.
- Aucune migration ou modification de synchronisation n'est déclarée comme exécutée dans ce rapport.
- Les temps autres que le vendredi après-midi ne sont pas confirmés.
