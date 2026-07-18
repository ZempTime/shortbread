# Stable Site origins serve immutable Releases

Each Site lives at `<slug>.sites.<apex>` while the control plane and Shelf live at the apex; a Site's current pointer selects one immutable, content-addressed Release stored in private object storage. Stable isolated origins let arbitrary Bundle HTML, CSS, and JavaScript use normal root-relative paths and offline caches without exposing apex credentials, while immutable Releases make publishing, rollback, deduplication, feedback anchors, and View Receipts deterministic; Shortbread never builds or rewrites a Bundle.
