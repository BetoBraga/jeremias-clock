# Validation and test plan

## Automated baseline

On Windows, run `Validate.cmd` or `powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Validate.ps1`. The script checks parsing, Win32 helper compilation, WPF markup, DST, midnight and preview calculations. The CI workflow runs the same script. Interactive behavior is covered separately below.

## Reviewing locally

1. Check out the PR on Windows and double-click `Review.cmd`. The review window can run alongside the regular widget. It has a separate mutex and review settings folder. Startup shortcut changes and external pet linking are disabled.
2. Verify the live clocks. Drag or scroll the timeline, observe the preview freeze, wait 12 seconds after releasing it, then test **Now**.
3. Right-click and choose **Greet Jeremias**. Expect a short movement and a text greeting. Repeat with Windows animation effects disabled. Expect the text greeting and a still mascot.
4. Resize, lock, pin, close and reopen the review instance. Confirm the review preferences persist. Use the remaining matrix for fullscreen and monitor coverage.
5. Close the review window and record the Windows build, display setup and observed results in the PR.

## Review Today offline

1. Open `Review.cmd`, then right-click the clock and choose **Today**.
2. Add a note with a title and body. Search for a word from the body, reopen the result and edit it.
3. Add a Meeting and a Focus block using local dates and times. Reopen one and change its time. Try an end time before the start and verify that the previous saved entry stays intact.
4. Close and reopen the review app. Check that the entries and note changes are present. Switch the clock to Time Travel and open Today again. The panel should still use the actual local date.
5. Repeat with the network disconnected. All these operations should work. Review data stays in `%LOCALAPPDATA%\JeremiasWorldClock.Review`.

The automated productivity checks use a temporary store to exercise the data layer. The steps above cover interaction and layout.

On an interactive desktop, close any open review instance and run the entry-point regression separately:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Validate-TodayEntry.ps1
```

It launches the review widget, opens Today through the actual menu, and saves a focus block and a note to a temporary store.

## Measuring the Windows baseline

Run on an interactive Windows desktop with the widget closed and no fullscreen app. Keep the display arrangement, power mode and background load the same when comparing builds. Leave the window untouched while it samples.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Measure-Clock.ps1 -Launches 20 -IdleSeconds 15 -WarmupSeconds 5
```

Each launch opens the actual WPF clock in a fresh Windows PowerShell process. It uses default preferences and leaves the regular and review settings untouched. Startup spans process creation through WPF's first `ContentRendered` event. The report includes nearest-rank p95, CPU averaged over idle sample time and normalized to total logical CPU capacity, plus per-launch private memory, working set and DPI. This procedure collects about five minutes of idle across 20 processes with normal OS caching. Record monitor layout and power mode separately.

A three-launch smoke run on Windows build `26300.9974` used 1 second of warm-up and 2 seconds of idle per window. First render was 856–934 ms, mean normalized idle CPU was 0.082%, and private memory was 141–142 MiB. Use the longer procedure and the manual matrix for stack and release decisions.

## Manual acceptance matrix

| Scenario | Expected |
|---|---|
| Live clock | Both faces reflect the same UTC instant, seconds update, independent dates |
| 13:00 São Paulo in July / November 2026 | Dublin 17:00 / 16:00 respectively |
| Irish DST transition | Offset and local time change consistently at UTC boundary |
| Midnight | Date differs when only one location crosses midnight |
| Drag / wheel / hour buttons | Frozen preview, correct increments and bounds |
| Wait 12 seconds / Now | Return to live time; no system clock changes |
| Resize at 60/100/250% | Proportional canvas, legible text, no clipping |
| DPI and multi-monitor | Resize and move across screens; reset position recovers widget |
| Lock, pin, close and reopen | Preferences persist; lock does not disable resizing |
| Maximized app | Clock remains visible if pinned |
| Fullscreen browser video and borderless/exclusive game | Clock yields on its monitor and restores afterward; record exceptions |
| Native pet linked, hidden, restarted, unlinked | Correct local fallback and no unrelated window movement |
| Bridge compilation failure | Clock and local sprite work; bridge-dependent controls disabled |
| Startup opt-in / opt-out | Shortcut created/removed only when requested; icon works |
| Corrupt or missing settings | Usable defaults, no crash |

Record OS/build, PowerShell version, DPI, monitor count, test steps, actual outcomes and known limitations. Never claim a manual test passed without executing it. Keep private desktop content out of screenshots.


## Optional Google Calendar test

The automated calendar test runs as part of `Validate.cmd` and uses fictional responses. It covers a moved recurring instance, the repeated Dublin hour with distinct offsets, ambiguity without an offset, revision replay/restart, stale age, offline fallback, revocation and calendar switching. It does not contact Google.

Manual validation is pending. Use one dedicated Google test calendar with fictional events. In its Google Calendar settings, copy the exact calendar ID (not `primary`). Enable the Google Calendar API in your test OAuth project and obtain a short-lived token with only `https://www.googleapis.com/auth/calendar.events.readonly` in your own authorization flow. In a local Windows PowerShell terminal, read the token without echo or command history and clear it after use:

```powershell
$secret = Read-Host 'Test calendar access token' -AsSecureString
$env:JEREMIAS_CALENDAR_ACCESS_TOKEN = [Net.NetworkCredential]::new('', $secret).Password
try { powershell.exe -NoProfile -File .\Sync-Calendar.ps1 -CalendarId '<exact-test-calendar-id>' }
finally { Remove-Item Env:JEREMIAS_CALENDAR_ACCESS_TOKEN; $secret.Dispose() }
```

Reopen the Today panel of `Review.cmd`: the imported timed events should be read-only. Change one event on Google, refresh from the terminal, and reopen: verify the same occurrence reflects the change with no duplicates. Disconnect the network and refresh: the same calendar's cache should remain. Revoke access at Google and try the refresh: access denied/unavailable clears the snapshot. For a local-only disconnect, run `Sync-Calendar.ps1 -Disconnect`; this deletes the review cache, not the provider grant. Close and reopen Today after changing the cache. The default import path is for the review instance.
## Activity and recurring meeting checks

Open the clock menu and choose **Activity**. Use **Watch meeting** to assign
a conflict check to an upcoming local meeting already entered in Today.
The clock checks on startup, every minute while open, and on **Check now**.
It writes a single conflict row per watched meeting revision, not an external
notification. The local store also retains the last checked UTC time and
revision. No checks run while the app is closed.

| Activity test | Expected |
| --- | --- |
| Watch a future local meeting that overlaps a focus block | One Conflict row appears for the watched meeting |
| Put the focus block exactly at the meeting end | No conflict from that block; UTC intervals are half-open |
| Check now twice, then exit and relaunch | The same revision still has exactly one Conflict row |
| Pause a watch and edit its meeting to a new overlapping time | New alerts wait until resumed and checked |
| Select a running fixture row and request cancellation | Request is displayed without claiming to have stopped |
| Deliver a stop acknowledgement for that run | The run now reads Stopped; no effect on future checks |

Windows PowerShell validation creates temporary Activity data, tests UTC
normalization, source isolation, checkpoint persistence and restart replay,
and parses the Activity XAML. The WPF interactions above are a separate
manual check. The offline agenda is connected by default. A separately refreshed fresh, selected calendar snapshot can also be watched for overlaps with local focus blocks; stale and revoked snapshots do not create alerts. The
normalized check entry point also accepts a selected source ID and scope
with provider event ID, occurrence ID, revision, kind, and explicit UTC or
offset times. Unsupported data (e.g. unresolved all-day dates) must not be
fed to that entry point as timed events. Provider cancellation must confirm
the stop through the acknowledgement API; pressing the button only records
the request.

## Optional OpenClaw qualification

Run `powershell.exe -NoProfile -STA -File .\tests\Validate-OpenClawPilot.ps1` for synthetic scope checks, minimization, bounded send, event filtering, ambiguous delivery, reconnect, exact cancellation and timeouts. It never opens a socket, calls a model, or reads credentials. No Gateway/client pair is qualified until the separate [live acceptance matrix](../integrations/openclaw/README.md#live-qualification-required-before-release) runs against a user-authorized isolated pilot.

## Integration test summary

The Windows validation command also runs the end-to-end synthetic calendar/Activity fixture, the meeting-brief acceptance policy, optional OpenClaw and OpenBot harnesses, and the offline approved-write policy. Those tests do not contact a live service. See the [integration evidence map](INTEGRATION-STATUS.md) for per-issue scope and [the real calendar pilot](validation/calendar-pilot.md) for the test account handoff.
