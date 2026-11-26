$ErrorActionPreference = 'Stop'
try {
    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
    $tokens=$null; $errors=$null
    $file = Join-Path $PSScriptRoot 'WorldClock.ps1'
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file,[ref]$tokens,[ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
    Write-Host 'OK: PowerShell'
    Add-Type -Path (Join-Path $PSScriptRoot 'WindowBridge.cs')
    Write-Host 'OK: Win32 helper'
    $source = Get-Content -Raw $file
    $match = [regex]::Match($source,"(?s)\[xml\]\`$xaml = @'\r?\n(.*?)\r?\n'@")
    if (-not $match.Success) { throw 'XAML not found' }
    [xml]$xaml = $match.Groups[1].Value
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    $window = [Windows.Markup.XamlReader]::Load($reader); $reader.Close()
    if ($null -eq $window.FindName('TravelSlider')) { throw 'Slider not found' }
    Write-Host 'OK: XAML / WPF'
    . (Join-Path $PSScriptRoot 'ClockModel.ps1')
    $br=[TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time'); $ie=[TimeZoneInfo]::FindSystemTimeZoneById('GMT Standard Time')
    foreach($case in @(@{Utc='2026-11-25T16:00:00Z';BR='13:00';IE='16:00'},@{Utc='2026-07-01T16:00:00Z';BR='13:00';IE='17:00'},@{Utc='2026-03-29T00:59:00Z';BR='21:59';IE='00:59'},@{Utc='2026-03-29T01:00:00Z';BR='22:00';IE='02:00'},@{Utc='2026-10-25T00:59:00Z';BR='21:59';IE='01:59'},@{Utc='2026-10-25T01:00:00Z';BR='22:00';IE='01:00'})) {
        $utc=[DateTimeOffset]::Parse($case.Utc)
        $snapshot = Get-ClockSnapshot $utc $br $ie
        if ($snapshot.Brazil.ToString('HH:mm') -ne $case.BR -or $snapshot.Ireland.ToString('HH:mm') -ne $case.IE) { throw ('Timezone mismatch: '+$case.Utc) }
    }
    Write-Host 'OK: time zones / DST transitions'
    $instant = [DateTimeOffset]::Parse('2026-11-25T00:43:37.125Z')
    $anchor = Get-TravelAnchor $instant $br
    if ($anchor -ne [DateTimeOffset]::Parse('2026-11-25T00:30:00Z')) { throw 'Preview anchor mismatch' }
    $preview = Get-ClockSnapshot ($anchor.AddMinutes((Get-TravelOffset -30))) $br $ie
    if ($preview.Brazil.Day -ne 24 -or $preview.Ireland.Day -ne 25) { throw 'Preview midnight mismatch' }
    if ((Get-TravelOffset 16) -ne 15 -or (Get-TravelOffset -1500) -ne -1440 -or (Get-TravelOffset 1500) -ne 1440) { throw 'Preview step or bound mismatch' }
    if ((Get-TravelRemaining ([TimeSpan]::FromSeconds(11))) -ne 1 -or (Get-TravelRemaining ([TimeSpan]::FromSeconds(12))) -ne 0) { throw 'Preview idle reset mismatch' }
    Write-Host 'OK: Time Travel anchor, bounds, idle countdown and midnight'
    Write-Host 'Validation completed. GUI interaction still requires manual testing.'
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
