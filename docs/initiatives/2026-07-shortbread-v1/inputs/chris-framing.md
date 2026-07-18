# Chris's Framing: Shortbread v1

**Owner:** Chris
**Status:** Open for contribution
**Editing rule:** Rough fragments are preferred over premature synthesis. Change, delete, or contradict any seed material below.

## Ready Signal

- [ ] I have added the ideas and outcomes I currently want represented.
- [ ] This input is ready for Stage 00 synthesis.

Only Chris checks the second box or gives the equivalent instruction in conversation.

## Raw Riff

Drop anything here without organizing it first.

-

## Desired Outcomes

Seed prompts from the design conversation, not accepted statements. Complete, replace, or delete.

- I can publish the Italy mini-site and text Mom a link she opens in one tap, no account.
- I can put real names and booking numbers in a shared page without them ever being public on the internet.
- I can push release after release and see whose feedback landed on which release.
- Anyone I trust can keep a site on their phone and open it with no signal.
- Any of my systems — CLI, work packet, Claude session — can publish and pull feedback without special treatment.
- One page lists every site I can open, and each one installs to my phone on its own.

## First Real Audiences & Trust Tiers

Who actually gets links in the first month, and how sensitive is each share?

- Italy trip roster: everyone on the trip. Need full-on user management across different bundles — one roster of people, grants managed across sites, not ad hoc per share.
- Prototype reviewers: friends. Content is travel docs and projects we're working on together — not deeply private.
- Sensitive-records shares: booking confirmations. Server-side protection gated by auth is fine; no extra ceremony beyond auth.

## Concrete Journeys

Describe real episodes rather than generic features.

1. Italy trip (multi-page, Leaflet, offline in dead zones): sources are HTML, MD, or other local static-site outputs. Publish during planning, likely only during times with high internet availability and computer access — not mid-trip from a phone.
2. Prototype review (push, gather thread feedback, revise): same, it's HTML. Feedback must be place-agnostic — context that easily flows anywhere via the CLI. Collected and kept in the place, then available via the CLI; easy for agents to access and use.
3. A share that must stay out of AI entirely: not totally sure this category is real. Basic controls like setting up find-and-replace values would be great (decided: post-v1 idea; v1 ships private-bundle-files only). I don't care if AI sees booking values — I just don't want them publicly on the internet. If I don't want AI to see something, I shouldn't put it there; the key is I control that with how I use the tool.

## Offline Expectations

Whole site vs chosen pages, acceptable size, how updates should feel, what "remove from this device" means.

- Want a clear, good policy; unsure on exact scope. The important thing offline is the info — text etc.; maybe not all images/heavy media.
- Updates: visible, not silent — let viewers control the data (they decide when to download).
- Decided: per-site PWAs stay (own origin/icon/offline install), plus an apex shelf page listing every site you have access to — one bookmark-able hub, isolation and zero-rewrite serving preserved. No umbrella PWA.
- "Remove from this device" = an in-site button in the Shortbread-injected UI that clears that site's cached release and service worker.

## Feedback Expectations

What makes the thread feel like the group text pinned to the thing? What must it never become (approvals, workflows, an inbox)?

- One flat chronological thread per site, no nesting — reads like Messages.
- Every comment auto-tagged with the release + page it was written from, shown as a chip (`r12 · /day-3`) — "whose feedback landed on which release" costs commenters nothing.
- Identity = first name from the grant; no avatars, no profiles.
- Thread injected on every page, collapsed; expands like a pinned group chat.
- Feedback is place-agnostic context: collected and kept in the place, pulled via the CLI, easy for agents to access and use.
- Never: notifications of any kind from Shortbread; approve/resolve states; per-comment reply threads; group-visible read receipts (view log is owner-only). Reactions out of v1 — revisit only if the thread feels dead.

## Sensitive Content Rules

Your own bright lines for what may/may not enter a bundle, a log, or a model context.

- The bright line is "not publicly on the internet," not "never touches an AI." AI exposure is my per-use choice, controlled by how I use the tool — not a product guarantee Shortbread has to enforce.

## Open Decisions to Confirm, Amend, or Reject

Seeds from `design-notes.md` §Remaining PRD Decisions — react inline:

- Revocation vs offline per tier: no tier machinery — a per-site owner toggle "allow keep offline," default on. Revocation stated plainly: no new access, no updates; saved copies survive.
- Public-link tier in v1: no — invite-only until it hurts. Month-one audiences are all people known by name.
- Owner dashboard minimum / no viewer shelf: amended — viewers DO get a shelf: apex page lists every site you have access to. Owner side needs full-on user management across bundles (roster of people, grants per site).
- No delivery infrastructure (you text links yourself): confirmed — none, ever. Copy the invite link, text it yourself. No email/SMS/push anywhere in the product.
- Single-tenant permanently: yes — one owner forever. "Full-on user management" means viewers and grants, never other publishers.
- Export / deletion / backup: v1 = delete-site (revokes all grants, removes blobs) plus platform backups (PlanetScale/R2). `pull` round-trip export is post-v1 — bundle sources already live on my machines.
- Name collision with an unrelated local application — rename old, namespace new, or other: rename the unrelated application; this project takes the clean `shortbread` name locally and on GitHub.
- CLI name (`shortbread` vs `shortbreadctl`): `shortbread`.

## Anti-goals and Bad Versions

What would make this ceremonial, creepy, unsafe, or just another CMS?

- It grows a web UI for editing content — becomes a CMS instead of a host for already-built bundles.
- The thread grows states — anything you can "resolve," "approve," or be assigned.
- It gets creepy — per-person view tracking surfaced to the group, or analytics beyond "who saw which release."
- Viewers face ceremony — anyone ever needs a password, an account, or an app-store install to open a link.
- Publishing needs babysitting — if `shortbread publish ./dist` isn't fire-and-forget for an agent, the producer-agnostic promise is dead.

## Evidence of Success

What observable outcome would prove this is genuinely better than claude.ai artifacts + texted screenshots?

- The Italy roster opens the site in a dead zone, offline, without asking me how.
- Nobody on the roster ever asks "how do I open this" — the link just works on every phone.
- I push 10+ releases of something and revise from `shortbread feedback` output rather than screenshots of texts.
- A share containing real names/booking numbers happens and I never once worry about it being public.

## Anything the Prompts Missed

- Sharing and getting feedback on prototypes is a first-class use, not an afterthought. It fits inside the existing prototype-review journey and the release-feedback outcome — no separate machinery needed.
