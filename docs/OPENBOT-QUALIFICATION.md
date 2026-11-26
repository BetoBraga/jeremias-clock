# Optional OpenBot bridge qualification (#9)

**Decision: NO-GO for enabling, distributing, or advertising a live bridge.** This is a documentation and offline policy-fixture handoff. No authorized deployment, credentials, or matched version pair was supplied or exercised. There is no adapter, runtime dependency, background job, network connection, packaging change, or default behavior change.

## Identity, version candidates, and rights

Checked 2026-11-26:

| Layer | Evidence | Candidate, not a compatibility claim |
| --- | --- | --- |
| Workspace | [CopilotKit/OpenBot](https://github.com/CopilotKit/OpenBot), not a similarly named project. [OpenDots](https://github.com/CopilotKit/OpenDots) directs users to the OpenDots skin in OpenBot. | [OpenBot v1.2.0](https://github.com/CopilotKit/OpenBot/releases/tag/v1.2.0), release commit prefix 1ad2bf3. Record exact image digests and active Intelligence build in a real run. |
| Workspace-to-adapter | [OpenBot README](https://github.com/CopilotKit/OpenBot#your-workspace-your-stack) documents connecting external agents through AG-UI. [AG-UI event docs](https://docs.ag-ui.com/concepts/events) describe lifecycle and streaming event types. | AG-UI 1.0 as a protocol candidate; record the actual SDK versions and event schema from the selected release, then test the selected deployment's agent registration, auth and framing. Generic event docs alone are not a working OpenBot contract. |
| Adapter-to-engine, polling | [OpenClaw A2A channel](https://docs.openclaw.ai/channels/a2a), separate from AG-UI; [v2026.8.1 introduced A2A 1.0](https://docs.openclaw.ai/releases/2026.8.1/messaging). | [OpenClaw v2026.11.10](https://github.com/openclaw/openclaw/releases/tag/v2026.11.10) for investigation, not assumed to match every current docs detail. Select precisely one audited build/plugin and record discovery and RPC behavior. |
| Alternative live path | [OpenClaw Gateway integrations](https://docs.openclaw.ai/gateway/external-apps) and [Gateway clients](https://docs.openclaw.ai/gateway/clients). | Requires its own qualified pair and authorization controls. Issue #6's offline fixture does not qualify this path or the OpenBot side. |

[OpenBot licensing](https://github.com/CopilotKit/OpenBot#open-source-local-operation-and-licensing) calls the application template MIT, but CopilotKit Intelligence separately licensed: personal local license, Kubernetes trial, or production license as applicable. Local operation does not imply permanently disconnected setup or that a connected cloud model or app keeps data local. The [AG-UI repository](https://github.com/ag-ui-protocol/ag-ui/blob/main/LICENSE) and [OpenClaw repository](https://github.com/openclaw/openclaw) are MIT; this does not grant rights to Intelligence, other dependencies, or Jeremias artwork. Review pinned notices, binary/image and deployment terms before any reuse or distribution. No upstream code is copied here.

## Candidate protocol boundary

Do not map OpenBot directly to OpenClaw by name alone: external AG-UI runs are one interface, OpenClaw A2A JSON-RPC tasks another. A future adapter may initiate one bounded, synthetic read-only task and poll its result. No streaming progress, push notification, remote cancellation or multi-tenant routing is assumed from A2A. Current A2A docs describe retained terminal tasks and same-peer message deduplication within retention; launch notes described an in-memory first version. Neither proves behavior of a selected binary. Plan for missing evidence after restart or retention expiry: show outcome unknown, don't replay automatically. Queueing is not success; completion of a remote task is not success unless the expected read-only result validates. Keep operator approvals on the authorized operator surface; this bridge must neither grant approval nor retry denied actions. If live controls are necessary, evaluate the Gateway route separately rather than projecting AG-UI events into unsupported authority.

## Offline contract

Run from this checkout on Windows:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Validate-OpenBotFixture.ps1
```

The JSON fixtures are local policy examples, not captured upstream packets. The PowerShell oracle exercises disabled default, peer-scoped retries/conflicts, same response for wrong peer and absent record, unknown after timeout/reopen, approval isolation, stale result rejection and terminal replay handling. Its restart serializes fixture state in memory; it does not verify actual disk persistence, crash recovery, authentication, AG-UI serialization, or engine calls. The submission count is simulated. Future integration tests should drive these scenarios through the actual entry point, with captured redacted request/run evidence and negative controls.

For the real mapping, key idempotency by authenticated peer and unique request ID; bind a normalized hash of the complete approved payload and source revision, not revision alone. A retry that changes intent is a conflict. A retry with uncertain send outcome must reconcile before any further dispatch. Persist linkage and last verified state independently of the upstream retention window. Do not pass raw provider payloads, prompts, IDs from other peers, or any credential to a viewer. The result remains untrusted display data, not an instruction or an approval.

## Live go/no-go checklist

- [ ] Owner authorizes the exact endpoint and test workspace; use a separate disposable deployment and dedicated read-only agent with only an approved synthetic fixture. No desktop bundling or shared credentials. Record tool/egress/storage policy and show service disables or blocks connected writes. Keep exactly one scheduler owner; this pilot adds none.
- [ ] Pin OpenBot, Intelligence, AG-UI SDK, adapter, OpenClaw, plugin and protocol/auth configuration; record immutable digests or revisions. Review deployment license, analytics/egress and retention. Store secrets in approved storage, not the repo or logs.
- [ ] Confirm external-agent registration/routing and pin actual advertised schema and transport through an authorized environment. Verify one end-to-end approved text/structured result and compare with direct fixture ground truth. Record redacted events and timestamps.
- [ ] Demonstrate absent/invalid peer auth and wrong-peer task lookup cannot access the task or learn it exists. Confirm packet/UI output contains only authorized fields. Delimit provider payloads and do not synthesize unsupported actions or lifecycle events.
- [ ] Exercise duplicate submission, changed-payload conflict, lost response and timeouts, adapter/Gateway restart both during and after a run, retention expiry and reordering. Observe upstream run counts; one logical request must not silently run twice.
- [ ] Verify the operator decision route and that unsupported actions do not masquerade as success; prove revocation/disable returns to the offline experience and record rollback. Only publish verified capability labels for the exact tested pair.

Record a dated pass/fail per row and attach redacted evidence. Any missing authorization, incompatible protocol, unresolved license, ambiguous execution outcome, or failure of access isolation keeps this optional surface disabled.
