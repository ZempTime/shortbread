# Input: Chris's redirect direction (2026-07-25)

Frozen historical source. Attribution: Chris Zempel, direct conversation with Claude Code.
Captured verbatim where quoted. Per the initiative input-lifecycle convention, this records the
moment it was captured and is not live product truth — the framing output controls.

## Opening context

The session began as a deployment question, not a redirect:

> "Please review where is this project at? I would like to get it deployed and start using it.
> I need to send out links to folks. I'm also wondering if it might be good to have some sort of
> link tree base page, unless we already considered that as the apex page or something along
> those lines."

Answered: the apex 404s by design; a public link tree would violate the invite-only /
no-anonymous-links boundary; the Viewer Shelf (U13) is the correct concept. Chris chose to defer
the Shelf and ship single-file HTML. **Both decisions were later superseded by the redirect.**

## Deployment direction

> "I don't right now have time to sit and configure creds etc. So it might actually be more
> effective to continue on feature work then come back."

> "What I'm looking For is a plug-and-play experience, similar to Brunch Club app that I
> referenced in here. This app is deploying successfully to North Blank, it has a lot of similar
> features. All I had to do to set it up was create the services, add secrets, hook up the repo.
> Done. I'm looking for a similar experience here."

Host answers given: Northflank; TLS "looking for recommendations"; DNS Netlify.

> "I will be using *.shortbread.chriszempel.com . If there's a different way to model this that
> is significantly simpler and provides the same benefits, then I'm also okay with that."

Blob storage: chose to implement the R2 port. Database: asked "how much is northflank managed
postgres".

## The redirect

> "One other potentially big change here. I recently used a project called plannotate
>
> https://github.com/backnotprop/plannotator
>
> this is amazing and exactly the kind of thing I'd like, being able to aggregate and store
> feedback for various things and iterate etc.
>
> basically plannotate but on a rails server with cli support and all the passkey link
> management etc bells and whistles."

Asked who the primary reviewer is:

> "other people me and my agents"

Asked how this relates to the accepted PRD:

> "we want this to be plannotator based. this is a major scope redirect previous approach is no
> longer relevant unless useful here."

Asked whether to rebuild or adapt plannotator:

> "would it be simpler to rebuild or just to adapt plannotator"

Then:

> "yes I want to flip this to fully support plannotator experience. lets target full infra.
> /ask-matt whats good outcome here."

(`/ask-matt` is `disable-model-invocation`; it was never run. Chris must invoke it himself.)

> "i love md to html feature of plannotator"

## Naming

> "Also, maybe we should rename this project to Tater Tots. Pour something tot based"

Clarified immediately after:

> "I meant tate based, as in annotate."

## Persistence request

> "please persist all of this down into an organized folder in docs/ as you progress and get
> reasonable outputs. this computer might get low on battery and I'd want to ensure
> resumability later."

This workspace is the response to that request.
