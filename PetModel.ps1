# Pure domain helpers and an explicitly invoked, app-owned persistence boundary.
$script:PetPersonalities = @('Curious', 'Calm', 'Playful')
$script:PetMemoryLimit = 20
$script:PetNoteLimit = 160

function New-PetState {
    [pscustomobject]@{
        Version = 1; Personality = 'Curious'; ZoneIds = @()
        PersistMemory = $false; Notes = @()
    }
}

function Get-PetZones([string[]]$Ids) {
    if ($Ids.Count -gt 4) { throw 'Choose at most four time zones.' }
    $seen = @{}
    foreach ($id in $Ids) {
        if ([string]::IsNullOrWhiteSpace($id)) { throw 'A time-zone ID is missing.' }
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById($id)
        if ($seen.ContainsKey($zone.Id)) { throw 'Choose different time zones.' }
        $seen[$zone.Id] = $true
        $zone
    }
}

function Get-PetClockRows([DateTimeOffset]$Utc, [TimeZoneInfo[]]$Zones) {
    foreach ($zone in $Zones) {
        $local = [TimeZoneInfo]::ConvertTime($Utc, $zone)
        [pscustomobject]@{ Id = $zone.Id; Local = $local }
    }
}

function Get-PetGreeting([string]$Personality, [int]$MemoryCount) {
    $line = switch ($Personality) {
        'Calm'    { 'One step at a time.' }
        'Playful' { 'Three heads. One good idea. Probably.' }
        default   { 'What are we figuring out today?' }
    }
    if ($MemoryCount -gt 0) { return "$line Local notes: $MemoryCount." }
    return $line
}

function Get-PetIdleCue([string]$Personality, [DateTimeOffset]$Utc) {
    $index = [int]([Math]::Floor($Utc.UtcDateTime.TimeOfDay.TotalMinutes) % 3)
    $lines = switch ($Personality) {
        'Calm'    { @('Resting nearby.', 'Taking a quiet breath.', 'Here when you need me.') }
        'Playful' { @('Guarding the desk.', 'Counting dragon heads.', 'Looking politely suspicious.') }
        default   { @('Keeping you company.', 'Thinking about small things.', 'Watching time go by.') }
    }
    return $lines[$index]
}

function Add-PetNote($State, [string]$Note) {
    $clean = $Note.Trim()
    if (!$clean -or $clean.Length -gt $script:PetNoteLimit -or $clean -match '\p{Cc}') {
        throw "Write one line of 1 to $script:PetNoteLimit characters."
    }
    if (@($State.Notes).Count -ge $script:PetMemoryLimit) { throw 'Remove a note before adding another.' }
    $State.Notes = @($State.Notes) + @($clean)
}

function Read-PetState([string]$Path) {
    $state = New-PetState
    if (![IO.File]::Exists($Path)) { return $state }
    if (([IO.FileInfo]::new($Path)).Length -gt 32768) { throw 'Stored profile is too large.' }
    $saved = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ($saved.Version -ne 1 -or $script:PetPersonalities -cnotcontains $saved.Personality -or
        $saved.PersistMemory -isnot [bool]) { throw 'Invalid pet profile.' }
    $state.Personality = $saved.Personality
    $state.ZoneIds = @(Get-PetZones @($saved.ZoneIds) | ForEach-Object { $_.Id })
    $state.PersistMemory = $saved.PersistMemory
    if ($state.PersistMemory) {
        foreach ($note in $saved.Notes) {
            if ($note -isnot [string]) { throw 'Invalid stored note.' }
            Add-PetNote $state $note
        }
    }
    return $state
}

function Save-PetState($State, [string]$Path) {
    $payload = [ordered]@{
        Version = 1; Personality = $State.Personality; ZoneIds = @($State.ZoneIds)
        PersistMemory = [bool]$State.PersistMemory
        Notes = @()
    }
    if ($State.PersistMemory) { $payload.Notes = @($State.Notes) }
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    $tmp = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($tmp, ($payload | ConvertTo-Json -Depth 3), [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
        else { [IO.File]::Move($tmp, $Path) }
    } finally {
        if ([IO.File]::Exists($tmp)) { [IO.File]::Delete($tmp) }
    }
}
