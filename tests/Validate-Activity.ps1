$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot) 'ResponsibilityStore.ps1')
function Assert-True($condition, [string]$message) { if (-not $condition) { throw $message } }
$folder = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
$path = Join-Path $folder 'activity.json'
try {
    $now = [DateTimeOffset]::Parse('2026-12-01T12:00:00Z')
    $meeting = @{ Id = 'meeting'; OccurrenceId = 'day1'; StartUtc = '2026-12-01T14:00:00Z'; EndUtc = '2026-12-01T15:00:00Z'; Revision = 'v1'; Kind = 'Meeting' }
    $touch = @{ Id = 'touch'; StartUtc = '2026-12-01T12:00:00-03:00'; EndUtc = '2026-12-01T13:00:00-03:00'; Revision = 'other'; Kind = 'Focus' }
    $overlap = @{ Id = 'overlap'; StartUtc = '2026-12-01T11:30:00-03:00'; EndUtc = '2026-12-01T12:30:00-03:00'; Revision = 'other'; Kind = 'Focus' }
    $r = New-MeetingResponsibility $path 'Planning' 'Fixture-A' 'meeting' 'day1' 'Calendar'
    $same = New-MeetingResponsibility $path 'Planning' 'Fixture-A' 'meeting' 'day1' 'Calendar'
    Assert-True ($r.Id -ceq $same.Id) 'ID changed for a repeated watch.'
    Assert-True (@(Invoke-MeetingResponsibilityChecks $path Calendar Fixture-A @($meeting,$touch) $now).Count -eq 0) 'Boundary-touch incorrectly overlapped.'
    Assert-True (@(Invoke-MeetingResponsibilityChecks $path Calendar Fixture-B @($meeting,$overlap) $now).Count -eq 0) 'An unapproved source generated an alert.'
    $first = Invoke-MeetingResponsibilityChecks $path Calendar Fixture-A @($meeting,$overlap,$touch) $now
    Assert-True ($first.IsAlert -and $first.Summary -eq 'Meeting overlaps 1 other agenda item(s).') 'UTC overlap calculation was incorrect.'
    $restartCode = ". '" + (Join-Path (Split-Path $PSScriptRoot) 'ResponsibilityStore.ps1') + "'; if (@((Read-ResponsibilityStore '" + $path + "').Runs).Count -ne 1) { exit 9 }"
    $snapshotJson = ConvertTo-Json -InputObject @($meeting,$overlap) -Compress
    $restartCode += "; if (@(Invoke-MeetingResponsibilityChecks '" + $path + "' Calendar Fixture-A (ConvertFrom-Json '" +
        $snapshotJson + "') ([DateTimeOffset]::Parse('2026-12-01T12:00:00Z'))).Count -ne 0) { exit 10 }"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($restartCode))
    & (Join-Path $PSHOME 'powershell.exe') -NoProfile -NonInteractive -EncodedCommand $encoded
    Assert-True ($LASTEXITCODE -eq 0) 'A fresh process could not read the ledger.'
    Assert-True (@(Invoke-MeetingResponsibilityChecks $path Calendar Fixture-A @($meeting,$overlap) $now).Count -eq 0) 'Replay reissued an alert.'
    $run = Add-ResponsibilityRun -Path $path -ResponsibilityId $r.Id -SourceId 'Fixture-A' -Revision 'v1' -Summary 'Working' -Provider 'fixture' -Status Running -RunId 'run-1'
    Set-ResponsibilityPaused $path $r.Id $true
    $meeting.Revision = 'v2'
    Assert-True (@(Invoke-MeetingResponsibilityChecks $path Calendar Fixture-A @($meeting,$overlap) $now).Count -eq 0) 'Paused responsibility still checked.'
    Assert-True (((Read-ResponsibilityStore $path).Runs | Where-Object Id -eq $run.Id).Status -eq 'Running') 'Pause modified an active run.'
    Assert-True ((Set-ResponsibilityRunStatus $path $run.Id RequestCancellation).Status -eq 'CancellationRequested') 'Request falsely confirmed a stop.'
    Assert-True ((Set-ResponsibilityRunStatus $path $run.Id AcknowledgeCancellation).Status -eq 'Stopped') 'Acknowledgement failed.'
    Set-ResponsibilityPaused $path $r.Id $false
    $new = Invoke-MeetingResponsibilityChecks $path Calendar Fixture-A @($meeting,$overlap) $now
    Assert-True ($new.IsAlert -and $new.Id -ne $first.Id) 'A new revision failed to generate a new alert.'
    $meeting.Revision = 'v1'
    Assert-True (@(Invoke-MeetingResponsibilityChecks $path Calendar Fixture-A @($meeting,$overlap) $now).Count -eq 0) 'Older revision emitted a duplicate after a newer revision.'
    $state = Read-ResponsibilityStore $path
    Assert-True ($state.Responsibilities[0].LastRevision -eq 'v2' -and $state.Responsibilities[0].LastCheckedUtc) 'Checkpoint not persisted.'
    [IO.File]::WriteAllText($path, '{"Version":99,"Responsibilities":[],"Runs":[]}')
    try { $null = New-MeetingResponsibility $path 'Cannot write' 'offline' 'new'; throw 'Expected bad file rejection.' }
    catch { Assert-True ($_.Exception.Message -like 'Invalid Activity file*') 'Unexpected corruption behavior.' }
    Assert-True (([IO.File]::ReadAllText($path)).Contains('"Version":99')) 'Damaged file was overwritten.'
    Write-Host 'OK: Activity stability, scopes, UTC boundaries, restart dedupe, and stop acknowledgement'
} finally {
    if ([IO.Directory]::Exists($folder)) {
        foreach ($file in [IO.Directory]::GetFiles($folder)) { [IO.File]::Delete($file) }
        [IO.Directory]::Delete($folder)
    }
}
