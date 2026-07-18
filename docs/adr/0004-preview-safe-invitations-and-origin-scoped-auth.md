# Preview-safe Invitations and origin-scoped authentication

Viewers enter through a personal, one-time Invitation on the apex: safe reads and link previews never consume it, explicit acceptance does, and the apex then issues a short-lived signed handoff that establishes a host-only Site cookie. The apex owns identity and the Shelf, an optional passkey provides re-entry, and passwords or email/SMS delivery do not exist; this balances a one-tap Viewer journey with replay resistance and keeps a hostile Bundle confined to its Site origin.
