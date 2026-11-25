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
    $br=[TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time'); $ie=[TimeZoneInfo]::FindSystemTimeZoneById('GMT Standard Time')
    foreach($case in @(@{Utc='2026-11-25T16:00:00Z';BR='13:00';IE='16:00'},@{Utc='2026-07-01T16:00:00Z';BR='13:00';IE='17:00'},@{Utc='2026-03-29T00:59:00Z';BR='21:59';IE='00:59'},@{Utc='2026-03-29T01:00:00Z';BR='22:00';IE='02:00'},@{Utc='2026-10-25T00:59:00Z';BR='21:59';IE='01:59'},@{Utc='2026-10-25T01:00:00Z';BR='22:00';IE='01:00'})) {
        $utc=[DateTimeOffset]::Parse($case.Utc)
        if ([TimeZoneInfo]::ConvertTime($utc,$br).ToString('HH:mm') -ne $case.BR -or [TimeZoneInfo]::ConvertTime($utc,$ie).ToString('HH:mm') -ne $case.IE) { throw ('Timezone mismatch: '+$case.Utc) }
    }
    Write-Host 'OK: time zones / DST transitions'
    Write-Host 'Validation completed. GUI interaction still requires manual testing.'
} catch { Write-Host $_.Exception.Message -ForegroundColor Red; exit 1 }
