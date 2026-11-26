function ConvertTo-JeremiasCalendarTime([object]$Value) {
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime() }
    if ($Value -is [DateTime] -and $Value.Kind -ne 'Unspecified') { return ([DateTimeOffset]$Value).ToUniversalTime() }
    $parsed = [DateTimeOffset]::MinValue
    if ($Value -is [string] -and $Value -match '(?:Z|[+-]\d{2}:\d{2})$' -and
        [DateTimeOffset]::TryParse($Value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
        return $parsed.ToUniversalTime()
    }
    throw 'Calendar event did not specify an unambiguous UTC offset.'
}

function Read-JeremiasCalendarCache {
    param([Parameter(Mandatory)][string]$Path, [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow)
    $empty = [pscustomobject]@{ Version = 1; CalendarId = $null; Status = 'Disconnected'; LastSuccessUtc = $null; Entries = @() }
    if (-not [IO.File]::Exists($Path)) { return $empty }
    try {
        $data = [IO.File]::ReadAllText($Path) | ConvertFrom-Json -ErrorAction Stop
        if ($data.Version -ne 1 -or [string]::IsNullOrWhiteSpace($data.CalendarId) -or $data.Entries -isnot [array] -or
            $data.Status -cnotin 'Fresh', 'Offline', 'Revoked') { throw 'Invalid cache.' }
        if ($data.Status -eq 'Revoked' -and $data.Entries.Count) { throw 'Invalid revoked cache.' }
        if ($data.LastSuccessUtc -or $data.Status -eq 'Fresh' -or $data.Entries.Count) {
            $last = ConvertTo-JeremiasCalendarTime $data.LastSuccessUtc
            if ($data.Status -eq 'Fresh' -and $Now -gt $last.AddMinutes(30)) { $data.Status = 'Stale' }
        }
        foreach ($item in $data.Entries) {
            if (-not $item.Id -or -not $item.Revision -or $item.Kind -cne 'Calendar' -or $item.ReadOnly -ne $true -or
                (ConvertTo-JeremiasCalendarTime $item.StartUtc) -ge (ConvertTo-JeremiasCalendarTime $item.EndUtc)) { throw 'Invalid event.' }
        }
        return $data
    } catch {
        $empty.Status = 'Unreadable'
        return $empty
    }
}

function Save-JeremiasCalendarCache($Path, $Data) {
    $destination = [IO.Path]::GetFullPath($Path)
    $directory = [IO.Path]::GetDirectoryName($destination)
    $null = [IO.Directory]::CreateDirectory($directory)
    $pending = Join-Path $directory ('.calendar-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($pending, (ConvertTo-Json -InputObject $Data -Depth 6 -ErrorAction Stop), [Text.UTF8Encoding]::new($false))
        if ([IO.File]::Exists($destination)) { [IO.File]::Replace($pending, $destination, [NullString]::Value) }
        else { [IO.File]::Move($pending, $destination) }
    } finally {
        if ([IO.File]::Exists($pending)) { [IO.File]::Delete($pending) }
    }
}

function Update-JeremiasCalendarCache {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CalendarId,
        [Parameter(Mandatory)][scriptblock]$Fetch,
        [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow
    )
    if ([string]::IsNullOrWhiteSpace($CalendarId) -or $CalendarId -ieq 'primary') {
        throw 'Supply the exact calendar ID, not the primary alias.'
    }
    $previous = Read-JeremiasCalendarCache -Path $Path -Now $Now
    $same = $CalendarId -ceq $previous.CalendarId
    $data = [pscustomobject]@{ Version = 1; CalendarId = $CalendarId; Status = 'Fresh'; LastSuccessUtc = $null; Entries = @() }
    $first = 'https://www.googleapis.com/calendar/v3/calendars/{0}/events?singleEvents=true&showDeleted=false&timeMin={1}&timeMax={2}&maxResults=2500&fields=nextPageToken%2Citems(id%2Cetag%2Cstatus%2Csummary%2Cstart%2Cend%2CrecurringEventId%2CoriginalStartTime)' -f
        [Uri]::EscapeDataString($CalendarId), [Uri]::EscapeDataString($Now.AddDays(-1).ToString('o')), [Uri]::EscapeDataString($Now.AddDays(7).ToString('o'))
    $token = ''
    $pages = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $entries = [Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    try {
        do {
            if ($pages.Count -ge 100 -or -not $pages.Add($token)) { throw 'Calendar pagination was incomplete.' }
            $uri = $first
            if ($token) { $uri += '&pageToken=' + [Uri]::EscapeDataString($token) }
            $page = & $Fetch $uri
            if ($null -eq $page -or ($null -ne $page.items -and $page.items -isnot [array])) { throw 'Invalid calendar page.' }
            foreach ($item in $page.items) {
                if ($item.status -eq 'cancelled' -or $item.start.date) { continue }
                if (-not $item.id -or -not $item.etag) { throw 'Missing event ID or revision.' }
                $start = ConvertTo-JeremiasCalendarTime $item.start.dateTime
                $end = ConvertTo-JeremiasCalendarTime $item.end.dateTime
                if ($start -ge $end) { throw 'Invalid event interval.' }
                $id = 'google:single:' + $item.id
                if ($item.recurringEventId) {
                    $original = ConvertTo-JeremiasCalendarTime $item.originalStartTime.dateTime
                    $id = 'google:recurring:' + $item.recurringEventId + ':' + $original.ToString('o')
                }
                if ($entries.Contains($id) -and $entries[$id].Revision -cne $item.etag) { throw 'Conflicting revisions in refresh.' }
                $entries[$id] = [pscustomobject]@{
                    Id = $id; Revision = $item.etag; Title = $(if ($item.summary) { [string]$item.summary } else { '(Untitled event)' })
                    Kind = 'Calendar'; StartUtc = $start.ToString('o'); EndUtc = $end.ToString('o'); ReadOnly = $true
                }
            }
            $token = [string]$page.nextPageToken
        } while ($token)
        $data.Entries = @($entries.Values)
        $data.LastSuccessUtc = $Now.ToUniversalTime().ToString('o')
    } catch {
        if ($_.Exception.Data['CalendarStatus'] -eq 'Revoked') { $data.Status = 'Revoked' }
        else {
            $data.Status = 'Offline'
            if ($same -and $previous.Status -eq 'Revoked') { $data.Status = 'Revoked' }
            elseif ($same) { $data.Entries = $previous.Entries; $data.LastSuccessUtc = $previous.LastSuccessUtc }
        }
    }
    Save-JeremiasCalendarCache $Path $data
    return $data
}
