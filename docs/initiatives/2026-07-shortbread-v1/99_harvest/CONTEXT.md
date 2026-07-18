# Stage 99 — Factory Harvest

## Inputs

- the completed run's `RUN.md`, stage outputs, tests, harnesses, reviews, and repair history
- `/agents/README.md` and the skills actually used
- product artifacts changed during the run

## Process

Separate product knowledge from factory learning. Promote a pattern into `agents/` only when run evidence shows it is reusable across unrelated product slices or a recurring correction demonstrates a factory defect. Keep Shortbread-specific vocabulary, provider details, architecture, runbooks, and behavior in product docs, ADRs, code, or tests.

For each candidate, name the observed failure or success, the general rule, the narrow factory edit, and the validation that proves the edit. Validate changed skills and scripts. It is correct to record that no reusable learning was found.

## Outputs

- `output/<run-or-ticket>-harvest.md`
- validated edits under `/agents/` when justified

## Verify

- Every factory edit cites run evidence and removes product-specific facts.
- No transcript, credential, private fixture, viewer PII, or working exhaust is promoted.
- Changed skills remain concise, executable, and vendor-neutral.
- The source ticket or run records either the promoted learning or an explicit `No reusable harvest` result.

## Stop

Do not turn preferences observed once into doctrine. Do not block product completion merely to invent a harvest.

## Promote

Commit validated factory changes with the product work that proved them, or as a clearly linked follow-up when isolation improves review.
