# Join a previously selected, fresh read-only snapshot to local focus blocks.
# This file never refreshes the provider, dispatches AI, or touches settings.
. (Join-Path $PSScriptRoot 'CalendarConnector.ps1')

function Get-JeremiasActivityMeetingChoices {
    param($Agenda, $Calendar, [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow)
    foreach ($entry in $Agenda.Entries) {
        if ($entry.Kind -ceq 'Meeting' -and (ConvertTo-ProductivityUtc $entry.EndUtc) -gt $Now) {
            [pscustomobject]@{ Id=$entry.Id; SourceId='offline'; Scope='LocalAgenda'; Label="$($entry.Title) [Local]"; Title=$entry.Title; Revision='' }
        }
    }
    if ($Calendar.Status -ceq 'Fresh') {
        foreach ($entry in $Calendar.Entries) {
            if ((ConvertTo-JeremiasCalendarTime $entry.EndUtc) -gt $Now) {
                [pscustomobject]@{ Id=$entry.Id; SourceId=$Calendar.CalendarId; Scope='Calendar'; Label="$($entry.Title) [Selected calendar]"; Title=$entry.Title; Revision=$entry.Revision }
            }
        }
    }
}

function Invoke-JeremiasResponsibilityChecks {
    param([string]$Path, [string]$AgendaPath, [string]$CalendarPath,
          [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow)
    if (-not [IO.File]::Exists($Path)) { return }
    Invoke-LocalResponsibilityChecks -Path $Path -AgendaPath $AgendaPath -Now $Now
    $calendar = Read-JeremiasCalendarCache -Path $CalendarPath -Now $Now
    if ($calendar.Status -cne 'Fresh') { return }
    $agenda = Read-ProductivityStore $AgendaPath
    if ($agenda.Warning) { throw $agenda.Warning }
    $events = @(foreach ($entry in $calendar.Entries) {
        [pscustomobject]@{ Id=$entry.Id; OccurrenceId=''; Kind='Meeting'; Revision=$entry.Revision; StartUtc=$entry.StartUtc; EndUtc=$entry.EndUtc }
    })
    $events += @(foreach ($entry in $agenda.Entries) {
        if ($entry.Kind -ceq 'Focus') {
            [pscustomobject]@{ Id=$entry.Id; OccurrenceId=''; Kind='Focus'; Revision='local'; StartUtc=$entry.StartUtc; EndUtc=$entry.EndUtc }
        }
    })
    Invoke-MeetingResponsibilityChecks -Path $Path -Scope Calendar -SourceId $calendar.CalendarId -Events $events -Now $Now
}
