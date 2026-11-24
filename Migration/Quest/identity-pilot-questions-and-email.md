# Quest AD Migration — Source Domain Read-Only Access and Pilot Preparation

> Generic email template. No customer names, actual domains, account names, addresses, or environment identifiers.

## Proposed email (English)

**Subject:** Quest AD Migration – Source Domain Read-Only Access and Pilot Preparation

Hi team,

Following our previous discussions, I would like to follow up on my request for a **dedicated read-only account in the source Active Directory domain**.

This access is required to review the source AD structure, users, groups, group memberships and relevant attributes, and to perform the necessary checks before configuring the Quest identity migration pilot.

Could you please confirm when this account will be available?

**1. Identity migration pilot**

The AD attribute used to select users for migration has already been agreed.

Could you please confirm the initial pilot scope and the users to be included?

**2. Group migration – Recommended approach**

As the target domain does not currently contain the users or groups to be migrated, I recommend the following approach:

- Identify the groups associated with the pilot users, including nested group dependencies.
- Review group types, scopes and target OU placement.
- Configure and validate group creation and synchronization in Quest.
- Enable group membership preservation and verify direct and nested memberships.
- Compare the source and target results before extending the migration to additional users.

**3. Quest synchronization configuration**

I will review the existing Quest Directory Sync Pro profiles, including the agreed selection attribute, matching rules, attribute mappings and destination OUs.

As agreed, SourceAnchor will not be migrated. We will review the Entra ID implications separately.

**4. SMTP proxy addresses**

I will handle the manual updates of the SMTP proxy addresses, coordinating the timing with the messaging migration activities.

**5. Pilot validation**

Could you please confirm who will approve the pilot scope and authorize the first synchronization test?

Once the read-only access is available and the pilot scope is confirmed, I can finalize the configuration review and prepare the pilot validation checklist.

Thanks.

## Technical note

The read-only source-domain account is for consultation and audit; it does not replace Quest technical service accounts requiring permissions to create or modify target directory objects. Do not commit customer credentials, real account names, domains, or production exports.
