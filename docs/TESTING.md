# Validation and test plan

## Automated baseline

On Windows, run `powershell.exe -NoProfile -STA -File .\Validate.ps1`. It checks PowerShell parsing, C# compilation, XAML instantiation and six Windows time-zone examples. The included workflow executes this command on a Windows runner. This does not test interactive behavior. The baseline is not yet verified in a Windows runtime.

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
