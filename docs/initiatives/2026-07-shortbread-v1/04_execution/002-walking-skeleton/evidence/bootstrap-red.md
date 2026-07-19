# Bootstrap red checkpoint

The governed public seam is `mise run bootstrap-check`. Before scaffolding, it must fail because the Rails application does not exist yet; this distinguishes the eventual green result from a test written after implementation.

Observed from the clean pinned baseline:

```text
$ MISE_HTTP_TIMEOUT=1 mise run bootstrap-check
[bootstrap-check] $ bin/verify-bootstrap
bin/verify-bootstrap: line 4: bin/rails: No such file or directory
[bootstrap-check] ERROR task failed
exit 127
```

The failure is at the public Rails boot boundary, before browser or Go checks can run. No implementation exists at this checkpoint.
