$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\MeetingBrief.ps1')
$fixture = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'fixtures\meeting-brief\selected.json') | ConvertFrom-Json
$now = [DateTimeOffset]::UtcNow

function Assert-Blocked([scriptblock]$Action, [string]$Expected) {
    try { $null = & $Action } catch {
        if ($_.Exception.Message -notlike "*$Expected*") { throw }
        return
    }
    throw "Expected rejection: $Expected"
}

$request = New-JeremiasMeetingBriefRequest -Meeting $fixture.meeting -Notes $fixture.notes -AllowedSourceIds $fixture.allowed -NowUtc $now
if ($request.Preview.Provider -ne 'offline-fixture' -or ($request.Preview.SourceIds -join ',') -ne 'meeting-a,note-a' -or $request.Preview.ToolLimit -ne 0) {
    throw 'Incorrect provider or scope preview.'
}
if ($request.Payload.Sources[1].Text -cne $fixture.notes[0].Text -or $request.Payload.Sources.Count -ne 2) { throw 'Note not preserved as scoped data.' }
$fixtureResponse = @{
    version = 1; runId = $request.Preview.RunId; meetingRevision = '2';
    summary = 'Compare the two draft formats and discuss the short format.'; sourceIds = @('meeting-a', 'note-a')
}
$argsForResult = @{
    Request = $request; Meeting = $fixture.meeting; Notes = $fixture.notes; AllowedSourceIds = $fixture.allowed;
    TokensUsed = 38; ToolsUsed = 0; NowUtc = $now
}
$valid = Complete-JeremiasMeetingBrief @argsForResult -ResultJson ($fixtureResponse | ConvertTo-Json)
if ($valid.Status -ne 'ReviewReady' -or $valid.Citations.Count -ne 2) { throw 'Valid draft rejected.' }

$fixtureResponse.sourceIds = @('meeting-a', 'note-private')
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson ($fixtureResponse | ConvertTo-Json) } 'unauthorized citation'
$fixtureResponse.sourceIds = @('meeting-a', 'note-a')
$fixtureResponse.version = '1'
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson ($fixtureResponse | ConvertTo-Json) } 'versioned response'
$fixtureResponse.version = 1
$resultJson = $fixtureResponse | ConvertTo-Json
$fixture.meeting.Revision = '3'
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'sources changed'
$fixture.meeting.Revision = '2'
$fixture.notes[0].Text = 'New text'
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'sources changed'
$fixture.notes[0].Text = $request.Payload.Sources[1].Text
$argsForResult.AllowedSourceIds = @()
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'sources changed'
$argsForResult.AllowedSourceIds = $fixture.allowed
$argsForResult.NowUtc = $request.Preview.DeadlineUtc
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'deadline'
$argsForResult.NowUtc = $now
$argsForResult.ToolsUsed = 1
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'budget'
$argsForResult.ToolsUsed = 0
$argsForResult.TokensUsed = 513
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'budget'
$argsForResult.TokensUsed = -1
Assert-Blocked { Complete-JeremiasMeetingBrief @argsForResult -ResultJson $resultJson } 'budget'
Assert-Blocked { New-JeremiasMeetingBriefRequest -Meeting $fixture.meeting -Notes $fixture.notes -AllowedSourceIds 'missing' } 'missing or ambiguous'
Write-Host 'OK: meeting brief preview, scoped sources, version, revision, deadline and budgets'
