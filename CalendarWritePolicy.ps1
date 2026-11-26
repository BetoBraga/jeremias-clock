# Offline reference policy. No provider, UI, credentials, or network are bound here.
function Get-JeremiasCalendarMoveKey {
    param([Parameter(Mandatory)]$Proposal)
    $parts = @()
    foreach ($name in @('ProposalId','Provider','AccountId','CalendarId','EventId','Revision','StartUtc','EndUtc')) {
        $v = $Proposal.$name
        if ($v -isnot [string] -or [string]::IsNullOrWhiteSpace($v) -or $v.Length -gt 1024) { throw "Invalid proposal field: $name" }
        $parts += $v
    }
    $s = [DateTimeOffset]::MinValue; $e = [DateTimeOffset]::MinValue
    if (-not $Proposal.StartUtc.EndsWith('Z') -or -not $Proposal.EndUtc.EndsWith('Z') -or
        -not [DateTimeOffset]::TryParseExact($Proposal.StartUtc, "yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$s) -or
        -not [DateTimeOffset]::TryParseExact($Proposal.EndUtc, "yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$e) -or $e -le $s) { throw 'Expected a positive interval with UTC timestamps.' }
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $encoded = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $parts -Compress))
        return [BitConverter]::ToString($sha.ComputeHash($encoded)).Replace('-','').ToLowerInvariant()
    } finally { $sha.Dispose() }
}

function Save-JeremiasCalendarWriteState {
    param([string]$Path, [string]$Key, [string]$Status)
    $temp = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
    $stream = $null
    try {
        $stream = [IO.File]::Open($temp, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @{ Version=1; Key=$Key; Status=$Status } -Compress))
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
        $stream.Dispose(); $stream = $null
        if ([IO.File]::Exists($Path)) {
            $backup = "$temp.previous"
            [IO.File]::Replace($temp, $Path, $backup)
            [IO.File]::Delete($backup)
        }
        else { [IO.File]::Move($temp, $Path) }
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
}

function Invoke-JeremiasApprovedCalendarMove {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Proposal,
        $Approval,
        [Parameter(Mandatory)][string]$JournalDirectory,
        [Parameter(Mandatory)][scriptblock]$ReadCurrent,
        [Parameter(Mandatory)][scriptblock]$Submit,
        [Parameter(Mandatory)][scriptblock]$Reconcile,
        [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow
    )
    $key = Get-JeremiasCalendarMoveKey $Proposal
    if ($null -eq $Approval -or $Approval.Decision -cne 'Approved' -or $Approval.ProposalKey -cne $key -or $Approval.AccountId -cne $Proposal.AccountId) { return 'NotApproved' }
    $approvedAt = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParse([string]$Approval.ApprovedAtUtc,[ref]$approvedAt) -or $approvedAt -gt $Now) { return 'NotApproved' }

    $null = [IO.Directory]::CreateDirectory($JournalDirectory)
    $path = Join-Path $JournalDirectory "$key.json"
    try { $lock = [IO.File]::Open("$path.lock", [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch [IO.IOException] { return 'BusyOrUnavailable' }
    try {
        if ([IO.File]::Exists($path)) {
            try { $record = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($path)) -ErrorAction Stop }
            catch { return 'JournalUnusable' }
            if ($record.Version -ne 1 -or $record.Key -cne $key) { return 'JournalUnusable' }
            if ($record.Status -cin @('Applied','Rejected')) { return $record.Status }
            if ($record.Status -cne 'Pending') { return 'JournalUnusable' }
            # A Pending record can mean a crash before or after the write.
            # Reconciliation is read-only. Never submit again for this key.
            try { $receipt = & $Reconcile $Proposal $key }
            catch { return 'Uncertain' }
        } else {
            if ($Now -ge $approvedAt.AddMinutes(10)) { return 'ApprovalExpired' }
            try { $current = & $ReadCurrent $Proposal }
            catch { return 'CurrentStateUnavailable' }
            if ($current.CanWrite -isnot [bool] -or -not $current.CanWrite -or
                $current.Provider -cne $Proposal.Provider -or $current.AccountId -cne $Proposal.AccountId -or
                $current.CalendarId -cne $Proposal.CalendarId -or $current.EventId -cne $Proposal.EventId) { return 'PermissionOrTargetChanged' }
            if ($current.Revision -cne $Proposal.Revision) { return 'StaleRevision' }
            Save-JeremiasCalendarWriteState $path $key 'Pending'
            # The adapter MUST check authorization and enforce the expected revision atomically at mutation time.
            try { $receipt = & $Submit $Proposal $key }
            catch { return 'Uncertain' }
        }
        if ($null -eq $receipt -or $receipt.Key -cne $key -or $receipt.Status -cnotin @('Applied','Rejected')) { return 'Uncertain' }
        Save-JeremiasCalendarWriteState $path $key $receipt.Status
        return $receipt.Status
    } finally { $lock.Dispose() }
}
