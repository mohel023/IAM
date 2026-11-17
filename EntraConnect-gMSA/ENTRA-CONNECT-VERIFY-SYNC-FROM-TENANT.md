# Vérifier la synchronisation Microsoft Entra Connect depuis le tenant

Ce guide concerne **Microsoft Entra Connect Sync** (anciennement Azure AD Connect), après sortie du mode staging. Il ne concerne ni le service BitTitan MigrationWiz ni la validation du fonctionnement PHS.

## Portail Entra

1. Ouvrir https://entra.microsoft.com, sélectionner le **bon tenant**.
2. **Entra ID > Users > All users**, ouvrir un compte pilote connu.
3. Examiner les propriétés **On-premises sync enabled** et **On-premises last sync date time** si affichées.
4. Contrôler qu'il s'agit bien de l'objet cloud préexistant, et non d'un doublon ; comparer son **Object ID** avec l'identifiant relevé avant la synchronisation.

## Attributs Microsoft Graph exacts

- `onPremisesSyncEnabled` : `true` = objet actuellement considéré comme synchronisé depuis l'AD local. Ce champ seul ne prouve pas qu'un cycle récent a réussi.
- `onPremisesLastSyncDateTime` : date/heure UTC du dernier traitement de synchronisation indiqué pour l'objet. Une date récente est un indice utile, **pas une preuve exhaustive du succès de tous les exports**.
- `onPremisesImmutableId` : identifiant d'ancrage de l'objet local, utile pour le rapprochement.
- `onPremisesSecurityIdentifier` : SID local exposé, si disponible.

~~~powershell
Connect-MgGraph -Scopes "User.Read.All"
Get-MgUser -UserId "utilisateur@exemple.com" `
  -Property "id,displayName,userPrincipalName,onPremisesSyncEnabled,onPremisesLastSyncDateTime,onPremisesImmutableId,onPremisesSecurityIdentifier" |
  Select-Object Id,DisplayName,UserPrincipalName,OnPremisesSyncEnabled,OnPremisesLastSyncDateTime,OnPremisesImmutableId,OnPremisesSecurityIdentifier |
  Format-List
~~~

Ne pas enregistrer dans ce dépôt public les UPN, SID, ID d'objet ou identifiants de tenant réels.

## Critères de validation

- `onPremisesSyncEnabled=True` et date récente pour un utilisateur pilote : **synchronisation de cet objet visible dans Entra**.
- Objet cloud inchangé (même `id`) : rapprochement confirmé pour **cet utilisateur**.
- Pour confirmer le **cycle complet** et les exports, examiner aussi l'historique du moteur Connect Sync et les éventuelles erreurs dans Entra.
- **PHS se valide séparément** : ces attributs ne prouvent pas que les hachages de mots de passe sont synchronisés.
- Ne pas modifier des comptes ou relancer un cycle uniquement pour tester sans avoir vérifié les exports/suppressions potentiels.

Documentation Microsoft Graph : https://learn.microsoft.com/en-us/graph/api/user-get
