$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'integrations\openclaw\OpenClawPilot.psm1') -Force

function Assert-Pilot($Expected, $Actual, [string]$Label) {
    if ($Expected -cne $Actual) { throw "$Label failed." }
}

$fixture = @{
    Calls = [Collections.Generic.List[object]]::new()
    Scopes = @('operator.write')
    Methods = @('chat.send', 'chat.history', 'chat.abort')
    Protocol = 4
    SessionId = 'synthetic-session'
    Active = $true
    Status = 'started'
    Fault = @{}
}
$transport = {
    param($method, $params)
    $fixture.Calls.Add(@{ Method = $method; Parameters = $params })
    if ($fixture.Fault[$method]) {
        return @{ ErrorCode = $fixture.Fault[$method]; Detail = 'not-for-display' }
    }
    switch ($method) {
        'fixture.connect' {
            return @{ type = 'hello-ok'; protocol = $fixture.Protocol
                auth = @{ role = 'operator'; scopes = $fixture.Scopes }
                features = @{ methods = $fixture.Methods; events = @('chat') } }
        }
        'chat.send' {
            return @{ runId = $params.idempotencyKey; status = $fixture.Status }
        }
        'chat.history' {
            $ids = if ($fixture.Active) { @($params.inputRunIds[0]) } else { @('unrelated-run') }
            return @{ sessionKey = $params.sessionKey; sessionId = $fixture.SessionId
                messages = @(@{ role = 'assistant'; content = 'opaque transcript' })
                sessionInfo = @{ activeRunIds = $ids } }
        }
        'chat.abort' {
            return @{ aborted = $true; runIds = @($params.runId) }
        }
        default { throw 'Unexpected fixture RPC.' }
    }
}.GetNewClosure()
$now = [DateTimeOffset]::Parse('2026-11-26T10:00:00Z')
function New-FixtureRun {
    New-JeremiasOpenClawBriefRun -Title 'Synthetic planning' -StartUtc ($now.AddHours(1)) -EndUtc ($now.AddHours(1.5)) -DeadlineUtc ($now.AddSeconds(40)) -Now $now -Excerpts @(
        @{ sourceId = 'note-1'; excerpt = 'Synthetic source'; token = 'must-not-leave'; body = 'must-not-leave' }
    )
}
function New-FixtureEvent($Run, $State, $Text = 'Draft. Source: note-1') {
    @{
        type = 'event'; event = 'chat'
        payload = @{
            sessionKey = $Run.SessionKey; runId = $Run.RunId; sessionId = $Run.SessionId; state = $State
            message = @{ role = 'assistant'; content = @(@{ type = 'text'; text = $Text }) }
        }
    }
}
$run = New-FixtureRun
$disabled = New-JeremiasOpenClawPilot -FixtureTransport $transport
Assert-Pilot 'disabled' (Connect-JeremiasOpenClawPilot $disabled) 'Default disabled'
Assert-Pilot 'disabled' (Start-JeremiasOpenClawBriefRun $disabled $run -ConfirmSelectedContext -Now $now) 'Disabled preserves local workflow'
Assert-Pilot 0 $fixture.Calls.Count 'Disabled made no calls'
$pilot = New-JeremiasOpenClawPilot -EnableFixture -FixtureTransport $transport
$fixture.Fault['fixture.connect'] = 'auth-rejected'
Assert-Pilot 'auth-rejected' (Connect-JeremiasOpenClawPilot $pilot) 'Invalid credentials'
Assert-Pilot 'unavailable' (Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now) 'No writes after failed login'
$fixture.Fault.Clear()
$fixture.Protocol = 3
Assert-Pilot 'incompatible' (Connect-JeremiasOpenClawPilot $pilot) 'Protocol downgrade refused'
$fixture.Protocol = 4
$fixture.Scopes = @('operator.write', 'operator.admin')
Assert-Pilot 'over-scoped' (Connect-JeremiasOpenClawPilot $pilot) 'Expanded credentials refused'
$fixture.Scopes = @('operator.read')
Assert-Pilot 'incompatible' (Connect-JeremiasOpenClawPilot $pilot) 'Read-only credentials cannot submit'
$fixture.Scopes = @('operator.write')
$fixture.Methods = @('chat.history', 'chat.abort')
Assert-Pilot 'incompatible' (Connect-JeremiasOpenClawPilot $pilot) 'Lack of capability'
$fixture.Methods += 'chat.send'
Assert-Pilot 'ready' (Connect-JeremiasOpenClawPilot $pilot) 'Qualified fixture'
Assert-Pilot 'selection-required' (Start-JeremiasOpenClawBriefRun $pilot $run -Now $now) 'Context confirmation'
Assert-Pilot 'accepted' (Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now) 'Send acknowledgement'
$send = $fixture.Calls[$fixture.Calls.Count - 1].Parameters
Assert-Pilot $false $send.deliver 'No reply delivery'
Assert-Pilot 40000 $send.timeoutMs 'Bounded server deadline'
Assert-Pilot $run.IdempotencyKey $send.idempotencyKey 'Stable submission identity'
Assert-Pilot $false ($send.message -match 'must-not-leave|token|body') 'Extra fields excluded'
Assert-Pilot $true ($send.message -match 'note-1|Synthetic planning') 'Only selected meeting and excerpt'
Assert-Pilot $null $run.Context 'Context not persisted in lifecycle'
$count = $fixture.Calls.Count
Assert-Pilot 'accepted' (Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now) 'No duplicate sends'
Assert-Pilot $count $fixture.Calls.Count 'No second transport call'
$foreign = New-FixtureEvent $run 'final'
$foreign.payload.runId = 'somebody-else'
Assert-Pilot 'accepted' (Receive-JeremiasOpenClawBriefEvent $pilot $run $foreign -Now $now) 'Other run ignored'
Assert-Pilot 'active' (Receive-JeremiasOpenClawBriefEvent $pilot $run (New-FixtureEvent $run 'delta') -Now $now) 'Delta lifecycle'
Assert-Pilot $null $run.Result 'No delta becomes a result'
Assert-Pilot 'review-required' (Receive-JeremiasOpenClawBriefEvent $pilot $run (New-FixtureEvent $run 'final') -Now $now) 'Final draft only'
Assert-Pilot 'Draft. Source: note-1' $run.Result 'Draft preserved for review'
Assert-Pilot 'review-required' (Receive-JeremiasOpenClawBriefEvent $pilot $run (New-FixtureEvent $run 'error') -Now $now) 'Terminal state absorbing'

$run = New-FixtureRun
$fixture.Fault['chat.send'] = 'timed-out'
Assert-Pilot 'unknown' (Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now) 'Lost acknowledgement'
$count = $fixture.Calls.Count
Assert-Pilot 'unknown' (Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now) 'Uncertain send cannot repeat'
Assert-Pilot $count $fixture.Calls.Count 'Uncertain send was not repeated'
$fixture.Fault.Clear()
Disconnect-JeremiasOpenClawPilot $pilot $run
Assert-Pilot 'unknown' (Get-JeremiasOpenClawBriefRunState $pilot $run) 'Disconnect does not infer cancellation'
Assert-Pilot 'ready' (Connect-JeremiasOpenClawPilot $pilot) 'Reconnect'
Assert-Pilot 'active' (Get-JeremiasOpenClawBriefRunState $pilot $run) 'Exact-run recovery'
Assert-Pilot 1 $fixture.Calls[$fixture.Calls.Count - 1].Parameters.limit 'Bounded history'
Assert-Pilot 1024 $fixture.Calls[$fixture.Calls.Count - 1].Parameters.maxBytes 'Bounded history bytes'
Assert-Pilot $null $run.Result 'History not stored'
$replacedRun = $run.Clone()
$fixture.SessionId = 'replaced'
Assert-Pilot 'session-replaced' (Stop-JeremiasOpenClawBriefRun $pilot $replacedRun) 'Changed physical session'
Assert-Pilot 'chat.history' $fixture.Calls[$fixture.Calls.Count - 1].Method 'No broad cancellation'
Assert-Pilot 'session-replaced' (Receive-JeremiasOpenClawBriefEvent $pilot $replacedRun (New-FixtureEvent $replacedRun 'final') -Now $now) 'Replaced incarnation cannot supply a draft'
$fixture.SessionId = 'synthetic-session'
$fixture.Active = $false
Assert-Pilot 'unknown' (Get-JeremiasOpenClawBriefRunState $pilot $run) 'Missing exact live run does not prove completion'
$fixture.Active = $true
Assert-Pilot 'cancel-requested' (Stop-JeremiasOpenClawBriefRun $pilot $run) 'Scoped abort acknowledgement'
$abort = $fixture.Calls[$fixture.Calls.Count - 1]
Assert-Pilot 'chat.abort' $abort.Method 'No other abort method'
Assert-Pilot $run.RunId $abort.Parameters.runId 'Exact abort run'
Assert-Pilot $run.SessionKey $abort.Parameters.sessionKey 'Exact abort session'
Assert-Pilot 'synthetic-session' $abort.Parameters.sessionId 'Physical incarnation fence'
Assert-Pilot 'cancelled' (Receive-JeremiasOpenClawBriefEvent $pilot $run (New-FixtureEvent $run 'aborted') -Now $now) 'Confirmed terminal cancellation'

$run = New-FixtureRun
Assert-Pilot 'not-sent' (Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now ($now.AddSeconds(41))) 'Expired local request'
Assert-Pilot $null $run.Context 'Expired selected context discarded'
$run = New-FixtureRun
$null = Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now
Assert-Pilot 'expired' (Receive-JeremiasOpenClawBriefEvent $pilot $run (New-FixtureEvent $run 'final') -Now ($now.AddSeconds(41))) 'Late final result'
Assert-Pilot $null $run.Result 'No late draft'
$run = New-FixtureRun
$null = Start-JeremiasOpenClawBriefRun $pilot $run -ConfirmSelectedContext -Now $now
Assert-Pilot 'no-brief' (Receive-JeremiasOpenClawBriefEvent $pilot $run (New-FixtureEvent $run 'final' ('z' * 4097)) -Now $now) 'Output size cap'
$invalid = $false
try {
    $null = New-JeremiasOpenClawBriefRun -Title ('x' * 121) -StartUtc ($now.AddHours(1)) -EndUtc ($now.AddHours(2)) -DeadlineUtc ($now.AddSeconds(10)) -Now $now
} catch [ArgumentException] { $invalid = $true }
Assert-Pilot $true $invalid 'Reject oversized title'
Write-Host 'OK: OpenClaw offline fixtures (no Gateway or credentials)'
