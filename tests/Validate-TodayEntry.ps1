$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$Project = Split-Path -Parent $PSScriptRoot
$originalLocalAppData = $env:LOCALAPPDATA
$env:LOCALAPPDATA = Join-Path ([IO.Path]::GetTempPath()) ('Jeremias-Review-' + [Guid]::NewGuid().ToString('N'))
$smokeApp = [Windows.Application]::new()
$smokeApp.ShutdownMode = 'OnExplicitShutdown'
$smoke = @{ Phase = 0; Error = $null; Clock = $null; Done = $false }
$smokeTimer = [Windows.Threading.DispatcherTimer]::new()
$smokeTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$panelTimer = [Windows.Threading.DispatcherTimer]::new()
$panelTimer.Interval = [TimeSpan]::FromMilliseconds(300)
function Invoke-SmokeClick($element, $event) { $element.RaiseEvent([Windows.RoutedEventArgs]::new($event)) }
$smokeTimer.Add_Tick({
    try {
        if ($smoke.Phase -eq 0) {
            $clock = $smokeApp.Windows | Where-Object Title -eq 'Jeremias World Clock' | Select-Object -First 1
            if ($null -eq $clock -or -not $clock.IsLoaded) { return }
            $smoke.Clock = $clock
            $item = $clock.ContextMenu.Items | Where-Object Header -eq 'Today'
            if ($null -eq $item) { throw 'Today menu missing.' }
            $clock.FindName('TravelSlider').Value = 1440
            $smoke.Phase = 1
            $panelTimer.Start()
            Invoke-SmokeClick $item ([Windows.Controls.MenuItem]::ClickEvent)
            if ($smoke.Error) { throw $smoke.Error }
            if (-not $smoke.Done) { throw 'Today menu did not open dialog.' }
            $smokeTimer.Stop()
            $clock.Close()
        }
    } catch {
        $smoke.Error = $_
        $smokeTimer.Stop()
        foreach ($testWindow in @($smokeApp.Windows)) { $testWindow.Close() }
    }
})
$panelTimer.Add_Tick({
    try {
        if ($smoke.Phase -eq 1) {
            $panel = $smokeApp.Windows | Where-Object Title -eq 'Jeremias Today' | Select-Object -First 1
            if ($null -eq $panel -or -not $panel.IsLoaded) { return }
            $panelTimer.Stop()
            $smoke.Phase = 2
            if ($panel.Owner -ne $smoke.Clock) { throw 'Unexpected panel owner.' }
            if (-not $panel.FindName('LocalDate').Text.StartsWith([DateTime]::Now.ToString('D'))) { throw 'Today date is not live time.' }
            $panel.FindName('EntryTitle').Text = 'Dublin focus fixture'
            $panel.FindName('EntryKind').SelectedIndex = 1
            Invoke-SmokeClick ($panel.FindName('SaveEntry')) ([Windows.Controls.Button]::ClickEvent)
            if ($panel.FindName('Status').Text -ne 'Event saved.') { throw $panel.FindName('Status').Text }
            $panel.FindName('NotesTab').IsSelected = $true
            $panel.FindName('NoteTitle').Text = 'Launcher smoke'
            $panel.FindName('NoteText').Text = 'Temporary fixture'
            Invoke-SmokeClick ($panel.FindName('SaveNote')) ([Windows.Controls.Button]::ClickEvent)
            if ($panel.FindName('Status').Text -ne 'Note saved.') { throw $panel.FindName('Status').Text }
            $smoke.Done = $true
            $panel.Close()
        }
    } catch {
        $smoke.Error = $_
        $smokeTimer.Stop()
        foreach ($testWindow in @($smokeApp.Windows)) { $testWindow.Close() }
    }
})
$timeoutTimer = [Windows.Threading.DispatcherTimer]::new()
$timeoutTimer.Interval = [TimeSpan]::FromSeconds(8)
$timeoutTimer.Add_Tick({
    $timeoutTimer.Stop()
    $smoke.Error = 'Timed out opening the clock or Today dialog.'
    foreach ($testWindow in @($smokeApp.Windows)) { $testWindow.Close() }
})
try {
    $smokeTimer.Start()
    $timeoutTimer.Start()
    & (Join-Path $Project 'WorldClock.ps1') -Review
    if ($smoke.Error) { throw $smoke.Error }
    if (-not $smoke.Done) { throw 'Review launcher returned before the widget loaded.' }
    $saved = Join-Path $env:LOCALAPPDATA 'JeremiasWorldClock.Review\productivity.json'
    if (-not [IO.File]::Exists($saved)) { throw 'Review data was not persisted.' }
    if (Test-Path (Join-Path $env:LOCALAPPDATA 'JeremiasWorldClock')) { throw 'Normal data folder unexpectedly created.' }
    $snapshot = Get-Content -Raw -LiteralPath $saved | ConvertFrom-Json
    if ($snapshot.Notes[0].Title -ne 'Launcher smoke' -or $snapshot.Entries[0].Kind -ne 'Focus') { throw 'Review data did not match the fixture.' }
    Write-Host 'OK: Review mode, Today menu, live date during Time Travel, focus block and note saves'
} finally {
    $smokeTimer.Stop()
    $panelTimer.Stop()
    $timeoutTimer.Stop()
    $smokeApp.Shutdown()
    $fixtureRoot = $env:LOCALAPPDATA
    $env:LOCALAPPDATA = $originalLocalAppData
    $reviewFolder = Join-Path $fixtureRoot 'JeremiasWorldClock.Review'
    if ([IO.Directory]::Exists($reviewFolder)) {
        foreach ($fixture in [IO.Directory]::EnumerateFiles($reviewFolder)) { [IO.File]::Delete($fixture) }
        [IO.Directory]::Delete($reviewFolder)
    }
    if ([IO.Directory]::Exists($fixtureRoot)) { [IO.Directory]::Delete($fixtureRoot) }
}
