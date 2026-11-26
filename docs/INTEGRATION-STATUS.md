# Integration evidence map

This is a review record, not a support declaration. The Windows clock does not require network, accounts, model runtimes, administrative access or telemetry. The qualification experiments must not switch the desktop out of offline mode.

| Issue | Evidence in this stack | Still needed before closing |
|---|---|---|
| [#3](https://github.com/BetoBraga/jeremias-clock/issues/3) Today | Base [PR #12](https://github.com/BetoBraga/jeremias-clock/pull/12); local notes/focus store and WPF validation. | Review and merge base; human layout and interaction review. |
| [#4](https://github.com/BetoBraga/jeremias-clock/issues/4) Read-only calendar | Explicit GET for one selected calendar, snapshot cache, status/age; synthetic recurrence, DST, wrong scope, revocation. | One live change using a dedicated test calendar and read-only access. |
| [#5](https://github.com/BetoBraga/jeremias-clock/issues/5) Responsibilities | WPF Activity, persistent run IDs, exact source, half-open UTC, restart dedupe and pause/cancel distinction. Local watches are available offline. Calendar watches only use fresh cached snapshots. | Human interaction review. Provider cancellation must be tested on a live, isolated gateway before claiming it is supported. |
| [#6](https://github.com/BetoBraga/jeremias-clock/issues/6) OpenClaw | Bounded synthetic qualification harness, pinned candidates and live acceptance matrix. | Actual authorized pair, minimum Windows credential storage/scopes and transport evidence; no live gateway adapter enabled. |
| [#7](https://github.com/BetoBraga/jeremias-clock/issues/7) Brief | Scope and provider preview fixture, response schema, citation/revision/budget checks and idempotent Activity persistence. | Live transport enforcing budgets and a human review of UI. |
| [#8](https://github.com/BetoBraga/jeremias-clock/issues/8) Calendar pilot | Windows synthetic move plus one conflict alert, one instant for both cities, replay, stale data and brief evidence. | Run the [dedicated live pilot](validation/calendar-pilot.md); publish only redacted outcomes. |
| [#9](https://github.com/BetoBraga/jeremias-clock/issues/9) OpenBot | Separate candidate and licensing scope, fixture oracle for A2A/polling and safe boundaries. | Qualify exact version pair and licensing with an isolated OpenBot deployment; never include it in the clock installer by default. |
| [#10](https://github.com/BetoBraga/jeremias-clock/issues/10) Confirmed calendar writes | [Offline write policy](CALENDAR-WRITE-POLICY.md) and fake transport recovery. | Only after #8, qualify exact UI approval, conditional provider writes and live recovery. No mutation transport is present. |
| [#11](https://github.com/BetoBraga/jeremias-clock/issues/11) Roadmap | This map, [architecture](ARCHITECTURE.md) and [validation](TESTING.md) link proof to each boundary. | Track the live gates above rather than closing the roadmap based on synthetic tests. |

The Windows operator owns the selected calendar, profile and local schedules. The optional test-gateway operator owns executable agent policy and rechecks its credentials. The optional OpenBot operator owns separate deployment and lifecycle. The Windows app never infers permission from a model response, nor starts a second scheduler on another host.
