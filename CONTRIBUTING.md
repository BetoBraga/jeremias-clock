# Contributing

Please start with an issue for substantial changes. For small bug fixes, submit a focused pull request. Before submitting code or artwork, confirm contribution and licensing terms with the maintainer (see NOTICE.md).

## Setup

Use Windows 10/11 and Windows PowerShell 5.1. Clone the repo, run `Start.cmd`, and run `Validate.cmd` before making changes. Git is required for development; no package installation is required for the app.

## Changes

- Create a branch from the default branch, e.g. `fix/fullscreen-detection`.
- Use English and clear conventional commit subjects, e.g. `fix: restore clock after fullscreen`.
- Avoid unrelated refactors, machine-specific settings and dependencies. Follow AGENTS.md and the architecture and design documents.
- Add tests for logic changes and record manual Windows tests for UI/Win32 changes. Screenshots are useful for visual changes; remove private desktop content.
- Submit a PR with motivation, implementation notes, validation evidence, known limitations and any AI assistance relevant to review. Contributors remain responsible for all submitted changes.

Do not merge changes that require unresolved licensing permission or bypass the documented security boundaries. Maintain respectful, constructive discussion and report vulnerabilities privately using SECURITY.md.
