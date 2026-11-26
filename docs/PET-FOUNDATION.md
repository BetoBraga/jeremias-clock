# Jeremias desktop pet: a narrow contract

The new default is a Windows desktop companion, not a general-purpose agent. The separate clock launcher retains the original Time Travel, Today, Activity, and opt-in pilot surfaces. The preserved legacy/remote-worker-clock branch carries the last pre-pivot snapshot.

| Surface | Available now | Not enabled |
|---|---|---|
| Personality | One of three local voices, manual greeting and an in-window idle cue | Remote model calls or prompt execution |
| Knowledge | Installed Windows time-zone definitions and a fixed local permissions panel | External sources, browsing, file or chat discovery |
| Memory | Up to 20 explicitly entered single-line notes, held for the session unless saved to this device | Background collection, sync, ingestion or automatic interpretation |
| Clock | Off initially; choose one to four distinct Windows zones from the same instant | Changes to the system clock or activity recording |
| Runtime | Local WPF, no third-party package installation, no model or service required | Shell delegation, calendar writes, remote access, or third-party account permissions |

Personality and zone choices are saved when the visitor changes them. Notes are plain text in the app-owned local profile only after explicit opt-in. Turning persistence off replaces that profile without its notes; it does not clear the current session, secure-erase the disk, or affect Windows and external backups. No activity runs while the app is closed. Clock refresh stops when the clock is off or the window is minimized.

## Next slice: handoff, not another chat shell

Experiment with a local-only handoff preview for remote workers: select notes and explicitly selected clock zones, show a dated handoff preview, then let the operator copy it. Time conversions should handle DST and midnight. Do not auto-send it, search local files, or infer recipients. A follow-on skill can accept typed input and return a structured proposal; only separately approved capabilities may act. Record permission, data boundary, timeout, and visible evidence for each capability. Keep the preview useful without any model.

[Capri Desktop](https://github.com/lachydotmcg/capri-desktop) is useful as a comparison point for desktop companions; offline/sign-in-free interactions or approvals should not be presented as category exclusives. Jeremias is currently narrower: an optional zone display, manual local memory, and a possible remote-work handoff. There is no measured performance comparison.

## Validate before broadening

- Proposed acceptance budgets, not measured promises: median first visible frame below 2 seconds, idle working set below 120 MiB, average idle CPU below 1% of one core over 60 seconds on an identified Windows machine, and zero outbound connections in the default pet scenario.
- Report cold/warm starts separately with at least five runs each, hardware and Windows versions, sample procedure, tails, and session state. Measure the new pet rather than extrapolating legacy clock results.
- Add a reviewer-run walkthrough for keyboard use, 100/150/200% DPI, time-zone selection, note opt-out and corrupted-profile recovery before describing the UI as production-ready.
- Default capabilities must remain closed when an adapter or consent is missing. Integration fixtures and local tests are not proof of live transport support.
