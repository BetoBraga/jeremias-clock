# Sourced only by the measurement instance. Keep setup and sampling outside the normal launch path.
$measurement = @{
    Process = [Diagnostics.Process]::GetCurrentProcess()
    StartupMs = 0
    BeforeCpu = $null
    IdleTimer = [Diagnostics.Stopwatch]::new()
    Result = $null
}

function Start-IdleSample {
    $measurement.Process.Refresh()
    $measurement.BeforeCpu = $measurement.Process.TotalProcessorTime
    $measurement.IdleTimer.Start()
    $sampleTimer.Interval = [TimeSpan]::FromSeconds($MeasureIdleSeconds)
    $sampleTimer.Start()
}

$sampleTimer = [Windows.Threading.DispatcherTimer]::new()
$sampleTimer.Add_Tick({
    $sampleTimer.Stop()
    if ($null -eq $measurement.BeforeCpu) {
        Start-IdleSample
        return
    }

    $measurement.IdleTimer.Stop()
    $process = $measurement.Process
    $process.Refresh()
    $elapsed = $measurement.IdleTimer.Elapsed.TotalSeconds
    $cpu = ($process.TotalProcessorTime - $measurement.BeforeCpu).TotalSeconds
    $dpi = [Windows.Media.VisualTreeHelper]::GetDpi($window)
    $measurement.Result = [ordered]@{
        StartupMs = [Math]::Round($measurement.StartupMs, 2)
        IdleSeconds = [Math]::Round($elapsed, 3)
        IdleCpuPercent = [Math]::Round(100 * $cpu / ($elapsed * [Environment]::ProcessorCount), 3)
        PrivateMiB = [Math]::Round($process.PrivateMemorySize64 / 1MB, 2)
        WorkingSetMiB = [Math]::Round($process.WorkingSet64 / 1MB, 2)
        WindowDpiScale = $dpi.DpiScaleX
    }
    $window.Close()
})

$window.Add_ContentRendered({
    if ($measurement.StartupMs -gt 0) { return }
    $measurement.StartupMs = 1000 * ([Diagnostics.Stopwatch]::GetTimestamp() - $MeasureStartTick) / [Diagnostics.Stopwatch]::Frequency
    if ($MeasureWarmupSeconds -eq 0) {
        Start-IdleSample
    } else {
        $sampleTimer.Interval = [TimeSpan]::FromSeconds($MeasureWarmupSeconds)
        $sampleTimer.Start()
    }
})
$window.Add_Closed({ $sampleTimer.Stop(); $measurement.Process.Dispose() })
