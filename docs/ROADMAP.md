# Roadmap

## P0: establish a validated baseline

- Run Windows CI and interactive smoke tests; resolve failures before a stable release.
- Validate Time Travel around DST, midnight and input capture.
- Verify DPI, multi-monitor behavior and fullscreen fallback against real applications.
- Confirm source and artwork licensing with the owner.

## P1: harden the portable app

- Extract deterministic time/preview logic with regression tests and injectable clock.
- Validate settings schema and use atomic writes; improve recoverable error reporting.
- Add reduced-motion mode and accessible keyboard navigation.
- Add an opt-in shortcut creation tool and reproducible ZIP packaging.

## P2: interoperability and distribution

- Assess supported native pet interfaces; keep experimental window docking isolated until a stable integration exists.
- Add configurable city pairs and locale only after preserving the core experience.
- Consider a signed native executable or installer with a clear uninstall path.

These are proposals, not shipped features or delivery commitments.
