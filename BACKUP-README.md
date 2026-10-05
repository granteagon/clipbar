# Clipbar — Mac source backup

Snapshot prepared October 5, 2026 from the associated local Codex project.

This branch saves current source, build configuration, tests and included assets. It is a recovery snapshot, not a release or deployment approval. Existing production branches remain separate.

Excluded: installed dependencies, generated build output and caches, runtime databases, environment credentials, signing keys, device provisioning profiles, Graphify indexes and temporary QA/build artifacts. Restore credentials separately and reinstall dependencies before building. No live credentials are intentionally included.

The backup preserves Clipbar’s source-relative paths, including Sources/, Tests/, Resources/, scripts/, and package/build configuration.

This snapshot is not an automatic future backup. Commit and push later changes to keep GitHub current.
