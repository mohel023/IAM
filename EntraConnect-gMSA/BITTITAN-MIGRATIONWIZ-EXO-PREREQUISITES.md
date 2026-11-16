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

**Subject:** BitTitan MigrationWiz – Source Tenant Prerequisites and Configuration

Hi Team,

Following our discussions, we are preparing the Exchange Online mailbox migration using BitTitan MigrationWiz and would like to confirm the prerequisites and configuration required on the source tenant.

Based on the BitTitan documentation, when using the EWS/OAuth application-permissions method, a dedicated Entra ID application needs to be registered and configured on both the source and target tenants.

We will handle the target tenant configuration, but we will need your support with the following items on the source side.

**1. Application registration and permissions**

- Register a dedicated application in Microsoft Entra ID.
- Configure the required Exchange Online API permissions:
  - Application permission: `full_access_as_app`
  - Delegated permission: `EWS.AccessAsUser.All`, where required by the selected BitTitan configuration.
- Grant administrator consent for the required permissions.
- Provide the Tenant ID and Application (Client) ID.
- Prepare a client secret if required. We can agree on a secure way to share it.

**2. Application access scoping**

For security reasons, we would like to restrict the application's access to the mailboxes included in the migration scope, rather than allowing unrestricted access to the entire Exchange Online environment.

Could you please review the available options for scoping the application permissions on the source tenant? We can validate the appropriate approach together during the configuration session, including testing access to both authorized and unauthorized mailboxes.

**3. Administrator account**

Could you also prepare a dedicated admin account with the necessary privileges to perform the application registration, grant admin consent and configure the required Exchange Online settings?

The account can remain under your team's control and be used during our working session.

**4. Exchange Online prerequisites**

We will also need to:

- Confirm that EWS access is available for the migration.
- Review any EWS application access restrictions or allow-list requirements.
- Check whether any existing security policies could prevent MigrationWiz from accessing the source mailboxes.
- Validate connectivity to the source Exchange Online environment.

**5. Working session**

To complete these activities, could you please let us know when you would be available for a **half-day working session**?

The idea would be to configure the application together, review and validate the permissions and access restrictions, and perform an initial MigrationWiz connectivity test.

**Official BitTitan documentation**

- Exchange Online to Exchange Online Migration Guide:
  https://help.bittitan.com/hc/en-us/articles/6488570876955-Exchange-Online-Microsoft-365-to-Exchange-Online-Microsoft-365-Mailbox-Migration-Guide
- Mailbox and Archive Migration using API Permissions:
  https://help.bittitan.com/hc/en-us/articles/27481872521115-M365-Mailbox-and-Archive-Migrations-Performing-Migration-using-only-API-permissions
- Microsoft 365 Authentication Methods:
  https://help.bittitan.com/hc/en-us/articles/360034124813-Authentication-Methods-for-Microsoft-365-All-Products-Migrations

Please let us know if you have any questions or concerns regarding the proposed configuration.

Thanks in advance for your support.

Best regards

---
**Implementation note:** This draft assumes the EWS/OAuth method. Confirm the selected BitTitan workflow and whether its permission model supports mailbox-level scoping before committing to a restriction mechanism. An EWS allow-list does not by itself restrict which mailboxes an authorized app can access.

**Security:** Do not commit internal tenant IDs, production domain names, secrets, usernames or customer identifiers to this public repository.
