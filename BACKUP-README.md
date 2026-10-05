# Clipbar — Mac source backup

Snapshot prepared October 5, 2026 from the associated local Codex project.

This branch saves current source, build configuration, tests and included assets. It is a recovery snapshot, not a release or deployment approval. Existing production branches remain separate.

Excluded: installed dependencies, generated build output and caches, runtime databases, environment credentials, signing keys, device provisioning profiles, Graphify indexes and temporary QA/build artifacts. Restore credentials separately and reinstall dependencies before building. No live credentials are intentionally included.

The backup preserves source-relative paths. Unstickies includes the active StickyTasks Mac source, the release-preparation source, current Companion mobile source under paperclip-ticky-sticky/mobile-v1-2026-09-26/mobile-parity-v1/source, and the public marketing checkout. Mercer source is under website/; Bad Employee source is under storefront/. Other projects retain their root layout.

This snapshot is not an automatic future backup. Commit and push later changes to keep GitHub current.
