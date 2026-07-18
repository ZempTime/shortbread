# Shortbread

Shortbread is a single bounded context for publishing prebuilt private websites, granting named people access, and carrying feedback from viewers back to producers. This glossary is the canonical language for specs, issues, UI copy, tests, and code.

## Publishing

**Site**:
A stable private website with its own slug, origin, access policy, and current Release.
_Avoid_: Project, share, artifact

**Bundle**:
The complete local directory a Producer submits as the content of a prospective Release.
_Avoid_: Build, package, upload

**Release**:
An immutable, numbered publication of one Bundle for one Site.
_Avoid_: Version, deployment, revision

**Blob**:
One immutable file body identified by its content hash and reusable across Releases.
_Avoid_: Asset when referring to stored content, object

**Manifest Entry**:
The mapping from one safe Site path to a Blob, content type, size, and offline policy within a Release.
_Avoid_: File row, asset record

**Producer**:
A human-operated CLI, CI job, agent, or other operator-controlled system that publishes Bundles and retrieves Feedback Threads through the API.
_Avoid_: Publisher when referring to a person, author

## People and Access

**Operator**:
The person who installs, configures, deploys, upgrades, backs up, and recovers one Shortbread installation.
_Avoid_: Administrator when referring to infrastructure ownership

**Owner**:
The installation's single permanent product authority, with control over Sites, People, Grants, Invitations, Releases, Feedback Threads, and View Receipts.
_Avoid_: Admin, publisher, superuser

**Person**:
A named individual in the Owner's reusable roster, independent of access to any particular Site.
_Avoid_: User, account, contact

**Viewer**:
A Person acting through a valid Grant to open and interact with a Site.
_Avoid_: Guest, member, user

**Grant**:
The Owner's revocable authorization for one Person to access one Site, including whether that Viewer may keep an Offline Copy.
_Avoid_: Permission, membership, share

**Invitation**:
A preview-safe, one-time credential that lets its intended Person activate a Grant without a password or pre-existing account.
_Avoid_: Magic link, login link, invite when naming the record

**Shelf**:
The apex-origin page listing the Sites a Viewer can currently access.
_Avoid_: Dashboard when referring to the Viewer surface, library

## Iteration and Viewing

**Feedback Thread**:
The single flat chronological conversation attached to a Site across its Releases.
_Avoid_: Inbox, review, approval workflow

**Comment**:
One append-only message in a Feedback Thread, attributed to a Person and anchored automatically to a Release and Site path.
_Avoid_: Reply, annotation, task

**View Receipt**:
An Owner-only record that a Viewer successfully opened a particular Release.
_Avoid_: Analytics event, read receipt when implying group visibility

**Offline Copy**:
A Viewer-initiated, browser-managed cache of one complete eligible Release that may survive Grant revocation and browser storage pressure.
_Avoid_: Download when referring to the managed Site cache, sync
