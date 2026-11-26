$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\PetModel.ps1')
function Assert-Pet([bool]$Condition, [string]$Label) {
    if (!$Condition) { throw ('Pet validation failed: ' + $Label) }
}
$profilePath = Join-Path ([IO.Path]::GetTempPath()) ('jeremias-pet-test-' + [Guid]::NewGuid().ToString('N') + '.json')
$ids = @('E. South America Standard Time','GMT Standard Time','UTC','Tokyo Standard Time')
$utc = [DateTimeOffset]::Parse('2026-07-01T16:00:00Z')
$state = Read-PetState $profilePath
Assert-Pet (!$state.PersistMemory -and !$state.ZoneIds.Count -and !$state.Notes.Count) 'clock and memory persistence disabled by default'
Assert-Pet (![IO.File]::Exists($profilePath)) 'reading defaults performs no write'
for ($count = 0; $count -le 4; $count++) {
    $selected = @($ids | Select-Object -First $count)
    $zones = @(Get-PetZones $selected)
    $rows = @(Get-PetClockRows $utc $zones)
    Assert-Pet ($rows.Count -eq $count) "row count $count"
    foreach ($row in $rows) { Assert-Pet ($row.Local.ToUniversalTime() -eq $utc) 'UTC instant preserved' }
}
$sample = @(Get-PetClockRows $utc @(Get-PetZones $ids))
Assert-Pet (($sample | ForEach-Object { $_.Local.ToString('HH:mm') }) -join ',' -eq '13:00,17:00,16:00,01:00') 'four zone display and DST'
foreach ($bad in @(@('UTC','UTC'),@('Invalid/Zone'),@('1','2','3','4','5'))) {
    $failed = $false
    try { $null = Get-PetZones $bad } catch { $failed = $true }
    Assert-Pet $failed 'bad zone rejected'
}
Assert-Pet ((Get-PetGreeting 'Calm' 0) -ne (Get-PetGreeting 'Playful' 0)) 'different personalities'
Assert-Pet ((Get-PetIdleCue 'Calm' $utc) -ne (Get-PetIdleCue 'Calm' $utc.AddMinutes(1))) 'local idle cue rotates'
Add-PetNote $state '  Explicit local memory only.  '
Assert-Pet ($state.Notes[0] -ceq 'Explicit local memory only.') 'explicit add and trim'
$state.ZoneIds = $ids
$state.Personality = 'Playful'
try {
    Save-PetState $state $profilePath
    $loaded = Read-PetState $profilePath
    Assert-Pet (!$loaded.Notes.Count -and $loaded.ZoneIds.Count -eq 4 -and $loaded.Personality -eq 'Playful') 'profile with memory off'
    $state.PersistMemory = $true
    Save-PetState $state $profilePath
    $loaded = Read-PetState $profilePath
    Assert-Pet ($loaded.Notes.Count -eq 1 -and $loaded.Notes[0] -ceq $state.Notes[0]) 'opt-in memory roundtrip'
    $state.PersistMemory = $false
    Save-PetState $state $profilePath
    Assert-Pet (![IO.File]::ReadAllText($profilePath).Contains($state.Notes[0])) 'opt-out removes on-disk note'
    for ($i = 1; $i -lt 20; $i++) { Add-PetNote $state "Fixture $i" }
    $failed = $false
    try { Add-PetNote $state 'Overflow' } catch { $failed = $true }
    Assert-Pet $failed 'note count bounded'
    foreach ($bad in '', ('A' * 161), "First\nSecond".Replace('\n', [string][char]10)) {
        $unbounded = New-PetState
        $failed = $false
        try { Add-PetNote $unbounded $bad } catch { $failed = $true }
        Assert-Pet $failed 'bad note rejected'
    }
} finally {
    if ([IO.File]::Exists($profilePath)) { [IO.File]::Delete($profilePath) }
}
Write-Host 'OK: pet time zones, local personality, bounded memory, consent roundtrip, and at-rest deletion'
& (Join-Path $PSScriptRoot '..\DesktopPet.ps1') -ValidateOnly
