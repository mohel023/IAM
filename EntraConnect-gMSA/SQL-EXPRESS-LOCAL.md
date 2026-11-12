# Entra Connect Sync — SQL Express local (design decision)

## Confirmed
- Custom installation.
- SQL Server Express installed locally by the Entra Connect installer.
- **Use an existing SQL Server: unchecked**.
- Intended ADSync service identity: dedicated gMSA (validate support for the exact installed build and selected SQL Express deployment mode before proceeding).
- AD DS connector uses a separate least-privilege account.

## Pre-install gates
1. Confirm the exact Entra Connect Sync build and SQL Express version it bundles; review Microsoft's current support matrix and release notes.
2. Confirm object count and database growth projections fit SQL Express limits, plus sufficient disk/CPU/RAM.
3. Confirm gMSA support for this exact wizard combination; if wizard rejects gMSA with bundled SQL Express, **stop and document the conflict**. Do not silently replace it with a domain account or change service identity post-installation.
4. Confirm KDS root key fully replicated and gMSA password retrieval permitted for the Connect server.
5. Validate gMSA locally with Test-ADServiceAccount.
6. Ensure no other Entra Connect instance is actively exporting for the same objects without an approved staging/cutover design.
7. Confirm AD DS connector delegated permissions, source anchor, OU scope, PHS/writeback and accidental deletion thresholds.

## Wizard choices
- Customize > Install required components.
- Leave **Use an existing SQL Server** unchecked.
- Use an existing service account > Managed Service Account only after checking compatibility of the specific build and bundled SQL installation.
- Supply DOMAIN\\gmsaName$ if accepted by the wizard; do not enter a gMSA password.
- Configure separate AD DS connector identity at the AD forest step.

## Validation
- Verify ADSync service starts under the expected identity.
- Verify local database creation and database access.
- Verify sync scheduler and connectors; run staged validation before exports.
- Back up configuration and encryption key per documented recovery procedures.
- Do not publish internal identifiers, secrets, screenshots or architecture documents to this public repository.
