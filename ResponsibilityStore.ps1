. (Join-Path $PSScriptRoot 'ProductivityStore.ps1')

function Read-ResponsibilityStore([string]$Path) {
    try { $json = [IO.File]::ReadAllText([IO.Path]::GetFullPath($Path)) }
    catch [IO.FileNotFoundException], [IO.DirectoryNotFoundException] {
        return [pscustomobject]@{ Version = 1; Responsibilities = @(); Runs = @() }
    }
    $s = ConvertFrom-Json $json -ErrorAction Stop
    if ($s.Version -ne 1 -or $s.Responsibilities -isnot [array] -or $s.Runs -isnot [array]) {
        throw 'Invalid Activity file; it was not overwritten.'
    }
    $s
}
function Invoke-ActivityTransaction([string]$Path, [scriptblock]$Change) {
    $Path = [IO.Path]::GetFullPath($Path)
    $dir = [IO.Path]::GetDirectoryName($Path)
    $null = [IO.Directory]::CreateDirectory($dir)
    $lock = [IO.File]::Open($Path + '.lock', 'OpenOrCreate', 'ReadWrite', 'None')
    $tmp = Join-Path $dir ('.activity-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        $s = Read-ResponsibilityStore $Path
        $result = & $Change $s
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes((ConvertTo-Json -InputObject $s -Depth 10 -ErrorAction Stop))
        $fs = [IO.File]::Open($tmp, 'CreateNew', 'Write', 'None')
        try { $fs.Write($bytes, 0, $bytes.Length); $fs.Flush($true) } finally { $fs.Dispose() }
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($tmp, $Path, [NullString]::Value) }
        else { [IO.File]::Move($tmp, $Path) }
        $result
    } finally {
        try { [IO.File]::Delete($tmp) } finally { $lock.Dispose() }
    }
}
function New-MeetingResponsibility {
    param([string]$Path, [string]$Title, [string]$SourceId, [string]$MeetingId,
          [string]$OccurrenceId = '', [string]$Scope = 'LocalAgenda')
    if (-not ($Title.Trim() -and $SourceId.Trim() -and $MeetingId.Trim() -and $Scope.Trim())) { throw 'Select a meeting and source.' }
    Invoke-ActivityTransaction $Path {
        param($s)
        $r = $s.Responsibilities | Where-Object {
            $_.Scope -ceq $Scope -and $_.SourceId -ceq $SourceId -and
            $_.MeetingId -ceq $MeetingId -and $_.OccurrenceId -ceq $OccurrenceId
        } | Select-Object -First 1
        if ($r) { return $r }
        $r = [pscustomobject]@{ Id = [guid]::NewGuid().ToString('N'); Title = $Title; Scope = $Scope
            SourceId = $SourceId; MeetingId = $MeetingId; OccurrenceId = $OccurrenceId; Owner = 'This device'
            Paused = $false; LastCheckedUtc = $null; LastRevision = $null }
        $s.Responsibilities += $r
        $r
    }
}
function Set-ResponsibilityPaused([string]$Path, [string]$ResponsibilityId, [bool]$Paused) {
    Invoke-ActivityTransaction $Path {
        param($s)
        $r = $s.Responsibilities | Where-Object Id -CEQ $ResponsibilityId
        if (-not $r) { throw 'Responsibility not found.' }
        $r.Paused = $Paused
    }
}
function New-ActivityRecord($Id, $ResponsibilityId, $SourceId, $Revision, $Summary, $Provider, $Citations, $Status, $IsAlert, $Now) {
    [pscustomobject]@{ Id = $Id; ResponsibilityId = $ResponsibilityId; SourceId = $SourceId
        Revision = $Revision; Summary = $Summary; Provider = $Provider; Citations = @($Citations | Where-Object { $_ })
        Status = $Status; IsAlert = $IsAlert; CreatedUtc = $Now.ToUniversalTime().ToString('o') }
}
function Add-ResponsibilityRun {
    param([string]$Path, [string]$ResponsibilityId, [string]$SourceId, [string]$Revision,
          [string]$Summary, [string]$Provider, [string[]]$Citations = @(),
          [ValidateSet('ReviewReady','Succeeded','Failed','Running')][string]$Status = 'ReviewReady',
          [string]$RunId = [guid]::NewGuid().ToString('N'))
    Invoke-ActivityTransaction $Path {
        param($s)
        $r = $s.Responsibilities | Where-Object Id -CEQ $ResponsibilityId
        if (-not $r -or $r.SourceId -cne $SourceId -or -not $Revision -or -not $RunId) { throw 'Invalid run source or identity.' }
        $run = $s.Runs | Where-Object Id -CEQ $RunId
        if ($run) {
            if ($run.ResponsibilityId -cne $ResponsibilityId -or $run.Revision -cne $Revision -or $run.IsAlert) { throw 'Run ID already in use.' }
            return $run
        }
        if ($r.Paused) { throw 'Future checks are paused.' }
        if ($Status -eq 'Running' -and ($s.Runs | Where-Object { $_.ResponsibilityId -ceq $ResponsibilityId -and $_.Status -in 'Running','CancellationRequested' })) {
            throw 'A run is already active for this responsibility.'
        }
        $run = New-ActivityRecord $RunId $ResponsibilityId $SourceId $Revision $Summary $Provider $Citations $Status $false ([DateTimeOffset]::UtcNow)
        $s.Runs += $run
        $run
    }
}
function Set-ResponsibilityRunStatus {
    param([string]$Path, [string]$RunId,
          [ValidateSet('RequestCancellation','AcknowledgeCancellation','Complete','Fail')][string]$Action)
    $next = @{ RequestCancellation = 'CancellationRequested'; AcknowledgeCancellation = 'Stopped'; Complete = 'Succeeded'; Fail = 'Failed' }[$Action]
    $allowed = @{ RequestCancellation = @('Running'); AcknowledgeCancellation = @('CancellationRequested')
        Complete = @('Running','CancellationRequested'); Fail = @('Running','CancellationRequested') }[$Action]
    Invoke-ActivityTransaction $Path {
        param($s)
        $run = $s.Runs | Where-Object Id -CEQ $RunId
        if (-not $run -or ($run.Status -ne $next -and $run.Status -notin $allowed)) { throw 'Invalid run status transition.' }
        $run.Status = $next
        $run
    }
}
function Invoke-MeetingResponsibilityChecks {
    param([string]$Path, [string]$Scope, [string]$SourceId,
          [AllowEmptyCollection()][object[]]$Events, [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow)
    if (-not [IO.File]::Exists($Path)) { return }
    $snapshot = @(foreach ($e in $Events) {
        if ($e.Kind -cnotin 'Meeting','Focus' -or -not $e.Id -or -not $e.Revision) { continue }
        $start = ConvertTo-ProductivityUtc $e.StartUtc
        $end = ConvertTo-ProductivityUtc $e.EndUtc
        if ($start -ge $end) { throw 'Invalid source time interval.' }
        [pscustomobject]@{ Id = $e.Id; OccurrenceId = [string]$e.OccurrenceId; Kind = $e.Kind
            Revision = [string]$e.Revision; Start = $start; End = $end }
    })
    Invoke-ActivityTransaction $Path {
        param($s)
        foreach ($r in $s.Responsibilities) {
            if ($r.Paused -or $r.Scope -cne $Scope -or $r.SourceId -cne $SourceId) { continue }
            $r.LastCheckedUtc = $Now.ToUniversalTime().ToString('o')
            $m = @($snapshot | Where-Object { $_.Kind -ceq 'Meeting' -and $_.Id -ceq $r.MeetingId -and $_.OccurrenceId -ceq $r.OccurrenceId })
            if ($m.Count -gt 1) { throw 'Duplicate meeting identity.' }
            if ($m.Count -ne 1 -or $m[0].End -le $Now) { continue }
            $m = $m[0]
            $priorAlert = $s.Runs | Where-Object { $_.IsAlert -and $_.ResponsibilityId -ceq $r.Id -and $_.Revision -ceq $m.Revision }
            if ($priorAlert) { continue }
            $r.LastRevision = $m.Revision
            $overlaps = @($snapshot | Where-Object {
                ($_.Id -cne $m.Id -or $_.OccurrenceId -cne $m.OccurrenceId) -and
                ($Scope -cne 'Calendar' -or $_.Kind -ceq 'Focus') -and
                $_.Start -lt $m.End -and $m.Start -lt $_.End
            })
            if (-not $overlaps.Count) { continue }
            $summary = 'Meeting overlaps ' + $overlaps.Count + ' other agenda item(s).'
            $run = New-ActivityRecord ([guid]::NewGuid().ToString('N')) $r.Id $SourceId $m.Revision $summary $Scope @() 'Conflict' $true $Now
            $s.Runs += $run
            $run
        }
    }
}
function Invoke-LocalResponsibilityChecks([string]$Path, [string]$AgendaPath, [DateTimeOffset]$Now = [DateTimeOffset]::UtcNow) {
    if (-not [IO.File]::Exists($Path)) { return }
    $agenda = Read-ProductivityStore $AgendaPath
    if ($agenda.Warning) { throw $agenda.Warning }
    $events = @(foreach ($e in $agenda.Entries) {
        $sha = [Security.Cryptography.SHA256]::Create()
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject @($e.Title,$e.StartUtc,$e.EndUtc) -Compress))
            $revision = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','')
        } finally { $sha.Dispose() }
        [pscustomobject]@{ Id = $e.Id; OccurrenceId = ''; Kind = $e.Kind
            StartUtc = $e.StartUtc; EndUtc = $e.EndUtc; Revision = $revision }
    })
    Invoke-MeetingResponsibilityChecks -Path $Path -Scope 'LocalAgenda' -SourceId 'offline' -Events $events -Now $Now
}
