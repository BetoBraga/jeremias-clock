# Sao Paulo / Dublin calendar pilot

**Live gate: not run.** A fixture, a local Windows test, or an HTTP mock cannot establish permission, provider freshness or what happened on a real calendar. Nothing in this plan grants live access. Do not enable calendar writes, install OpenBot or pair a real Gateway as part of this record.

## Operator setup and rollback

1. Use a dedicated test account and calendar containing only fictional events. The operator verifies the exact account and calendar and grants read-only event scope to a short-lived test session. Do not copy tokens to logs, docs or PRs. Record provider, app commit, Windows/PowerShell versions and the operator's acknowledgement.
2. Use the isolated review profile and separate cache/activity directories. Create the focus block locally. If using optional AI, pair only an isolated test agent with calendar credentials absent, scoped inputs and a documented protocol/version pair. Run once without a gateway first.
3. The operator changes the fixture event directly in the provider, not through Jeremias. Capture redacted revisions, alert count and displayed times. Confirm the app made no mutation and no unrelated calendar was accessed.
4. Revoke the grant, disconnect the test gateway and remove the test-only profile/cache through normal controls. Verify the offline clock and Today still work. Do not use private screenshots or publish event details.

## Evidence to record

| Case | Expected | Live status |
|---|---|---|
| Read-only scope | One selected calendar; no mutation; outside target never imported | Not run |
| Move an event into a focus block | One new alert for that revision; UTC interval and both local times agree | Not run |
| Retry and restart | Same revision produces zero new alerts; local run stays inspectable | Not run |
| Gateway unavailable | Conflict check still works; AI does not dispatch | Not run |
| Dublin daylight-saving edge | Offsets are resolved by Windows rules; ambiguous local times have explicit offset | Not run |
| Older revision / stale brief | Old revision does not create a second alert or become actionable | Not run |
| Reject a proposed decision | No mutation; cancelled/requested stop distinguished | Not run |
| Permission revoked | State is labelled and account cannot send or access new entries | Not run |

Record each row with timestamp, platform version, source revision (redacted), expected versus actual result and evidence link. Passing these rows is required before closing #8. A possible meeting brief is optional and does not block basic offline conflict detection.
