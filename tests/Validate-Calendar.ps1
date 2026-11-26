$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\CalendarConnector.ps1')
$cache = Join-Path ([IO.Path]::GetTempPath()) ('jeremias-calendar-' + [Guid]::NewGuid() + '.json')
try {
    $fixture = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures\calendar\dst.json')) | ConvertFrom-Json
    $now = [DateTimeOffset]'2026-10-24T23:00:00Z'
    $seen = [Collections.Generic.List[string]]::new()
    $source = { param($uri) $seen.Add([string]$uri); $fixture }
    $result = Update-JeremiasCalendarCache -Path $cache -CalendarId 'test/calendar@example.invalid' -Fetch $source -Now $now
    if ($result.Status -ne 'Fresh' -or $result.Entries.Count -ne 2) { throw 'Timed occurrences and duplicates not normalized.' }
    if ($seen.Count -ne 1 -or $seen[0] -cnotmatch 'https://www.googleapis.com/calendar/v3/calendars/test%2Fcalendar%40example.invalid/events\?singleEvents=true') { throw 'Wrong calendar endpoint.' }
    $disk = Read-JeremiasCalendarCache -Path $cache -Now $now
    if (($disk.Entries[0].Id -eq $disk.Entries[1].Id) -or $disk.Entries[0].Revision -ne 'rev2') { throw 'Identity or revision lost.' }
    $aged = Read-JeremiasCalendarCache -Path $cache -Now $now.AddMinutes(31)
    if ($aged.Status -ne 'Stale' -or $aged.Entries.Count -ne 2) { throw 'Age did not mark cache stale.' }
    $fixture.items[0].start.dateTime = '2026-10-25T01:30:00'
    $bad = Update-JeremiasCalendarCache -Path $cache -CalendarId $disk.CalendarId -Fetch $source -Now $now
    if ($bad.Status -ne 'Offline' -or $bad.Entries.Count -ne 2) { throw 'Offset-free repeated hour was accepted.' }
    $fixture.items[0].start.dateTime = '2026-10-25T02:00:00+00:00'
    $replay = Update-JeremiasCalendarCache -Path $cache -CalendarId $disk.CalendarId -Fetch $source -Now $now
    if ($replay.Entries.Count -ne 2 -or $replay.Entries[0].Id -cne $disk.Entries[0].Id) { throw 'Revision replay duplicated or changed identity.' }
    $fixture.items[0].etag = $fixture.items[1].etag = 'rev5'
    $changed = Update-JeremiasCalendarCache -Path $cache -CalendarId $disk.CalendarId -Fetch $source -Now $now
    if ($changed.Entries[0].Id -cne $disk.Entries[0].Id -or $changed.Entries[0].Revision -cne 'rev5') { throw 'A source update changed the occurrence identity or failed to replace its revision.' }
    $stale = Update-JeremiasCalendarCache -Path $cache -CalendarId $disk.CalendarId -Fetch { throw 'offline' } -Now $now.AddHours(2)
    if ($stale.Status -ne 'Offline' -or $stale.Entries.Count -ne 2) { throw 'Offline refresh discarded entries.' }
    $revoked = Update-JeremiasCalendarCache -Path $cache -CalendarId $disk.CalendarId -Fetch { $e = [Exception]::new(); $e.Data['CalendarStatus'] = 'Revoked'; throw $e } -Now $now
    if ($revoked.Status -ne 'Revoked' -or $revoked.Entries.Count -ne 0) { throw 'Revocation did not clear entries.' }
    $new = Update-JeremiasCalendarCache -Path $cache -CalendarId 'new@example.invalid' -Fetch { throw 'offline' } -Now $now
    if ($new.Status -ne 'Offline' -or $new.CalendarId -ne 'new@example.invalid' -or $new.Entries.Count) { throw 'Calendar switch retained the wrong snapshot.' }
    Write-Host 'Calendar fixtures passed.'
} finally {
    if (Test-Path -LiteralPath $cache) { Remove-Item -LiteralPath $cache }
}
