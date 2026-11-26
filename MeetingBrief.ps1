# Standalone, offline policy for the meeting brief. Does not execute any note,
# provider text, tools or calendar writes. The caller displays Preview first.
function Get-MeetingBriefField($Object, [string]$Name) {
    if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
    if ($null -ne $Object) { return $Object.$Name }
}

function Test-MeetingBriefId($Value) {
    return $Value -is [string] -and $Value -cmatch '\A[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}\z'
}

function Get-MeetingBriefScope($Meeting, [object[]]$Notes, [string[]]$AllowedSourceIds) {
    $meetingId = Get-MeetingBriefField $Meeting 'Id'
    $revision = Get-MeetingBriefField $Meeting 'Revision'
    if (-not (Test-MeetingBriefId $meetingId) -or -not (Test-MeetingBriefId $revision)) { throw 'Missing meeting identity or revision.' }
    if ($AllowedSourceIds.Count -gt 8) { throw 'At most eight notes may be selected.' }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $null = $seen.Add($meetingId)
    $title = Get-MeetingBriefField $Meeting 'Title'
    $text = Get-MeetingBriefField $Meeting 'Text'
    if ($null -eq $text) { $text = '' }
    if ($title -isnot [string] -or $title.Length -gt 160 -or $text -isnot [string] -or $text.Length -gt 2000) { throw 'Invalid or oversized meeting.' }
    $list = @([pscustomobject][ordered]@{ Id = $meetingId; Kind = 'Meeting'; Title = $title; Text = $text })
    foreach ($id in $AllowedSourceIds) {
        if (-not (Test-MeetingBriefId $id) -or -not $seen.Add($id)) { throw 'Invalid or duplicate source ID.' }
        $matches = @($Notes | Where-Object { (Get-MeetingBriefField $_ 'Id') -ceq $id })
        if ($matches.Count -ne 1) { throw 'Selected note missing or ambiguous.' }
        $title = Get-MeetingBriefField $matches[0] 'Title'
        $text = Get-MeetingBriefField $matches[0] 'Text'
        if ($title -isnot [string] -or $title.Length -gt 160 -or $text -isnot [string] -or $text.Length -gt 2000) { throw 'Invalid or oversized note.' }
        $list += [pscustomobject][ordered]@{ Id = $id; Kind = 'Note'; Title = $title; Text = $text }
    }
    $packed = ConvertTo-Json -InputObject $list -Depth 4 -Compress
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $hash = [Convert]::ToBase64String($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($packed))) } finally { $sha.Dispose() }
    [pscustomobject]@{ Sources = $list; Revision = $revision; Digest = $hash }
}

function New-JeremiasMeetingBriefRequest {
    param($Meeting, [object[]]$Notes = @(), [string[]]$AllowedSourceIds = @(),
          [string]$Provider = 'offline-fixture', [DateTimeOffset]$NowUtc = [DateTimeOffset]::UtcNow,
          [ValidateRange(1,120)][int]$TimeoutSeconds = 30, [ValidateRange(1,4096)][int]$TokenLimit = 512)
    if (-not (Test-MeetingBriefId $Provider)) { throw 'Invalid provider identity.' }
    $scope = Get-MeetingBriefScope $Meeting $Notes $AllowedSourceIds
    $runId = [guid]::NewGuid().ToString('N')
    [pscustomobject]@{
        Preview = [pscustomobject]@{ RunId = $runId; Provider = $Provider; SourceIds = @($scope.Sources.Id); DeadlineUtc = $NowUtc.AddSeconds($TimeoutSeconds); ToolLimit = 0; TokenLimit = $TokenLimit }
        Payload = [pscustomobject]@{ Version = 1; RunId = $runId; MeetingRevision = $scope.Revision; Sources = $scope.Sources }
        ScopeDigest = $scope.Digest
    }
}

function Complete-JeremiasMeetingBrief {
    param($Request, [string]$ResultJson, $Meeting, [object[]]$Notes = @(), [string[]]$AllowedSourceIds = @(),
          [int]$ToolsUsed = -1, [int]$TokensUsed = -1, [DateTimeOffset]$NowUtc = [DateTimeOffset]::UtcNow)
    if ($NowUtc -ge $Request.Preview.DeadlineUtc) { throw 'Brief deadline exceeded.' }
    if ($ToolsUsed -ne 0 -or $TokensUsed -lt 0 -or $TokensUsed -gt $Request.Preview.TokenLimit) { throw 'Brief budget missing or exceeded.' }
    $scope = Get-MeetingBriefScope $Meeting $Notes $AllowedSourceIds
    if ($scope.Revision -cne $Request.Payload.MeetingRevision -or $scope.Digest -cne $Request.ScopeDigest) { throw 'Brief sources changed; rerun with the current scope.' }
    if ($ResultJson.Length -gt 8192 -or $ResultJson -notmatch '^\s*\{') { throw 'Invalid brief response envelope.' }
    $result = ConvertFrom-Json -InputObject $ResultJson -ErrorAction Stop
    $properties = @('version', 'runId', 'meetingRevision', 'summary', 'sourceIds')
    if (@($result.PSObject.Properties).Count -ne $properties.Count -or
        @($result.PSObject.Properties.Name | Where-Object { $_ -cnotin $properties }).Count -ne 0 -or
        ($result.version -isnot [int] -and $result.version -isnot [long]) -or $result.version -ne 1 -or
        $result.runId -isnot [string] -or $result.runId -cne $Request.Preview.RunId -or
        $result.meetingRevision -isnot [string] -or $result.meetingRevision -cne $scope.Revision -or
        $result.summary -isnot [string] -or [string]::IsNullOrWhiteSpace($result.summary) -or $result.summary.Length -gt 1500 -or
        $result.sourceIds -isnot [array] -or $result.sourceIds.Count -lt 1 -or $result.sourceIds.Count -gt $scope.Sources.Count) {
        throw 'Brief does not match the versioned response contract.'
    }
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($id in $result.sourceIds) {
        if (-not (Test-MeetingBriefId $id) -or $id -cnotin $scope.Sources.Id -or -not $seen.Add($id)) { throw 'Invalid or unauthorized citation.' }
    }
    if ($scope.Sources[0].Id -cnotin $result.sourceIds) { throw 'The brief must cite the meeting.' }
    [pscustomobject]@{ Status = 'ReviewReady'; Provider = $Request.Preview.Provider; SourceId = $scope.Sources[0].Id; Revision = $scope.Revision; Summary = $result.summary; Citations = [string[]]$result.sourceIds }
}

function Add-JeremiasMeetingBriefToActivity {
    param([string]$Path, [string]$ResponsibilityId, $Request, [string]$ResultJson, $Meeting,
          [object[]]$Notes = @(), [string[]]$AllowedSourceIds = @(), [int]$ToolsUsed = -1, [int]$TokensUsed = -1, [DateTimeOffset]$NowUtc = [DateTimeOffset]::UtcNow)
    $brief = Complete-JeremiasMeetingBrief -Request $Request -ResultJson $ResultJson -Meeting $Meeting -Notes $Notes -AllowedSourceIds $AllowedSourceIds -ToolsUsed $ToolsUsed -TokensUsed $TokensUsed -NowUtc $NowUtc
    $responsibility = @((Read-ResponsibilityStore $Path).Responsibilities | Where-Object Id -CEQ $ResponsibilityId)
    if ($responsibility.Count -ne 1 -or $responsibility[0].MeetingId -cne $brief.SourceId) { throw 'Brief does not belong to this responsibility.' }
    Add-ResponsibilityRun -Path $Path -ResponsibilityId $ResponsibilityId -SourceId $responsibility[0].SourceId -Revision $brief.Revision -Summary $brief.Summary -Provider $brief.Provider -Citations $brief.Citations -Status $brief.Status -RunId $Request.Preview.RunId
}
