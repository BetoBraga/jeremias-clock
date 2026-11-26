param([switch]$ValidateOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
. (Join-Path $PSScriptRoot 'PetModel.ps1')
$statePath = Join-Path $env:LOCALAPPDATA 'JeremiasDesktopPet\state.json'
$startupWarning = ''
try { $state = if ($ValidateOnly) { New-PetState } else { Read-PetState $statePath } }
catch {
    $state = New-PetState
    $startupWarning = 'The saved profile could not be read. Defaults are in use.'
}
$markup = [xml][IO.File]::ReadAllText((Join-Path $PSScriptRoot 'DesktopPet.xaml'))
$reader = [Xml.XmlNodeReader]::new($markup)
try { $window = [Windows.Markup.XamlReader]::Load($reader) }
finally { $reader.Close() }
$controls = @{}
foreach ($name in 'Mascot','Mood','Greet','Personality','Zone1','Zone2','Zone3','Zone4','ApplyZones',
    'ClockPanel','ClockRows','NewNote','Notes','Remember','Forget','Persist','Status') {
    $controls[$name] = $window.FindName($name)
}
$asset = Join-Path $PSScriptRoot 'assets\jeremias.png'
$controls.Mascot.Source = [Windows.Media.Imaging.BitmapImage]::new([Uri]::new($asset))
$controls.Personality.ItemsSource = $script:PetPersonalities
$controls.Personality.SelectedItem = $state.Personality
$off = [pscustomobject]@{ Id = ''; DisplayName = 'Off' }
$choices = @($off) + @([TimeZoneInfo]::GetSystemTimeZones() | Sort-Object DisplayName)
$slots = @($controls.Zone1,$controls.Zone2,$controls.Zone3,$controls.Zone4)
for ($i = 0; $i -lt $slots.Count; $i++) {
    $slots[$i].ItemsSource = $choices
    $slots[$i].DisplayMemberPath = 'DisplayName'
    $slots[$i].SelectedValuePath = 'Id'
    $slots[$i].SelectedValue = if ($i -lt @($state.ZoneIds).Count) { $state.ZoneIds[$i] } else { '' }
}
$controls.Persist.IsChecked = $state.PersistMemory
$controls.Status.Text = $startupWarning
$ui = @{ Zones = @(Get-PetZones @($state.ZoneIds)); PauseCueUntil = [DateTimeOffset]::MinValue }
$clockTimer = [Windows.Threading.DispatcherTimer]::new()
$clockTimer.Interval = [TimeSpan]::FromMinutes(1)
$cueTimer = [Windows.Threading.DispatcherTimer]::new()
$cueTimer.Interval = [TimeSpan]::FromMinutes(1)

function Write-Profile {
    if (!$ValidateOnly) { Save-PetState $state $statePath }
}

function Set-ClockPanel([DateTimeOffset]$Utc) {
    if (!$ui.Zones.Count) {
        $clockTimer.Stop()
        $controls.ClockPanel.Visibility = 'Collapsed'
        $controls.ClockRows.ItemsSource = $null
        return
    }
    $controls.ClockPanel.Visibility = 'Visible'
    $controls.ClockRows.ItemsSource = @(
        Get-PetClockRows $Utc $ui.Zones | ForEach-Object {
            $_.Local.ToString('HH:mm  ddd, dd MMM  zzz') + '  ' + $_.Id
        }
    )
}

function Set-IdleCue([DateTimeOffset]$Utc) {
    if ($Utc -ge $ui.PauseCueUntil) {
        $controls.Mood.Text = Get-PetIdleCue $state.Personality $Utc
    }
}

$clockTimer.Add_Tick({ Set-ClockPanel ([DateTimeOffset]::UtcNow) })
$cueTimer.Add_Tick({
    if ($window.WindowState -ne 'Minimized') { Set-IdleCue ([DateTimeOffset]::UtcNow) }
})
$controls.Greet.Add_Click({
    $ui.PauseCueUntil = [DateTimeOffset]::UtcNow.AddMinutes(1)
    $controls.Mood.Text = Get-PetGreeting $state.Personality @($state.Notes).Count
})
$controls.Personality.Add_SelectionChanged({
    if ($controls.Personality.SelectedItem -in $script:PetPersonalities) {
        $state.Personality = $controls.Personality.SelectedItem
        $ui.PauseCueUntil = [DateTimeOffset]::MinValue
        Set-IdleCue ([DateTimeOffset]::UtcNow)
        try { Write-Profile; $controls.Status.Text = '' }
        catch { $controls.Status.Text = 'Personality changed for this session. The profile could not be saved.' }
    }
})
$controls.ApplyZones.Add_Click({
    try { $selected = @(Get-PetZones @($slots | ForEach-Object { $_.SelectedValue } | Where-Object { $_ })) }
    catch { $controls.Status.Text = 'Choose up to four different Windows time zones.'; return }
    $ui.Zones = $selected
    $state.ZoneIds = @($selected | ForEach-Object { $_.Id })
    Set-ClockPanel ([DateTimeOffset]::UtcNow)
    if ($selected.Count -and $window.WindowState -ne 'Minimized') { $clockTimer.Start() }
    try { Write-Profile; $controls.Status.Text = '' }
    catch { $controls.Status.Text = 'Clock changed for this session. The profile could not be saved.' }
})
$controls.Notes.ItemsSource = @($state.Notes)
$controls.Remember.Add_Click({
    try { Add-PetNote $state $controls.NewNote.Text }
    catch { $controls.Status.Text = $_.Exception.Message; return }
    $controls.Notes.ItemsSource = @($state.Notes)
    $controls.NewNote.Clear()
    $controls.Status.Text = ''
    if ($state.PersistMemory) {
        try { Write-Profile }
        catch { $controls.Status.Text = 'Note added for this session. The profile could not be saved.' }
    }
})
$controls.Forget.Add_Click({
    $index = $controls.Notes.SelectedIndex
    if ($index -lt 0) { return }
    $old = @($state.Notes)
    $state.Notes = @(for ($i = 0; $i -lt $old.Count; $i++) { if ($i -ne $index) { $old[$i] } })
    try {
        if ($state.PersistMemory) { Write-Profile }
        $controls.Notes.ItemsSource = @($state.Notes)
        $controls.Status.Text = ''
    } catch {
        $state.Notes = $old
        $controls.Status.Text = 'The saved note could not be removed. Please try again.'
    }
})
$controls.Persist.Add_Click({
    $wasEnabled = $state.PersistMemory
    $state.PersistMemory = [bool]$controls.Persist.IsChecked
    try { Write-Profile; $controls.Status.Text = '' }
    catch {
        $state.PersistMemory = $wasEnabled
        $controls.Persist.IsChecked = $wasEnabled
        $controls.Status.Text = 'The storage setting did not change because the profile could not be saved.'
    }
})
$window.Add_StateChanged({
    if ($window.WindowState -eq 'Minimized') { $clockTimer.Stop(); $cueTimer.Stop() }
    else {
        Set-ClockPanel ([DateTimeOffset]::UtcNow)
        if ($ui.Zones.Count) { $clockTimer.Start() }
        Set-IdleCue ([DateTimeOffset]::UtcNow)
        $cueTimer.Start()
    }
})
$window.Add_Closed({ $clockTimer.Stop(); $cueTimer.Stop() })
$now = [DateTimeOffset]::UtcNow
Set-ClockPanel $now
Set-IdleCue $now
if ($ui.Zones.Count) { $clockTimer.Start() }
$cueTimer.Start()
if ($ValidateOnly) {
    $cueTimer.Stop()
    if ($clockTimer.IsEnabled -or $controls.ClockPanel.Visibility -ne 'Collapsed') {
        throw 'Clock is unexpectedly active on first launch.'
    }
    $controls.Zone1.SelectedValue = 'UTC'
    $controls.Zone2.SelectedValue = 'GMT Standard Time'
    $controls.Zone3.SelectedValue = 'E. South America Standard Time'
    $controls.Zone4.SelectedValue = 'Tokyo Standard Time'
    $controls.ApplyZones.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($controls.ClockPanel.Visibility -ne 'Visible' -or $controls.ClockRows.Items.Count -ne 4) {
        throw 'Pet WPF did not display four clock rows.'
    }
    foreach ($slot in $slots) { $slot.SelectedValue = '' }
    $controls.ApplyZones.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($clockTimer.IsEnabled -or $controls.ClockPanel.Visibility -ne 'Collapsed') {
        throw 'Turning the optional clock off did not stop the refresh.'
    }
    $controls.NewNote.Text = 'Synthetic local WPF note.'
    $controls.Remember.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    $controls.Greet.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($controls.Notes.Items.Count -ne 1 -or $controls.Mood.Text -notmatch 'Local notes: 1') {
        throw 'Pet WPF local note and greeting did not work.'
    }
    $controls.Notes.SelectedIndex = 0
    $controls.Forget.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
    if ($controls.Notes.Items.Count -ne 0) { throw 'Pet WPF did not remove the selected note.' }
    $window.Close()
    Write-Host 'OK: pet WPF controls, optional clock transitions, and local note interactions'
    return
}
$null = $window.ShowDialog()
