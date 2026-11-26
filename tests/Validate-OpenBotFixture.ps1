$ErrorActionPreference = 'Stop'
$fixture = Get-Content -Raw (Join-Path $PSScriptRoot 'fixtures/openbot-qualification.json') | ConvertFrom-Json
if ($fixture.format -cne 'openbot-policy-oracle-v1') { throw 'Unknown fixture format' }
# Fixture-only policy oracle; not a transport, scheduler or durable store.
function Invoke-FixtureStep($Context, $Step) {
    $key = "$($Step.peer):$($Step.id)"
    $item = $Context.Ledger[$key]
    switch -Exact ($Step.action) {
        'submit' {
            if ($Step.optIn -ne $true) { return 'disabled' }
            if ($null -ne $item) {
                if ($Step.revision -cne $item.Revision) { return 'conflict' }
                return 'duplicate'
            }
            $Context.Ledger[$key] = @{ Revision = $Step.revision; Status = 'queued' }
            $Context.Submissions++
            return 'queued'
        }
        'restart' {
            $saved = ConvertTo-Json -Depth 5 -Compress -InputObject $Context.Ledger | ConvertFrom-Json
            $Context.Ledger = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
            foreach ($property in $saved.PSObject.Properties) {
                $Context.Ledger[$property.Name] = $property.Value
            }
            return 'reopened'
        }
        default {
            if ($Step.action -cnotin @('poll','timeout','approval','cancel','result')) {
                throw "Unknown operation: $($Step.action)"
            }
            if ($null -eq $item) { return 'not-found' }
            switch -Exact ($Step.action) {
                'poll' { return $item.Status }
                'approval' { return 'operator-only' }
                'cancel' { return 'unsupported' }
                'timeout' {
                    if ($item.Status -eq 'completed') { return 'terminal' }
                    $item.Status = 'unknown'
                    return 'unknown'
                }
                'result' {
                    if ($item.Status -eq 'completed') { return 'terminal' }
                    if ($Step.revision -cne $item.Revision) { return 'stale' }
                    if ($Step.result -isnot [string] -or [string]::IsNullOrWhiteSpace($Step.result) -or $Step.result.Length -gt 1024) { return 'invalid-result' }
                    $item.Status = 'completed'
                    return 'completed'
                }
            }
        }
    }
}
foreach ($scenario in $fixture.scenarios) {
    if ($scenario.steps.Count -ne $scenario.expected.Count) { throw "Invalid expectations for $($scenario.name)" }
    $ledger = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $context = @{ Ledger = $ledger; Submissions = 0 }
    for ($i = 0; $i -lt $scenario.steps.Count; $i++) {
        $actual = Invoke-FixtureStep $context $scenario.steps[$i]
        if ($actual -cne $scenario.expected[$i]) { throw "$($scenario.name) step ${i}: expected $($scenario.expected[$i]), got $actual" }
    }
    if ($context.Submissions -ne $scenario.submissions) { throw "$($scenario.name): wrong submission count" }
    Write-Host "OK: $($scenario.name)"
}
Write-Host 'OpenBot fixture oracle passed. No live integration was exercised.'
