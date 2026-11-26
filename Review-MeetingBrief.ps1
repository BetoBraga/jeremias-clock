# Review the synthetic brief workflow only, without calendar access or a model.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MeetingBrief.ps1')
$fixture = Get-Content -Raw -Encoding UTF8 (Join-Path $PSScriptRoot 'tests\fixtures\meeting-brief\selected.json') | ConvertFrom-Json
$scope = @{ Meeting = $fixture.meeting; Notes = $fixture.notes; AllowedSourceIds = $fixture.allowed }
$request = New-JeremiasMeetingBriefRequest @scope -TimeoutSeconds 120
$preview = $request.Preview
Write-Host "Provider: $($preview.Provider) (synthetic; local only)"
Write-Host "Sources: $($preview.SourceIds -join ', ')"
Write-Host "Budget: $($preview.TokenLimit) tokens, $($preview.ToolLimit) tools"
Write-Host "Deadline (UTC): $($preview.DeadlineUtc.UtcDateTime.ToString('u'))"
if ((Read-Host 'Dispatch this fixture? [y/N]') -cne 'y') { Write-Host 'Not dispatched.'; return }
if ([DateTimeOffset]::UtcNow -ge $preview.DeadlineUtc) { throw 'Brief deadline exceeded before dispatch.' }
$response = ConvertTo-Json -InputObject @{
    version = 1
    runId = $preview.RunId
    meetingRevision = $request.Payload.MeetingRevision
    summary = 'Compare the two draft formats and discuss the short format.'
    sourceIds = @('meeting-a', 'note-a')
}
$brief = Complete-JeremiasMeetingBrief @scope -Request $request -ResultJson $response -ToolsUsed 0 -TokensUsed 0
Write-Host "Status: $($brief.Status)"
Write-Host "Summary: $($brief.Summary)"
Write-Host "Citations: $($brief.Citations -join ', ')"
