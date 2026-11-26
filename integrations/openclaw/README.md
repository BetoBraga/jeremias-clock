# OpenClaw Gateway qualification

**Status: offline fixture only.** Jeremias does not connect, pair, install OpenClaw, accept credentials, or send network requests. The clock, Today panel, notes and local briefs work with no Gateway. No running Gateway, signed device proof, real credentials or end-to-end version pair has been tested. Do not enable a live path based on these fixtures alone.

## Protocol basis

Reviewed 2026-11-26:

- [OpenClaw v2026.11.10](https://github.com/openclaw/openclaw/releases/tag/v2026.11.10) was the upstream latest release observed. Its [tagged wire schemas](https://github.com/openclaw/openclaw/blob/v2026.11.10/packages/gateway-protocol/src/schema/logs-chat.ts) define the chat requests used in the harness.
- The [official client guide](https://docs.openclaw.ai/gateway/clients) recommends pinning the client and protocol packages at **2026.8.1** (wire protocol **4**, Node.js >=22.19.0). These are the guide's pins, not a verified match for the Gateway release above. Verify available packages, integrity, Node runtime, advertised methods and the exact running Gateway version on the selected pilot before choosing the release pair.
- [WebSocket handshake](https://docs.openclaw.ai/gateway/protocol/handshake), [operator scopes](https://docs.openclaw.ai/gateway/operator-scopes), [session RPCs](https://docs.openclaw.ai/gateway/protocol/rpc-session-control) and [event families](https://docs.openclaw.ai/gateway/protocol/rpc-bootstrap-and-events) describe the additional gates.

Favor a separately installed, version-pinned helper using the published client SDK over implementing device-signing and socket recovery in PowerShell 5.1. Keep that helper optional and isolated from the WPF dispatcher. Never install or upgrade Gateway, Node, or packages from the clock's launcher. No implicit Gateway discovery, default credentials, protocol downgrade, shared-token fallback or global permissions.

## Authority and data boundary for a future live pilot

1. The user selects and approves an existing **dedicated test Gateway** and model provider with known retention, isolated from personal and work Gateway instances. Require standard TLS verification for remote endpoints; allow cleartext only on an explicitly approved direct loopback pilot. Do not follow redirects or fail over to a different endpoint/profile. Model-provider routing is a separate data disclosure even when the Gateway runs locally.
2. Pair outside the clock on a trusted admin surface using challenge-bound device proof. A trusted operator reviews the exact endpoint, public device fingerprint and scopes. The clock is not an approval broker and must not ask for admin/pairing/Talk, terminal, browser, approval, cron, configuration, or channel-delivery authority.
3. For this proposed **chat RPC** path, request operator role with `operator.write` only; official docs list it for `chat.send`, and it also satisfies `operator.read` for refresh. Refuse extra grants and missing scope/methods. `operator.sessions.write` is narrower but is not a substitute for this ordinary `chat.send` path unless an alternate own-session surface is separately qualified. `operator.write` alone is broad and not an isolation boundary. Dedicated Gateway and profile isolation are required regardless of token scopes.
4. Restrict to the `jeremias-calendar-pilot` agent, a fresh namespaced session per run and one reviewed brief workflow. No calendar write credentials (ideally no calendar connection), other agent access, shell, filesystem, browser, messages/channels, custom skills, subprocesses or external-tool execution. Enforce that restriction on the Gateway, not just with a prompt. Before use, inspect effective tools and verify a synthetic action request is refused with no calendar/network side effects.
5. Keep the paired device private key and reusable device token in Windows Credential Manager or encrypted with Windows DPAPI CurrentUser under a restricted per-user Windows directory, bound to the approved Gateway and device. Memory-only administrator bootstrap, if needed, stays outside the clock. Never store secrets in repo configs, app settings, command arguments, ordinary log files, stdout, screenshots or crash reports. Explicit disable/unpair must stop new requests, close the transport, revoke the approved device and remove the local secret.
6. Preview the exact fields and wait for explicit approval before sharing: selected title (120 characters), UTC start/end and up to four selected/redacted excerpts (280 characters each) with opaque source IDs. Never include attendees, addresses, joins, attachments, tokens, notes by association or adjacent calendar records. No calendar/provider credentials in the integration. Treat selected strings and returned content as untrusted text; neither becomes commands or tools. A completed response is a draft only and must pass the meeting brief's source validation before use. Keep titles, source content and response out of logs; use opaque run/session IDs and coarse status only.

## Offline harness

`OpenClawPilot.psm1` is a development harness. PowerShell functions accept a fixture script block explicitly to stand in for transport. `fixture.connect` is **local to the harness**, not a Gateway RPC. The fixture returns a normalized hello/RPC payload and coarse errors; no network implementation is supplied. The model is sequential, not a recommendation to block the WPF dispatcher.

- New user-confirmed runs use one unique session/idempotency key and `chat.send` with delivery disabled and no more than 60 seconds of server runtime. The harness clears selected content from the run record after the attempt. A started/accepted reply is not a final result.
- A matching complete `chat` event produces a review-only draft, capped at 4 KiB, or a coarse outcome. Ignore unrelated sessions/runs, never publish a delta as a draft, and discard late completions. Apply downstream source validation before any user-visible approved brief.
- On disconnect or uncertain send, do not automatically retry, give the run a new identity or report cancellation. Reauthenticate and use bounded `chat.history` for only that session/identity. Exact active-run evidence reconciles to active; absence leaves the outcome unknown. Never infer success from history inactivity. For production, fence callbacks by live connection generation and qualify terminal recovery with verified upstream evidence before broadening this rule.
- Before aborting, refresh the precise run and require a matching physical session ID. Never issue session-wide aborts or target a successor. A matching abort reply means cancellation requested; wait for a matching abort event to report cancelled. A local timeout only limits the client's wait, not Gateway execution.

## Live qualification required before release

| Test | Required evidence |
|---|---|
| Client/Gateway versions and pairing | Record exact approved endpoint class and client, protocol and Gateway builds; accepted challenge and effective grants, no secrets. Invalid/revoked/over-scoped traffic must be denied before a run. |
| Agent policy | Only dedicated agent, explicit model/provider, verified tool deny list and no calendar write credential; synthetic attempts at writes or outbound delivery have no effects. |
| Lifecycle | One submit returns an exact run; delta, final, failure, and pre/post-deadline outcomes map correctly. Admit a draft only after source validation. |
| Disconnect and transport timeout | Drop connection before and after admission; reauthenticate, converge on exact state or keep unknown, do not replay automatically, and discard stale-generation callbacks. |
| Cancellation | Use the exact run plus physical session fence; verify another run stays untouched and request/terminal outcomes are distinct. |
| Fallback and privacy | Disabled/unavailable leaves local features usable; TLS/identity mismatch, revoked token and stale pairing fail closed. Confirm credentials never reach logs/files in plaintext and removal is clean. |

Offline fixtures are synthetic and do not satisfy the live gate. No live Gateway or calendar side effect is expected or required by the normal validation suite.
