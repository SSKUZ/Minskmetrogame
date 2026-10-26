# Development branches and release process

- `main`: production. Never commit experiments or preview code here.
- `develop`: integration branch for new work and refactoring.
- `testing`: candidate build for phone testing. Update only after syntax checks.
- `refactor/modular-foundation-20261025`: historical refactor branch, retained as backup.

## Procedure
1. Make changes in `develop`, keeping the currently accepted carriage camera.
2. Run `node --check` on all JavaScript files (GitHub Actions validates pushes).
3. Merge or copy an approved build to `testing` and validate on devices.
4. Promote a tested version to `main` only with explicit approval.

## Deployment note
GitHub Pages currently serves the repository's existing `main` publication. The old `/test/` URL is a directory **inside main**, not a separately deployed branch. Branch separation alone does not make `testing` available at `/test/`. A separate preview deployment (e.g. independent Pages site or workflow publishing combined artifacts) must be configured before using a branch-specific preview URL. Do not mirror development changes into `main/test` in the meantime.

## Current checkpoint
The passenger-car camera placement and rotation from version 35 are retained. The carriage geometry and materials remain unfinished.
