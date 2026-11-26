function Get-TravelAnchor([DateTimeOffset]$instant, [TimeZoneInfo]$zone) {
    $local = [TimeZoneInfo]::ConvertTime($instant, $zone)
    $wall = $local.DateTime
    $ticks = [TimeSpan]::FromMinutes(15).Ticks
    $quarter = $wall.AddTicks(-($wall.Ticks % $ticks))
    return [DateTimeOffset]::new($quarter, $local.Offset).ToUniversalTime()
}

function Get-TravelOffset([double]$minutes) {
    $steps = [Math]::Round($minutes / 15, [MidpointRounding]::AwayFromZero)
    return [Math]::Max(-1440, [Math]::Min(1440, $steps * 15))
}

function Get-TravelRemaining([TimeSpan]$elapsed) {
    return [Math]::Max(0, 12 - $elapsed.TotalSeconds)
}

function Get-ClockSnapshot([DateTimeOffset]$instant, [TimeZoneInfo]$brazil, [TimeZoneInfo]$ireland) {
    $br = [TimeZoneInfo]::ConvertTime($instant, $brazil)
    $ie = [TimeZoneInfo]::ConvertTime($instant, $ireland)
    return @{ Brazil = $br; Ireland = $ie; Difference = $ie.Offset - $br.Offset }
}
