# Quest AD identity migration — generic pilot checklist

> Reusable template only. No customer identifiers, actual environment settings, credentials, internal decisions, or production exports should be committed to this repository.

## Scope and ownership
- [ ] Confirm identity migration owner and separate ownership of server migration.
- [ ] Obtain approved pilot user and group inventory through an authorized private channel.
- [ ] Define inclusion/exclusion criteria and wave selection method; verify actual tool support before configuring attribute-based filters.
- [ ] Define source/target domain technical owners and pilot sign-off authority.

## Identity matching and directory sync
- [ ] Inventory existing target objects and identify potential collisions.
- [ ] Review source/target OU scope, including sub-OUs, disabled users and non-mail-enabled objects.
- [ ] Review matching rules and mapping/override transformations without changing production configuration.
- [ ] Define sourceAnchor strategy with the identity team; verify Entra Connect and cloud identity continuity independently.
- [ ] Define how groups are synchronized or migrated, and validate direct/nested memberships and group scopes in a pilot.
- [ ] Establish a controlled plan for SMTP proxy address changes with messaging owners; validate uniqueness and mail routing.

## Security and access
- [ ] Use named operator accounts and least-privilege access.
- [ ] Validate authentication separately from application role authorization.
- [ ] Audit technical service-account permissions in source and target.
- [ ] Do not share passwords, secrets, real DNs or tenant identifiers in GitHub.

## Pilot readiness
- [ ] Confirm approved pilot scope and schedule.
- [ ] Capture baseline of identities, attributes, group memberships and mail addressing in secure storage.
- [ ] Validate synchronization profile scope and schedules before execution.
- [ ] Obtain go/no-go approval and rollback procedure.
- [ ] Test with noncritical identities and record actual results.
- [ ] Verify target identity, group membership, attribute mappings, application access and expected cloud linkage.
- [ ] Record exceptions and obtain sign-off before expanding waves.

## Questions for stakeholders
1. Which users and groups are in the approved pilot?
2. What selection mechanism identifies each wave, and is it supported in the installed tool version?
3. What memberships must be preserved, and are corresponding groups already present in the target?
4. How should existing target objects and collisions be handled?
5. What is the approved identity-anchor and cloud matching design?
6. Who owns manual SMTP address changes, their timing, and validation?
7. Who grants permissions, approves the pilot, and signs off on results?

## Safety
Do not run synchronization, ReACL, cutover or production changes solely from this template. Verify vendor-specific behavior and customer approvals first.
