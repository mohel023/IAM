# First Sync — automated AD/Entra identity matching preflight

Scenario: first AD domain sync to a tenant with **existing cloud users** and **Entra-joined/Intune-managed devices**.

## Prerequisites
- Windows PowerShell 5.1 on a domain-joined admin workstation/server with RSAT ActiveDirectory.
- Microsoft Graph PowerShell **Microsoft.Graph.Authentication** module, e.g. \`Install-Module Microsoft.Graph.Authentication -Scope CurrentUser\` after enterprise approval.
- Authorized Entra identity with delegated read scopes; do **not** activate Global Administrator merely for this report.
- Network access to AD and Graph. Run outside the Git checkout if possible.

## Connect and run
\`\`\`powershell
Connect-MgGraph -Scopes 'User.Read.All','Directory.Read.All'
.\11-Test-EntraConnect-FirstSync.ps1 -SearchBase 'OU=Pilot,DC=example,DC=com'
\`\`\`
Replace the example OU DN. For a specific DC add \`-AdServer 'dc.example.com'\`. The script excludes disabled AD users by default; use \`-IncludeDisabledADUsers\` to include them.

## Checks
- AD users in the explicit scope; UPN and SMTP duplicates in that scope.
- Cloud user inventory via paginated Graph read calls.
- Potential matches by UPN, mail, SMTP proxy addresses, and proposed sourceAnchor.
- Existing \`onPremisesImmutableId\`, \`onPremisesSyncEnabled\`, cloud license presence.
- Flags ambiguous matches, mismatched immutable IDs and already-synced identities.
- Produces local CSV (per-object sensitive data), JSON summary and Markdown recommendations under TEMP.

**All findings are provisional**. Matching rules, Exchange attributes, device registration, Intune, cloud role assignments, forest topology and sourceAnchor selection require manual validation. The report does **not** verify Intune device state or certify rollback. The script does not change AD, Graph, Entra Connect, GPO, passwords or MFA.

## Required rollback gate
1. Inventory and securely back up relevant AD and cloud attributes, identities, licenses, Intune enrollment and policies.
2. Confirm no existing sync engine; verify matching and exclusions.
3. Use staging mode for the first deployment and review pending exports and projected joins before permitting exports.
4. Remember: staging prevents cloud exports, **not necessarily AD-side writes** such as \`msDS-ConsistencyGuid\` initialization.
5. After exports, changes to source of authority, PHS and cloud identities may not be automatically reversible.

**No automatic GO.** Review all potential matches and get change approval before configuring production exports.

**Security:** outputs contain real UPNs, DNs, immutable IDs, GUIDs and tenant metadata. Keep them internal, do not upload to the public GitHub repository, and delete them under the retention policy.
