# Agent instructions

These rules apply to all files in the repository and to human and AI-assisted changes.

## Start here

Read README.md, docs/ARCHITECTURE.md, docs/DESIGN.md and docs/TESTING.md before changing behavior. Inspect the actual implementation; documentation expresses intent and does not prove that a feature works. Follow CONTRIBUTING.md.

## Project invariants

- Windows PowerShell 5.1 and WPF are the supported baseline. Keep C# compatible with the compiler used by Windows PowerShell Add-Type. No mandatory downloads, elevation, telemetry or runtime services.
- Use one UTC instant for both clock faces; use TimeZoneInfo and the Windows zone IDs, never fixed offsets or handwritten DST rules. Simulate using an instant, not independently edited wall clocks. Never modify system time.
- Keep live and simulated modes explicit. Preserve 15-minute increments, ±24-hour bounds and 12-second idle reset unless an approved requirement changes them.
- Preserve the 440×322 logical canvas and proportional 60–250% scale, or document and test an intentional redesign. Position lock and topmost are independent preferences.
- Fullscreen detection must not inject into games, interfere with input, or move unrelated windows. Native pet docking is opt-in, best-effort and reversible; fail closed to the local sprite. Never inspect chat contents, credentials, memory or internal ChatGPT files.
- Keep settings backward-compatible, local, and tolerant of missing or corrupt values. Never commit a user's settings, window titles, tokens or machine-specific paths.
- English for docs, UI, comments and public issues. Preserve UTF-8 BOM for Windows PowerShell scripts containing non-ASCII text.

## Workflow

1. Identify scope, acceptance criteria, affected files and risks. Read nearby code; prefer the smallest coherent patch over a rewrite.
2. Keep side effects at system boundaries. Prefer pure clock and state logic when extracting functions. Do not add abstractions without a concrete need.
3. Add regression coverage; run Validate.ps1 on Windows in STA mode and follow relevant manual cases in docs/TESTING.md. Non-Windows static checks are not substitutes for Windows validation.
4. Update docs and CHANGELOG.md for user-visible changes. Report commands, results, untested cases and assumptions accurately. Never fabricate test results.
5. Open a focused PR using the template. Do not publish releases, alter licenses, change security policy or modify third-party application internals without explicit maintainer authorization.

## Definition of done

Acceptance criteria met; no unrelated edits; relevant tests executed or clearly marked pending; no secrets; backwards compatibility considered; docs updated; fullscreen, DPI and docking changes reviewed on Windows before claiming support.
