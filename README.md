# Jeremias Desktop Pet

A lightweight Windows desktop companion with three heads, selectable personalities and local notes. The clock is optional: leave it off, or pick up to four time zones.

<p align="center"><img src="assets/jeremias-readme.png" width="240" alt="Jeremias, a smiling black dragon with three heads and bright green eyes"></p>

**Status:** preview. This is a source distribution, not a signed installer. Automated Windows validation covers the local pet and legacy clock. Manual UI review and live integration qualification are separate.

## Try the pet

On Windows 10 or 11, run [Start.cmd](Start.cmd). No account, service, installer or model is required. Say hello, change the pet's personality, and choose zero to four Windows time zones. Add a note to keep it for the session; explicitly enable **Save notes to this device** before leaving if you want it to survive a restart.

The pet does not inspect other files, execute notes, connect to a calendar, or run actions when closed. See [the pet contract](docs/PET-FOUNDATION.md) for the permissions boundary and next steps.

## Original world clock

Use [Start-Clock.cmd](Start-Clock.cmd) for the original Sao Paulo / Dublin widget with Time Travel and Today. The preserved baseline is available in the [remote-worker clock branch](https://github.com/BetoBraga/jeremias-clock/tree/legacy/remote-worker-clock).

### Legacy clock features

- Side-by-side 24-hour clocks with seconds, local dates, UTC offsets and the current difference.
- Automatic daylight-saving transitions using Windows time-zone data. Dublin is normally three hours ahead of São Paulo in Irish winter and four in Irish summer.
- Time Travel: preview up to 24 hours in either direction in 15-minute increments, with automatic return to live time after 12 seconds of inactivity.
- Proportional resizing (60–250%), movable widget, position lock, optional always-on-top and startup shortcut.
- Best-effort fullscreen avoidance on the widget's monitor.
- Local blink animation; optional experimental docking of the native ChatGPT desktop pet, with a local fallback.
- Local settings; no network requests, accounts, telemetry or external runtime dependencies.
- An offline Today panel for meeting entries, focus blocks and searchable notes.

## Pick a review path

| Goal | Entry point | What it does |
|---|---|---|
| Use the clock | [Start-Clock.cmd](Start-Clock.cmd) | Starts the normal widget. The startup shortcut and native pet link are opt-in. |
| Try the widget without touching everyday settings | [Review.cmd](Review.cmd) | Opens a separate review instance with its own settings; startup and native pet linking are unavailable. |
| Validate without showing the widget | [Validate.ps1](Validate.ps1) | Checks PowerShell parsing, C# helper compilation, WPF markup, and time-zone and Time Travel behavior. |

## Quick start

1. Download or clone the repository and extract it to a permanent folder.
2. On Windows 10 or 11, run `Start-Clock.cmd` (Windows PowerShell 5.1, WPF; no administrator privileges required).
3. Drag the body to move, the bottom-right grip to resize, or right-click for additional settings.

The launcher applies `ExecutionPolicy Bypass` to its own process only, not the system policy. Review source before running. To use your own applicable execution policy, open Windows PowerShell and run `powershell.exe -NoProfile -STA -File .\WorldClock.ps1`.

## Controls

| Control | Action |
|---|---|
| Slider | Preview another instant; range ±24 hours |
| Scroll over time or slider | Move 15 minutes |
| −1h / +1h | Move one hour |
| Now | Return to live time immediately |
| Diamond | Toggle always-on-top |
| Lock | Toggle movement lock |
| Bottom-right grip | Resize proportionally |
| Right-click → Today | Open the local agenda and notes |
| Right-click | Presets, reset position, startup, fullscreen and pet settings |

The simulated instant is frozen; it never changes the system clock. Dates and offsets are computed for that instant, including midnight and DST boundaries.

## ChatGPT pet (experimental)

Enable your native desktop pet, then choose **Link ChatGPT pet (point in 5s)** from the context menu and hover over the pet. If a qualifying window can be identified and moved, the widget docks it above the clock and hides the local sprite. Otherwise the local animation remains. Use **Unlink pet / local animation** to stop docking.

This is not an official ChatGPT integration. It uses limited Win32 window metadata and geometry, not chat data or internal application files. It may require relinking after updates or restarts. Fullscreen avoidance applies to the clock only, not the separate native pet. See [architecture](docs/ARCHITECTURE.md) and [security](SECURITY.md).

## Development

Run `Measure-Clock.ps1` in Windows PowerShell to measure startup and idle resource use. It opens and closes isolated measurement windows and prints JSON. See the [measurement procedure](docs/TESTING.md#measuring-the-windows-baseline).

For interactive review, open `Review.cmd` from a PR checkout. It launches a separate instance that saves preferences in `%LOCALAPPDATA%\JeremiasWorldClock.Review`. Startup and external pet linking are disabled in this mode. Right-click and choose **Greet Jeremias** to try the local mascot animation. Follow the manual steps in [Testing](docs/TESTING.md).

Run `Validate.cmd` or `powershell.exe -NoProfile -STA -File .\Validate.ps1` on Windows. This checks parsing, Win32 helper compilation, WPF markup and DST examples without opening the widget. Windows CI loads the pet and legacy WPF controls and checks the new pet flows without showing its window. Live providers and manual UI checks are separate.

See [contributing](CONTRIBUTING.md), [agent instructions](AGENTS.md), [design standards](docs/DESIGN.md), [test plan](docs/TESTING.md) and [roadmap](docs/ROADMAP.md).

Settings are stored under `%LOCALAPPDATA%\JeremiasWorldClock\settings.json`. To uninstall, disable **Start with Windows**, close the widget, and remove the project folder. Optionally remove the local settings folder. If the widget was deleted first, remove its shortcut from `shell:startup`.

Today data is stored in `productivity.json` beside the settings, with its last valid backup in `productivity.json.bak`. `Review.cmd` uses its own copy under `JeremiasWorldClock.Review`.

## Icon

Use `assets/JeremiasClock.ico` for Windows shortcuts. A `.cmd` or `.bat` file cannot have a per-file custom icon; create a shortcut and select the ICO in its properties. The startup shortcut uses the icon automatically when enabled.

## Licensing

Public visibility is not a license. A distribution license for the source and artwork has not yet been selected by the owner. See [NOTICE.md](NOTICE.md). No affiliation with or endorsement by OpenAI or Microsoft is implied.
