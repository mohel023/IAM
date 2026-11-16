# BitTitan MigrationWiz — Exchange Online source and target prerequisites

Scope: Exchange Online mailbox migration between two Microsoft 365 tenants. SharePoint (ShareGate) and AD domain migration (Quest Migration Manager) are out of scope.

## Important decision before configuration
Confirm whether the project will use **EWS/OAuth** or **Microsoft Graph** with MigrationWiz. Do not combine permission lists from different authentication methods. Verify the current BitTitan guide and licensing/support for the selected method before granting consent.

## EWS/OAuth — customer-owned application configuration
For the BitTitan EWS application-permissions configuration, prepare **separate Entra application registrations in the source and target tenants**. For each tenant:
1. Register a dedicated application and record the **tenant ID** and **application (client) ID**.
2. Configure the API permissions documented by BitTitan for the chosen EWS migration procedure. The BitTitan EWS procedure includes Exchange Online **application** permission `full_access_as_app` and may list **delegated** `EWS.AccessAsUser.All`; confirm which are actually used for the chosen workflow rather than granting unnecessary access.
3. Have an authorized tenant administrator grant **admin consent**.
4. Create and securely distribute a client secret if required by that workflow; **never send secrets by email or commit them to GitHub**.
5. Validate EWS availability, any Exchange Online EWS application access policies/allow-lists, and access to the pilot mailboxes. Check the exact allow-list format and configuration against the current BitTitan instructions.
6. Run MigrationWiz endpoint verification and a pilot before wider migration.

The **source team** should supply tenant ID, application ID, confirmation of granted permissions/admin consent, confirmation of required Exchange access and a technical contact. Share any secret only via an approved secret-management channel. The **target team** performs the equivalent target-side setup.

## Graph option
BitTitan also documents Graph-based authentication, including BitTitan-managed and customer-owned app paths. **App registration ownership and API permissions differ** from the EWS procedure; do not assume the EWS registration/permission matrix applies. Review the Graph documentation before requesting source-side changes.

## Source mailbox information for migration planning
Request mailbox list, primary SMTP/UPN, mailbox type, size, archive presence, and any migration-relevant access or policy restrictions. The migration application should be tested on a pilot mailbox.

## Official BitTitan documentation
- [Exchange Online to Exchange Online mailbox migration guide](https://help.bittitan.com/hc/en-us/articles/6488570876955-Exchange-Online-Microsoft-365-to-Exchange-Online-Microsoft-365-Mailbox-Migration-Guide)
- [Microsoft 365 authentication methods](https://help.bittitan.com/hc/en-us/articles/360034124813-Authentication-Methods-for-Microsoft-365-All-Products-Migrations)
- [M365 mailbox and archive migration using API permissions](https://help.bittitan.com/hc/en-us/articles/27481872521115-M365-Mailbox-and-Archive-Migrations-Performing-Migration-using-only-API-permissions)
- [Graph API authentication using BitTitan app](https://help.bittitan.com/hc/en-us/articles/55707316319387-Authentication-Requirements-for-Graph-API-using-the-BT-App)

## Email draft to source team (EWS/OAuth path only)

**Subject:** BitTitan MigrationWiz — Source Tenant Application Setup

Hi Team,

For our Exchange Online mailbox migration with BitTitan MigrationWiz, we are planning to use the EWS/OAuth application-permissions method, subject to final confirmation of the authentication approach.

For this method, a dedicated Entra ID application registration and the relevant Exchange Online API permissions are needed in **both the source and target tenants**. We will handle the target-side configuration.

Could you please arrange the following on the source tenant:
- Register a dedicated Entra ID application and share its Tenant ID and Application (Client) ID.
- Configure the Exchange Online application permission `full_access_as_app` and review the BitTitan EWS procedure for any additional permission requirements, including `EWS.AccessAsUser.All` where applicable.
- Have an authorized administrator grant consent.
- Check the EWS access settings and any application access restrictions for the pilot mailboxes.
- Confirm who can coordinate the initial endpoint connectivity test.

If the selected workflow requires a client secret, please use an approved secure channel rather than email.

BitTitan documentation:
- https://help.bittitan.com/hc/en-us/articles/27481872521115-M365-Mailbox-and-Archive-Migrations-Performing-Migration-using-only-API-permissions
- https://help.bittitan.com/hc/en-us/articles/360034124813-Authentication-Methods-for-Microsoft-365-All-Products-Migrations
- https://help.bittitan.com/hc/en-us/articles/6488570876955-Exchange-Online-Microsoft-365-to-Exchange-Online-Microsoft-365-Mailbox-Migration-Guide

Please let us know once these items are ready, or if you have any questions.

Best regards

---
**Security:** No internal tenant IDs, production domain names, secrets, usernames or customer identifiers belong in this public repository.
