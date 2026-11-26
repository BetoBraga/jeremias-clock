param(
    [ValidateRange(1, 20)][int]$Launches = 5,
    [ValidateRange(1, 300)][int]$IdleSeconds = 10,
    [ValidateRange(0, 60)][int]$WarmupSeconds = 5
)

$ErrorActionPreference = 'Stop'
$samples = @()
for ($i = 1; $i -le $Launches; $i++) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $script = Join-Path $PSScriptRoot 'WorldClock.ps1'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $started = [Diagnostics.Stopwatch]::GetTimestamp()
    $info.Arguments = '-NoProfile -STA -ExecutionPolicy Bypass -File "{0}" -Review -MeasureIdleSeconds {1} -MeasureWarmupSeconds {2} -MeasureStartTick {3}' -f $script, $IdleSeconds, $WarmupSeconds, $started
    $child = [Diagnostics.Process]::Start($info)
    try {
        $output = $child.StandardOutput.ReadToEndAsync()
        $errors = $child.StandardError.ReadToEndAsync()
        if (-not $child.WaitForExit(1000 * (30 + $WarmupSeconds + $IdleSeconds))) {
            $child.Kill()
            [void]$child.WaitForExit(5000)
            throw "Launch $i timed out before producing a sample."
        }
        if ($child.ExitCode -ne 0) { throw $errors.GetAwaiter().GetResult() }
        $result = $output.GetAwaiter().GetResult()
        if (-not $result.Trim()) { throw "Launch $i produced no sample. Close any other measurement instance." }
        $samples += $result | ConvertFrom-Json
    } finally {
        $child.Dispose()
    }
}

$sorted = @($samples.StartupMs | Sort-Object)
$p95Index = [int][Math]::Ceiling(0.95 * $sorted.Count) - 1
$weightedCpu = ($samples | ForEach-Object { $_.IdleCpuPercent * $_.IdleSeconds } | Measure-Object -Sum).Sum
$sampleTime = ($samples.IdleSeconds | Measure-Object -Sum).Sum
$windows = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
[ordered]@{
    WindowsBuild = '{0}.{1}' -f $windows.CurrentBuildNumber, $windows.UBR
    LogicalProcessors = [Environment]::ProcessorCount
    WarmupSeconds = $WarmupSeconds
    StartupP95Ms = $sorted[$p95Index]
    MeanIdleCpuPercent = [Math]::Round($weightedCpu / $sampleTime, 3)
    Samples = $samples
} | ConvertTo-Json -Depth 4
