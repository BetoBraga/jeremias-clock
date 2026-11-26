# Confirmed calendar moves: offline reference only

The read-only pilot in #8 must pass first. This module does not connect, request a scope, render an approval UI, manage calendar credentials, or send mutations. It is safe to execute its fixture test without an account. Do not expose this policy as a live feature.

## User and adapter contract

- Start with one timed event, one account and one calendar. The proposed UI must show the target account/calendar, event, old and new interval, time zones and explicit approve/decline controls. Bind an approval to the exact proposal digest, account and UTC decision time; the approval is valid for ten minutes. A digest detects changing fields between screens; it is not authentication or a substitute for trusted local storage.
- Immediately before a first submit, verify the selected account, calendar, event, write permission and source revision. The adapter must enforce permission and a conditional revision check at the provider at mutation time, not infer success from the local probe. Reject providers that cannot guarantee the conditional mutation. A secondary confirmation is required for a new proposal; no fallback account.
- Before a first dispatch, persist a Pending journal keyed to the exact proposal. The adapter receives the same idempotency key and must return a matching terminal receipt. A concurrent caller cannot enter while the lock is held. If a result is lost, restart reconciles the Pending record by a read-only lookup; it never sends that mutation again automatically. A missing or inconclusive receipt is Uncertain, not error-free completion. A local file is not a cross-host lock; do not share an approval or journal between independently scheduled hosts.
- The reference journal contains the digest/state only. The UI still needs an approval record and a distinct Activity outcome. Do not copy calendar contents, account identifiers or token material to the repository. Treat corruption as a blocker, not a reason to resend.

## How to validate

`powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Validate-CalendarWritePolicy.ps1`

Tests use injected callbacks for no approval, changed proposal/account, revoked permission, stale revision, approval expiry, one dispatch, restart/reconcile, unexpected receipt and broken journal. Provider conditional-write support, exact UI review, granted scopes and live recovery have not been qualified. Those are independent acceptance requirements for #10.
