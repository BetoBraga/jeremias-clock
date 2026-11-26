[CmdletBinding(DefaultParameterSetName='Sync')]
param(
    [Parameter(Mandatory, ParameterSetName='Sync')][string]$CalendarId,
    [Parameter(Mandatory, ParameterSetName='Disconnect')][switch]$Disconnect,
    [string]$CachePath = (Join-Path $env:LOCALAPPDATA 'JeremiasWorldClock.Review\calendar.json')
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'CalendarConnector.ps1')
if ($Disconnect) {
    if (Test-Path -LiteralPath $CachePath) { Remove-Item -LiteralPath $CachePath -ErrorAction Stop }
    Write-Output 'Disconnected. Local calendar cache removed.'
    return
}
if ([string]::IsNullOrWhiteSpace($env:JEREMIAS_CALENDAR_ACCESS_TOKEN)) {
    throw 'Provide a short-lived token with calendar.events.readonly in JEREMIAS_CALENDAR_ACCESS_TOKEN.'
}
$fetch = {
    param($Uri)
    try {
        Invoke-RestMethod -Method Get -Uri $Uri -Headers @{ Authorization = 'Bearer ' + $env:JEREMIAS_CALENDAR_ACCESS_TOKEN } -MaximumRedirection 0 -TimeoutSec 15 -ErrorAction Stop
    } catch {
        # Do not write HTTP exception bodies, headers, or provider payloads to disk.
        $response = $_.Exception.Response
        if ($null -ne $response -and [int]$response.StatusCode -in 401,403,404) {
            $failure = [InvalidOperationException]::new('Calendar access denied or unavailable to this token.')
            $failure.Data['CalendarStatus'] = 'Revoked'
            throw $failure
        }
        throw 'Calendar refresh is unavailable.'
    }
}
$snapshot = Update-JeremiasCalendarCache -Path $CachePath -CalendarId $CalendarId -Fetch $fetch
Write-Output ('Calendar status: {0}. Timed entries cached: {1}.' -f $snapshot.Status, $snapshot.Entries.Count)
if ($snapshot.Status -ne 'Fresh') { exit 1 }
