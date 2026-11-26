$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
foreach($f in 'ResponsibilityStore.ps1','CalendarActivity.ps1','MeetingBrief.ps1','ClockModel.ps1'){ . (Join-Path $root $f) }
function Confirm($ok,[string]$label) { if(-not $ok){throw $label} }
$dir=Join-Path ([IO.Path]::GetTempPath()) ('Jeremias-pilot-'+[guid]::NewGuid().ToString('N'))
$activity=Join-Path $dir 'activity.json';$agenda=Join-Path $dir 'productivity.json';$cache=Join-Path $dir 'calendar.json'
$now=[DateTimeOffset]::Parse('2026-07-01T12:00:00Z')
$cal='fixture-dublin'
try {
    Save-ProductivityStore -Path $agenda -Data @{Version=1;Entries=@(
        @{Id='focus-n1';Kind='Focus';Title='Protected focus';StartUtc='2026-07-01T16:00:00Z';EndUtc='2026-07-01T17:00:00Z'}
    );Notes=@()}
    $story=@{ id='occurrence';recurringEventId='series';etag='before';summary='Fixture design review'
        originalStartTime=@{ dateTime='2026-07-01T16:00:00+01:00' }
        start=@{dateTime='2026-07-01T16:00:00+01:00'}; end=@{dateTime='2026-07-01T17:00:00+01:00'} }
    $provider={param($uri) if($uri -notmatch '/calendars/fixture-dublin/events\?'){throw 'Wrong selected calendar'}; @{items=@($story)} }
    $first=Update-JeremiasCalendarCache -Path $cache -CalendarId $cal -Fetch $provider -Now $now
    Confirm ($first.Status -ceq 'Fresh' -and $first.Entries.Count -eq 1) 'Cannot read fixture calendar'
    $id=$first.Entries[0].Id
    $r=New-MeetingResponsibility -Path $activity -Title $story.summary -SourceId $cal -MeetingId $id -Scope Calendar
    $argsForCheck=@{Path=$activity;AgendaPath=$agenda;CalendarPath=$cache;Now=$now}
    Confirm (@(Invoke-JeremiasResponsibilityChecks @argsForCheck).Count -eq 0) 'Before move: boundary touch alerted'
    $story.start.dateTime='2026-07-01T17:00:00+01:00';$story.end.dateTime='2026-07-01T17:30:00+01:00';$story.etag='moved'
    $moved=Update-JeremiasCalendarCache -Path $cache -CalendarId $cal -Fetch $provider -Now $now
    Confirm ($moved.Entries[0].Id -ceq $id) 'A moved occurrence changed identity'
    $b=[TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time')
    $i=[TimeZoneInfo]::FindSystemTimeZoneById('GMT Standard Time')
    $time=Get-ClockSnapshot (ConvertTo-JeremiasCalendarTime $moved.Entries[0].StartUtc) $b $i
    Confirm ($time.Brazil.ToString('HH:mm') -eq '13:00' -and $time.Ireland.ToString('HH:mm') -eq '17:00') 'Dublin summer time lost'
    $alert=@(Invoke-JeremiasResponsibilityChecks @argsForCheck)
    Confirm ($alert.Count -eq 1 -and $alert[0].Revision -ceq 'moved') 'Move failed to emit one conflict with no gateway'
    Confirm (@(Invoke-JeremiasResponsibilityChecks @argsForCheck).Count -eq 0) 'Replayed update duplicated conflict'
    Confirm (@((Read-ResponsibilityStore $activity).Runs).Count -eq 1) 'Conflict was not durable'
    $story.etag='stale-unseen'
    $null=Update-JeremiasCalendarCache -Path $cache -CalendarId $cal -Fetch $provider -Now $now
    $argsForCheck.Now=$now.AddMinutes(31)
    Confirm (@(Invoke-JeremiasResponsibilityChecks @argsForCheck).Count -eq 0) 'Stale cache created a new conflict'
    $fixture=Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'fixtures/meeting-brief/selected.json')|ConvertFrom-Json
    $briefR=New-MeetingResponsibility -Path $activity -Title $fixture.meeting.Title -SourceId 'offline' -MeetingId $fixture.meeting.Id
    $request=New-JeremiasMeetingBriefRequest -Meeting $fixture.meeting -Notes $fixture.notes -AllowedSourceIds $fixture.allowed -NowUtc $now
    $json=ConvertTo-Json -InputObject @{version=1;runId=$request.Preview.RunId;meetingRevision='2';summary='Compare the two draft formats.';sourceIds=@('meeting-a','note-a')}
    $argsForBrief=@{Path=$activity;ResponsibilityId=$briefR.Id;Request=$request;ResultJson=$json;Meeting=$fixture.meeting
                    Notes=$fixture.notes;AllowedSourceIds=$fixture.allowed;ToolsUsed=0;TokensUsed=38;NowUtc=$now}
    $brief=Add-JeremiasMeetingBriefToActivity @argsForBrief
    Confirm ($brief.Status -eq 'ReviewReady' -and $brief.Citations.Count -eq 2 -and $brief.SourceId -ceq 'offline') 'Brief cannot be persisted in Activity'
    $null=Add-JeremiasMeetingBriefToActivity @argsForBrief
    Confirm (@((Read-ResponsibilityStore $activity).Runs).Count -eq 2) 'Brief replay duplicated Activity'
    $fixture.meeting.Revision='3'
    $blocked=$false
    try { $null=Add-JeremiasMeetingBriefToActivity @argsForBrief } catch { $blocked=$_.Exception.Message -like '*sources changed*' }
    Confirm $blocked 'Stale brief was not rejected'
    Write-Host 'OK: synthetic pilot, stable occurrence, DST, one alert, stale cache, scoped brief and Activity'
} finally {
    if([IO.Directory]::Exists($dir)){ foreach($p in [IO.Directory]::GetFiles($dir)){ [IO.File]::Delete($p) };[IO.Directory]::Delete($dir) }
}
