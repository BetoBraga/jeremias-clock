$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'CalendarWritePolicy.ps1')
$now = [DateTimeOffset]::Parse('2026-11-26T12:00:00Z')
$p = @{ ProposalId='p1';Provider='fake';AccountId='test-only';CalendarId='calendar';EventId='ev';Revision='v2';StartUtc='2026-11-27T14:00:00Z';EndUtc='2026-11-27T14:30:00Z' }
$key=Get-JeremiasCalendarMoveKey $p
$a=@{ Decision='Approved';ProposalKey=$key;AccountId='test-only';ApprovedAtUtc='2026-11-26T11:58:00Z' }
$root=Join-Path ([IO.Path]::GetTempPath()) "Jeremias-write-test-$([guid]::NewGuid().ToString('N'))"
$current=$p.Clone();$current.CanWrite=$true
$probe={param($proposal) $current}
$stats=@{ Writes=0;Reads=0 }
$submit={param($proposal,$key) $stats.Writes++; @{Key=$key;Status='Applied'} }
$reconcile={param($proposal,$key) $stats.Reads++; @{Key=$key;Status='Applied'} }
function Check($label,$expected,$actual) {
    if ($expected -cne $actual) { throw "$label expected '$expected' but got '$actual'" }
}
function Invoke-TestMove($proposal=$p,$approval=$a,$writer=$submit,$reader=$reconcile,$when=$now){
    Invoke-JeremiasApprovedCalendarMove -Proposal $proposal -Approval $approval -JournalDirectory $root -ReadCurrent $probe -Submit $writer -Reconcile $reader -Now $when
}
$declined=$a.Clone();$declined.Decision='Declined'
Check 'decline' 'NotApproved' (Invoke-TestMove $p $declined)
$tampered=$p.Clone();$tampered.EndUtc='2026-11-27T15:00:00Z'
Check 'scope binding' 'NotApproved' (Invoke-TestMove $tampered)
$current.AccountId='different'
Check 'wrong account' 'PermissionOrTargetChanged' (Invoke-TestMove)
$current.AccountId=$p.AccountId;$current.CanWrite=$false
Check 'revoked permission' 'PermissionOrTargetChanged' (Invoke-TestMove)
$current.CanWrite=$true;$current.Revision='v3'
Check 'stale source' 'StaleRevision' (Invoke-TestMove)
$current.Revision=$p.Revision
Check 'expired decision' 'ApprovalExpired' (Invoke-TestMove -when $now.AddMinutes(20))
Check 'no early writes' 0 $stats.Writes
Check 'valid write' 'Applied' (Invoke-TestMove)
Check 'duplicate' 'Applied' (Invoke-TestMove)
Check 'one submit' 1 $stats.Writes
$p2=$p.Clone();$p2.ProposalId='p2';$a2=$a.Clone();$a2.ProposalKey=Get-JeremiasCalendarMoveKey $p2
$timeoutAfterWrite={param($proposal,$key) $stats.Writes++; throw 'response lost' }
$unknown={param($proposal,$key) $stats.Reads++; @{Key=$key;Status='Unknown'} }
Check 'lost response' 'Uncertain' (Invoke-TestMove $p2 $a2 $timeoutAfterWrite)
Check 'restart/read not conclusive' 'Uncertain' (Invoke-TestMove $p2 $a2 $submit $unknown)
Check 'read confirms' 'Applied' (Invoke-TestMove $p2 $a2)
Check 'no second submit' 2 $stats.Writes
Check 'two reconciliations' 2 $stats.Reads
$p3=$p.Clone();$p3.ProposalId='p3';$a3=$a.Clone();$a3.ProposalKey=Get-JeremiasCalendarMoveKey $p3
$wrongReceipt={param($proposal,$key) $stats.Writes++; @{Key='other';Status='Applied'} }
Check 'mismatched receipt' 'Uncertain' (Invoke-TestMove $p3 $a3 $wrongReceipt)
$bad = Join-Path $root ($a3.ProposalKey + '.json')
[IO.File]::WriteAllText($bad,'not JSON')
Check 'corrupt journal blocks all retries' 'JournalUnusable' (Invoke-TestMove $p3 $a3)
Check 'no writes after corrupt state' 3 $stats.Writes
Write-Host 'OK: confirmed-calendar policy, scope, revocation, revision, timeout, journal recovery boundary and replay (fixture only)'
