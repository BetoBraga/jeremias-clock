$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'ProductivityStore.ps1')

function Assert-Store([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Productivity store regression: $Message" }
}

function Assert-SaveFails([string]$Path, $Data, [string]$Message) {
    $failed = $false
    try {
        Save-ProductivityStore -Path $Path -Data $Data
    } catch {
        $failed = $true
    }
    Assert-Store $failed $Message
}

$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$testFolder = [IO.Directory]::CreateDirectory(
    (Join-Path $tempRoot ('Jeremias-Productivity-' + [Guid]::NewGuid().ToString('N')))
).FullName
$storePath = Join-Path $testFolder 'productivity.json'
$backupPath = "$storePath.bak"
try {
    $empty = Read-ProductivityStore -Path $storePath
    Assert-Store (@($empty.Notes).Count -eq 0 -and @($empty.Entries).Count -eq 0) 'A new store must start empty.'
    Assert-Store ([string]::IsNullOrEmpty($empty.Warning)) 'First launch must not report data corruption.'
    Assert-Store (-not [IO.File]::Exists($storePath)) 'A read must not create a data file.'

    $note = @{
        Id = [Guid]::NewGuid().ToString('D')
        Title = 'S' + [char]0x00E3 + 'o Paulo'
        Text = "Dublin meeting`r`n" + [char]::ConvertFromUtf32(0x1F409)
    }
    $meeting = @{
        Id = [Guid]::NewGuid().ToString('D')
        Title = 'Dublin sync'
        Kind = 'Meeting'
        StartUtc = '2026-11-25T14:00:00.0000000+00:00'
        EndUtc = '2026-11-25T14:30:00.0000000+00:00'
    }
    $focus = $meeting.Clone()
    $focus.Id = [Guid]::NewGuid().ToString('D')
    $focus.Title = 'Writing block'
    $focus.Kind = 'Focus'
    $focus.StartUtc = '2026-11-25T15:00:00.0000000+00:00'
    $focus.EndUtc = '2026-11-25T16:00:00.0000000+00:00'
    $data = @{ Notes = @($note); Entries = @($meeting, $focus) }
    Save-ProductivityStore -Path $storePath -Data $data

    $firstRead = Read-ProductivityStore -Path $storePath
    Assert-Store (@($firstRead.Notes).Count -eq 1 -and @($firstRead.Entries).Count -eq 2) 'All records must survive a reload.'
    Assert-Store ($firstRead.Notes[0].Id -eq $note.Id -and $firstRead.Notes[0].Title -ceq $note.Title -and $firstRead.Notes[0].Text -ceq $note.Text) 'The note must preserve its ID, Unicode and line breaks.'
    foreach ($entry in $data.Entries) {
        $restored = $firstRead.Entries | Where-Object Id -eq $entry.Id
        Assert-Store ($restored.Title -eq $entry.Title -and $restored.Kind -eq $entry.Kind -and $restored.StartUtc -eq $entry.StartUtc -and $restored.EndUtc -eq $entry.EndUtc) 'The agenda must preserve entry kind and UTC interval.'
    }

    $previousHash = (Get-FileHash -LiteralPath $storePath).Hash
    $note.Title = 'Meeting preparation'
    $focus.Title = 'Edited writing block'
    Save-ProductivityStore -Path $storePath -Data $data
    $edited = Read-ProductivityStore -Path $storePath
    Assert-Store ($edited.Notes[0].Id -eq $note.Id -and $edited.Notes[0].Title -eq $note.Title) 'Editing a note must update the existing record.'
    Assert-Store (($edited.Entries | Where-Object Id -eq $focus.Id).Title -eq $focus.Title) 'Editing a focus block must update the existing record.'
    Assert-Store ((Get-FileHash -LiteralPath $backupPath).Hash -eq $previousHash) 'A save must retain the previous valid snapshot.'

    $primaryHash = (Get-FileHash -LiteralPath $storePath).Hash
    $goodBackupHash = (Get-FileHash -LiteralPath $backupPath).Hash
    $validEnd = $focus.EndUtc
    $focus.EndUtc = $focus.StartUtc
    Assert-SaveFails $storePath $data 'A zero-length interval must be rejected.'
    $focus.EndUtc = $validEnd
    Assert-Store ((Get-FileHash -LiteralPath $storePath).Hash -eq $primaryHash) 'Validation failure must preserve the primary snapshot.'
    Assert-Store ((Get-FileHash -LiteralPath $backupPath).Hash -eq $goodBackupHash) 'Validation failure must preserve the backup.'

    # Allow reads but deny replacement while the primary file handle is open.
    $handle = [IO.File]::Open($storePath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $note.Title = 'Attempted edit while locked'
        Assert-SaveFails $storePath $data 'Replacing a locked primary file must fail visibly.'
    } finally {
        $handle.Dispose()
    }
    Assert-Store ((Get-FileHash -LiteralPath $storePath).Hash -eq $primaryHash) 'A failed replacement must leave the primary snapshot intact.'
    Assert-Store ((Get-FileHash -LiteralPath $backupPath).Hash -eq $goodBackupHash) 'A failed replacement must leave the previous backup intact.'

    [IO.File]::WriteAllText($storePath, '{"Notes":')
    $recovered = Read-ProductivityStore -Path $storePath
    Assert-Store (-not [string]::IsNullOrWhiteSpace($recovered.Warning)) 'Recovery must surface a warning.'
    Assert-Store ($recovered.Notes[0].Title -eq $firstRead.Notes[0].Title -and @($recovered.Entries).Count -eq 2) 'Recovery must load the previous valid snapshot.'

    $recovered.Notes[0].Title = 'Recovered and edited'
    Save-ProductivityStore -Path $storePath -Data $recovered
    $reopened = Read-ProductivityStore -Path $storePath
    Assert-Store ($reopened.Notes[0].Title -eq 'Recovered and edited' -and [string]::IsNullOrEmpty($reopened.Warning)) 'Saving recovered data must restore normal reads.'
    Assert-Store ((Get-FileHash -LiteralPath $backupPath).Hash -eq $goodBackupHash) 'Saving after recovery must preserve the good backup.'
} finally {
    # Delete only files immediately inside the uniquely created fixture directory.
    foreach ($fixture in [IO.Directory]::EnumerateFiles($testFolder)) {
        [IO.File]::Delete($fixture)
    }
    [IO.Directory]::Delete($testFolder)
}

Write-Host 'OK: productivity store roundtrip, edits, Unicode, invalid intervals, interrupted save and recovery'
