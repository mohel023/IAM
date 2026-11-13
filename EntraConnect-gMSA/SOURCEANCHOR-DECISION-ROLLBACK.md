# Decision gate — Uniquely identifying your users (Entra Connect Sync)

**STOP before Next / Configure** until the HLD and current tenant state are verified. This runbook is generic and contains no tenant or client details.

## Wizard decision matrix

| Check | Decision |
| --- | --- |
| Each person represented once across all connected AD forests | **Users are represented only once across all directories** |
| Same person has account/resource objects in multiple forests | **User identities exist across multiple directories**; choose matching only after confirming real attributes and topology (mail, objectSID/msExchMasterAccountSID/msRTCSIP-OriginatorSID, sAMAccountName/MailNickName, or a validated specific attribute) |
| Fresh deployment, no conflicting existing sourceAnchor policy, no custom anchor mandated by HLD | **Let Azure manage the source anchor** is generally appropriate |
| Existing Entra Connect/Cloud Sync, migrated forest, existing cloud immutable IDs, or prescribed HLD anchor | Confirm actual sourceAnchor and matching; **do not override** until equivalence is demonstrated |

SourceAnchor is effectively immutable for an object's lifetime. For new installs, Microsoft selection often uses msDS-ConsistencyGuid, otherwise objectGUID depending on existing usage/policy. Entra Connect may write objectGUID into blank msDS-ConsistencyGuid values; **staging mode is not an AD-write rollback mechanism**.

## Mandatory pre-change evidence (read-only)

1. Identify all existing Entra Connect Sync and Cloud Sync instances, active/staging state, scheduler, connector scopes, and existing sourceAnchor policy.
2. Inventory AD forests, trusts, user/resource-forest arrangements, enabled/disabled user pairs, contacts, and duplicate identities.
3. Inspect msDS-ConsistencyGuid population and objectGUID for the intended OUs, plus UPN, mail, proxyAddresses, SID, and Exchange hybrid attributes where relevant.
4. Inventory cloud users and onPremisesImmutableId/onPremisesSyncEnabled, including cloud-only users, admin/PIM accounts, licensed identities, and possible UPN/SMTP matches.
5. Compare intended OU/domain filters, excluded Tier-0/admin OUs, and all matching conflicts. Do not sync preexisting cloud admin accounts by default.
6. Confirm AD DS Connector has least-privilege permissions, including the rights necessary for msDS-ConsistencyGuid when used, and PHS replication rights if enabled.
7. Capture current sync configuration, connector rules, scheduler settings, and tenant sync status securely. Record approval and restoration owner.
8. Plan staging mode, import/sync, and review of pending exports **before** enabling exports. Confirm accidental deletion protection and rollback owner.

## Recovery boundaries

- **Before Configure:** use Previous/exit; no sync export yet, but separately check whether any earlier wizard step already changed configuration.
- **After configuration in staging:** cloud exports are disabled, but local AD writes (including possible msDS-ConsistencyGuid population) may have occurred. Save original values before install. Do not bulk clear or rewrite anchor attributes.
- **After cloud export:** stopping scheduler/staging prevents future exports; it **does not undo** cloud changes, source-of-authority takeover, or PHS. Restoration requires per-object mapping and approved remediation, not a universal undo.
- Keep any preexisting active sync server as the sole exporting server; never activate two exporters simultaneously.

## Validation / go-no-go

GO only when topology, sourceAnchor, matching report, exclusions, export preview, backup and rollback plan are signed off. NO-GO if any of these are unknown or unexpected cloud takeover/deletion appears.

## Microsoft documentation
- https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-custom
- https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-existing-tenant
- https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-sync-staging-server
- https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/tshoot-connect-source-anchor

**Never commit inventory, raw reports, domains, DNs, user names, or secrets to a public repository.**
