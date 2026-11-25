$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$mutex = [System.Threading.Mutex]::new($false, 'Local\JeremiasWorldClock')
if (-not $mutex.WaitOne(0)) { $mutex.Dispose(); return }
try {
$root = $PSScriptRoot
$bridgeAvailable = $false
try { Add-Type -Path (Join-Path $root 'WindowBridge.cs'); $bridgeAvailable = $true } catch { $bridgeAvailable = $false }
$stateDir = Join-Path $env:LOCALAPPDATA 'JeremiasWorldClock'
$null = New-Item -ItemType Directory -Force -Path $stateDir
$statePath = Join-Path $stateDir 'settings.json'
$startupPath = Join-Path ([Environment]::GetFolderPath('Startup')) 'Jeremias World Clock.lnk'
$brZone = [TimeZoneInfo]::FindSystemTimeZoneById('E. South America Standard Time')
$ieZone = [TimeZoneInfo]::FindSystemTimeZoneById('GMT Standard Time')
$culture = [Globalization.CultureInfo]::GetCultureInfo('en-GB')
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Jeremias World Clock" Width="440" Height="322" MinWidth="264" MinHeight="193.2" MaxWidth="1100" MaxHeight="805" WindowStyle="None" ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent" ShowInTaskbar="False" ShowActivated="False" WindowStartupLocation="Manual" FontFamily="Segoe UI" UseLayoutRounding="True" SnapsToDevicePixels="True">
 <Window.Resources>
  <Style TargetType="Button">
   <Setter Property="FontSize" Value="19"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Foreground" Value="#A3ACA6"/><Setter Property="Background" Value="#252B29"/><Setter Property="Cursor" Value="Hand"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="0"/><Setter Property="Focusable" Value="False"/>
   <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="surface" CornerRadius="7" Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="surface" Property="Background" Value="#3C4940"/><Setter Property="Foreground" Value="#D9F3D4"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
  </Style>
 </Window.Resources>
 <Viewbox Stretch="Uniform">
 <Canvas Width="440" Height="322">
  <Border Canvas.Left="8" Canvas.Top="74" Width="424" Height="240" CornerRadius="23" Background="#141719" BorderBrush="#3B4440" BorderThickness="1.5"/>
  <Border Canvas.Left="20" Canvas.Top="115" Width="196" Height="99" CornerRadius="14" Background="#212626" BorderBrush="#39433E" BorderThickness="1"/>
  <Border Canvas.Left="224" Canvas.Top="115" Width="196" Height="99" CornerRadius="14" Background="#212626" BorderBrush="#39433E" BorderThickness="1"/>
  <TextBlock Canvas.Left="24" Canvas.Top="86" Text="JEREMIAS" FontSize="12" FontWeight="Bold" Foreground="#D7DFDA"/>
  <TextBlock Canvas.Left="24" Canvas.Top="100" Text="WORLD CLOCK" FontSize="9" FontWeight="SemiBold" Foreground="#82C778"/>
  <Image x:Name="Mascot" Canvas.Left="170" Canvas.Top="1" Width="100" Height="104" Stretch="Uniform" IsHitTestVisible="False" RenderOptions.BitmapScalingMode="HighQuality"/>
  <Button x:Name="LockBtn" Canvas.Left="333" Canvas.Top="84" Width="26" Height="25" Content="&#x21F1;" ToolTip="Lock position"/>
  <Button x:Name="Pin" Canvas.Left="362" Canvas.Top="84" Width="26" Height="25" Content="&#x25C7;" ToolTip="Always on top"/>
  <Button x:Name="CloseBtn" Canvas.Left="391" Canvas.Top="84" Width="26" Height="25" Content="&#x00D7;" ToolTip="Close"/>
  <Ellipse Canvas.Left="32" Canvas.Top="129" Width="7" Height="7" Fill="#83CF6E"/>
  <TextBlock Canvas.Left="45" Canvas.Top="124" Text="BRAZIL" FontSize="12" FontWeight="Bold" Foreground="#D8E6D8"/>
  <TextBlock Canvas.Right="237" Canvas.Top="125" Text="São Paulo" FontSize="11" Foreground="#A3ACA6"/>
  <TextBlock x:Name="BrTime" Canvas.Left="31" Canvas.Top="141" FontFamily="Consolas" FontWeight="Bold" FontSize="37" Foreground="#F2F5F0" Text="00:00"/>
  <TextBlock x:Name="BrSeconds" Canvas.Left="158" Canvas.Top="159" FontFamily="Consolas" FontSize="16" Foreground="#82C778" Text=":00"/>
  <TextBlock x:Name="BrDate" Canvas.Left="32" Canvas.Top="188" FontSize="11" Foreground="#A3ACA6"/>
  <TextBlock x:Name="BrOffset" Canvas.Right="237" Canvas.Top="188" FontSize="11" Foreground="#82C778"/>
  <Ellipse Canvas.Left="236" Canvas.Top="129" Width="7" Height="7" Fill="#83CF6E"/>
  <TextBlock Canvas.Left="249" Canvas.Top="124" Text="IRELAND" FontSize="12" FontWeight="Bold" Foreground="#D8E6D8"/>
  <TextBlock Canvas.Right="31" Canvas.Top="125" Text="Dublin" FontSize="11" Foreground="#A3ACA6"/>
  <TextBlock x:Name="IeTime" Canvas.Left="235" Canvas.Top="141" FontFamily="Consolas" FontWeight="Bold" FontSize="37" Foreground="#F2F5F0" Text="00:00"/>
  <TextBlock x:Name="IeSeconds" Canvas.Left="362" Canvas.Top="159" FontFamily="Consolas" FontSize="16" Foreground="#82C778" Text=":00"/>
  <TextBlock x:Name="IeDate" Canvas.Left="236" Canvas.Top="188" FontSize="11" Foreground="#A3ACA6"/>
  <TextBlock x:Name="IeOffset" Canvas.Right="31" Canvas.Top="188" FontSize="11" Foreground="#82C778"/>
  <Ellipse Canvas.Left="25" Canvas.Top="226" Width="6" Height="6" Fill="#82C778"/>
  <TextBlock x:Name="TravelStatus" Canvas.Left="24" Canvas.Top="246" FontSize="10" FontWeight="SemiBold" Foreground="#82C778" Text="TIME TRAVEL · drag to preview"/>
  <Button x:Name="NowBtn" Canvas.Left="356" Canvas.Top="240" Width="60" Height="22" FontSize="11" Content="Now" ToolTip="Return to live time"/>
  <Button x:Name="MinusHour" Canvas.Left="24" Canvas.Top="266" Width="31" Height="22" FontSize="11" Content="-1h" ToolTip="Go back one hour"/>
  <Slider x:Name="TravelSlider" Canvas.Left="64" Canvas.Top="265" Width="311" Height="24" Minimum="-1440" Maximum="1440" Value="0" TickFrequency="15" IsSnapToTickEnabled="True" SmallChange="15" LargeChange="60" IsMoveToPointEnabled="True" Cursor="Hand" ToolTip="Drag: -24h to +24h, in 15-minute steps">
   <Slider.Template><ControlTemplate TargetType="Slider"><Grid Background="Transparent">
    <Border Height="5" Background="#35433B" CornerRadius="2.5" VerticalAlignment="Center" Margin="6,0"/>
    <Border Width="2" Height="11" Background="#83CF6E" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    <Track x:Name="PART_Track" Orientation="Horizontal" Minimum="{TemplateBinding Minimum}" Maximum="{TemplateBinding Maximum}" Value="{Binding Value, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay}">
     <Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Focusable="False" Background="Transparent" Opacity="0"/></Track.DecreaseRepeatButton>
     <Track.Thumb><Thumb Width="15" Height="22"><Thumb.Template><ControlTemplate TargetType="Thumb"><Grid Background="Transparent"><Border Width="13" Height="17" CornerRadius="5" Background="#82C778" BorderBrush="#BDE8B4" BorderThickness="1"/><Border Width="2" Height="7" Background="#324C36" CornerRadius="1"/></Grid></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
     <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Focusable="False" Background="Transparent" Opacity="0"/></Track.IncreaseRepeatButton>
    </Track>
   </Grid></ControlTemplate></Slider.Template>
  </Slider>
  <Button x:Name="PlusHour" Canvas.Left="385" Canvas.Top="266" Width="31" Height="22" FontSize="11" Content="+1h" ToolTip="Go forward one hour"/>
  <TextBlock x:Name="PetStatus" Canvas.Left="24" Canvas.Top="295" FontSize="10" Foreground="#A3ACA6" Text="Jeremias · local animation"/>
  <TextBlock Canvas.Right="44" Canvas.Top="295" FontSize="9" Foreground="#75827B" Text="-24h  /  +24h"/>
  <TextBlock x:Name="Difference" Canvas.Left="37" Canvas.Top="222" FontSize="11" FontWeight="SemiBold" Foreground="#B8D9B3"/>
  <TextBlock x:Name="Season" Canvas.Right="42" Canvas.Top="222" FontSize="11" Foreground="#A3ACA6"/>
  <Thumb x:Name="ResizeGrip" Canvas.Left="399" Canvas.Top="289" Width="24" Height="22" Cursor="SizeNWSE" ToolTip="Drag to resize">
   <Thumb.Template><ControlTemplate TargetType="Thumb">
    <Border Background="Transparent" CornerRadius="4">
     <Grid Width="16" Height="16" HorizontalAlignment="Center" VerticalAlignment="Center">
      <Path Data="M 3,14 L 14,3 M 8,14 L 14,8 M 13,14 L 14,13" Stroke="#82C778" StrokeThickness="1.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
     </Grid>
    </Border>
   </ControlTemplate></Thumb.Template>
  </Thumb>
 </Canvas>
 </Viewbox>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)
$reader.Close()
$controls = @{}
foreach ($n in 'Mascot','Pin','CloseBtn','BrTime','BrSeconds','BrDate','BrOffset','IeTime','IeSeconds','IeDate','IeOffset','Difference','Season','ResizeGrip','LockBtn','TravelSlider','TravelStatus','NowBtn','MinusHour','PlusHour','PetStatus') { $controls[$n] = $window.FindName($n) }
function Load-Bitmap([string]$name) {
    $bitmap = New-Object Windows.Media.Imaging.BitmapImage
    $bitmap.BeginInit(); $bitmap.CacheOption = 'OnLoad'
    $bitmap.UriSource = [Uri]::new((Join-Path (Join-Path $root 'assets') $name), [UriKind]::Absolute)
    $bitmap.EndInit(); $bitmap.Freeze(); return $bitmap
}
$normal = Load-Bitmap 'jeremias.png'; $blink = Load-Bitmap 'jeremias-blink.png'
$controls.Mascot.Source = $normal
function Format-Offset([TimeSpan]$offset) {
    if ($offset.TotalMinutes -eq 0) { return 'UTC+0' }
    $sign = if ($offset.TotalMinutes -lt 0) { '-' } else { '+' }
    $abs = $offset.Duration()
    if ($abs.Minutes -eq 0) { return ('UTC{0}{1}' -f $sign,$abs.Hours) }
    return ('UTC{0}{1}:{2:00}' -f $sign,$abs.Hours,$abs.Minutes)
}
$travel = @{Active=$false; Anchor=[DateTimeOffset]::UtcNow; Last=[DateTimeOffset]::UtcNow; Suppress=$false; Timeout=12}
$desktop = @{Pin=$true; Locked=$false; Fullscreen=$true; Hidden=$false; Hwnd=[IntPtr]::Zero; PetHandle=[IntPtr]::Zero; PetPid=0; Signature=$null; PairUntil=$null; PairNotice=''; NoticeUntil=[DateTimeOffset]::MinValue; LastDock=''; LastScan=[DateTimeOffset]::MinValue}
function Start-Travel {
    if (-not $travel.Active) {
        $local = [TimeZoneInfo]::ConvertTime([DateTimeOffset]::UtcNow,$brZone)
        $wall = $local.DateTime.AddMinutes(-($local.Minute % 15)).AddSeconds(-$local.Second).AddTicks(-($local.Ticks % [TimeSpan]::TicksPerSecond))
        $travel.Anchor = ([DateTimeOffset]::new($wall,$local.Offset)).ToUniversalTime()
        $travel.Active = $true
    }
    $travel.Last = [DateTimeOffset]::UtcNow
}
function Reset-Travel {
    $travel.Suppress = $true; $travel.Active = $false; $controls.TravelSlider.Value = 0; $travel.Suppress = $false
}
function Update-Clocks {
    $now = [DateTimeOffset]::UtcNow
    if ($travel.Active) {
        if ($controls.TravelSlider.IsMouseCaptureWithin -or ($controls.TravelSlider.IsMouseOver -and [Windows.Input.Mouse]::LeftButton -eq 'Pressed')) { $travel.Last = $now }
        if (($now - $travel.Last).TotalSeconds -ge $travel.Timeout) { Reset-Travel }
    }
    $utc = if ($travel.Active) { $travel.Anchor.AddMinutes($controls.TravelSlider.Value) } else { $now }
    $accent = if ($travel.Active) { '#A1F1A3' } else { '#F2F5F0' }
    $brush = [Windows.Media.BrushConverter]::new().ConvertFromString($accent)
    $controls.BrTime.Foreground = $brush; $controls.IeTime.Foreground = $brush
    if ($travel.Active) {
        $left = [Math]::Max(0,[Math]::Ceiling($travel.Timeout - ($now - $travel.Last).TotalSeconds))
        $controls.TravelStatus.Text = "PREVIEW · resets in ${left}s"
    } else { $controls.TravelStatus.Text = 'TIME TRAVEL · drag to preview' }
    $br = [TimeZoneInfo]::ConvertTime($utc,$brZone)
    $ie = [TimeZoneInfo]::ConvertTime($utc,$ieZone)
    foreach ($pair in @(@{Key='Br';Time=$br},@{Key='Ie';Time=$ie})) {
        $k = $pair.Key; $t = $pair.Time
        $controls[($k+'Time')].Text = $t.ToString('HH:mm',$culture)
        $controls[($k+'Seconds')].Text = $t.ToString(':ss',$culture)
        $controls[($k+'Date')].Text = $t.ToString('ddd, dd/MM',$culture)
        $controls[($k+'Date')].ToolTip = $t.ToString('dddd, dd MMMM yyyy',$culture)
        $controls[($k+'Offset')].Text = Format-Offset $t.Offset
    }
    $d = $ie.Offset - $br.Offset
    $diff = if ($d.Minutes -eq 0) { ('{0:+0;-0;0}h' -f $d.TotalHours) } else { ('{0:+0.##;-0.##;0}h' -f $d.TotalHours) }
    $controls.Difference.Text = "Dublin: $diff vs Brazil"
    $controls.Season.Text = if ($ie.Offset.TotalHours -eq 1) { 'Irish summer time' } elseif ($ie.Offset.TotalHours -eq 0) { 'Irish winter time' } else { 'Irish time updated' }
}
function Update-Pin {
    $controls.Pin.Content = if ($desktop.Pin) { [string][char]0x25C6 } else { [string][char]0x25C7 }
    $controls.Pin.ToolTip = if ($desktop.Pin) { 'Unpin from top' } else { 'Always on top' }
    $controls.LockBtn.Content = if ($desktop.Locked) { [string][char]0x25A3 } else { [string][char]0x21F1 }
    $controls.LockBtn.ToolTip = if ($desktop.Locked) { 'Unlock position' } else { 'Lock position' }
    if (-not $desktop.Hidden) { $window.Topmost = $desktop.Pin }
}
function Save-Settings {
    try { @{Left=$window.Left;Top=$window.Top;Topmost=$desktop.Pin;Width=$window.Width;Locked=$desktop.Locked;Fullscreen=$desktop.Fullscreen;PetSignature=$desktop.Signature} | ConvertTo-Json | Set-Content -Encoding UTF8 $statePath } catch { }
}
function Set-WidgetSize([double]$width) {
    $width = [Math]::Max($window.MinWidth, [Math]::Min($window.MaxWidth, $width))
    $window.Width = $width
    $window.Height = $width * 322.0 / 440.0
}
$work = [System.Windows.SystemParameters]::WorkArea
$window.Left = $work.Right - $window.Width - 14
$window.Top = $work.Bottom - $window.Height - 14
$window.Topmost = $desktop.Pin
if (Test-Path $statePath) {
    try {
        $saved = Get-Content -Raw $statePath | ConvertFrom-Json
        if ($null -ne $saved.Width -and [double]$saved.Width -gt 0) { Set-WidgetSize ([double]$saved.Width) }
        $window.Left = $work.Right - $window.Width - 14
        $window.Top = $work.Bottom - $window.Height - 14
        $vx = [System.Windows.SystemParameters]::VirtualScreenLeft; $vy = [System.Windows.SystemParameters]::VirtualScreenTop
        $vr = $vx + [System.Windows.SystemParameters]::VirtualScreenWidth; $vb = $vy + [System.Windows.SystemParameters]::VirtualScreenHeight
        if ($saved.Left -ge $vx -and $saved.Left -le ($vr-100) -and $saved.Top -ge $vy -and $saved.Top -le ($vb-80)) { $window.Left = $saved.Left; $window.Top = $saved.Top }
        if ($null -ne $saved.Topmost) { $desktop.Pin = [bool]$saved.Topmost }
        if ($null -ne $saved.Locked) { $desktop.Locked = [bool]$saved.Locked }
        if ($null -ne $saved.Fullscreen) { $desktop.Fullscreen = [bool]$saved.Fullscreen }
        if ($null -ne $saved.PetSignature) { $desktop.Signature = $saved.PetSignature }
    } catch { }
}
Update-Pin
$controls.Pin.Add_Click({ $desktop.Pin = -not $desktop.Pin; Update-Pin; Save-Settings })
$controls.LockBtn.Add_Click({ $desktop.Locked = -not $desktop.Locked; Update-Pin; Save-Settings })
$controls.TravelSlider.Add_PreviewMouseLeftButtonDown({ Start-Travel; Update-Clocks })
$controls.TravelSlider.Add_ValueChanged({ if (-not $travel.Suppress) { Start-Travel; Update-Clocks } })
$controls.TravelSlider.Add_PreviewMouseWheel({ param($sender,$e) Start-Travel; $sender.Value = [Math]::Max($sender.Minimum,[Math]::Min($sender.Maximum,$sender.Value + [Math]::Sign($e.Delta)*15)); $e.Handled=$true; Update-Clocks })
$controls.NowBtn.Add_Click({ Reset-Travel; Update-Clocks })
foreach ($clock in @($controls.BrTime,$controls.IeTime,$controls.BrSeconds,$controls.IeSeconds)) {
    $clock.Cursor = [Windows.Input.Cursors]::Hand
    $clock.ToolTip = 'Scroll over the clock to move by 15 minutes'
    $clock.Add_PreviewMouseWheel({ param($sender,$e) Start-Travel; $controls.TravelSlider.Value = [Math]::Max(-1440,[Math]::Min(1440,$controls.TravelSlider.Value + [Math]::Sign($e.Delta)*15)); $e.Handled=$true; Update-Clocks })
}
$controls.MinusHour.Add_Click({ Start-Travel; $controls.TravelSlider.Value = [Math]::Max(-1440,$controls.TravelSlider.Value - 60); Update-Clocks })
$controls.PlusHour.Add_Click({ Start-Travel; $controls.TravelSlider.Value = [Math]::Min(1440,$controls.TravelSlider.Value + 60); Update-Clocks })
$controls.CloseBtn.Add_Click({ $window.Close() })
$window.Add_MouseLeftButtonDown({ param($sender,$e) if ($controls.TravelSlider.IsMouseOver -or $controls.ResizeGrip.IsMouseOver) { return }; if (-not $desktop.Locked -and $e.ChangedButton -eq 'Left') { try { $window.DragMove(); Save-Settings } catch { } } })
# Keep the entire canvas proportional, including text, mascot and controls.
# Use physical screen coordinates to avoid feedback when the grip itself moves.
$resizeState = @{Active=$false; Start=$null; Width=440.0; Matrix=$null}
$controls.ResizeGrip.Add_DragStarted({
    $resizeState.Start = $window.PointToScreen([Windows.Input.Mouse]::GetPosition($window))
    $resizeState.Matrix = [Windows.PresentationSource]::FromVisual($window).CompositionTarget.TransformFromDevice
    $resizeState.Width = $window.Width
    $resizeState.Active = $true
})
$controls.ResizeGrip.Add_DragDelta({
    if (-not $resizeState.Active) { return }
    $current = $window.PointToScreen([Windows.Input.Mouse]::GetPosition($window))
    $pixels = [Windows.Vector]::new(($current.X - $resizeState.Start.X), ($current.Y - $resizeState.Start.Y))
    $delta = $resizeState.Matrix.Transform($pixels)
    $ratio = 322.0 / 440.0
    $change = ($delta.X + $ratio * $delta.Y) / (1.0 + $ratio * $ratio)
    Set-WidgetSize ($resizeState.Width + $change)
})
$controls.ResizeGrip.Add_DragCompleted({ $resizeState.Active = $false; Save-Settings })
function Show-PetNotice([string]$message) { $desktop.PairNotice = $message; $desktop.NoticeUntil = [DateTimeOffset]::UtcNow.AddSeconds(7) }
function Update-Desktop {
    if (-not $bridgeAvailable) { $controls.PetStatus.Text = 'Local mode · Win32 unavailable'; return }
    if ($desktop.Hwnd -eq [IntPtr]::Zero) { return }
    $now = [DateTimeOffset]::UtcNow
    if ($null -ne $desktop.PairUntil) {
        $remaining = [Math]::Ceiling(($desktop.PairUntil - $now).TotalSeconds)
        if ($remaining -gt 0) { $controls.PetStatus.Text = "Point at the ChatGPT pet: ${remaining}s" }
        else {
            $desktop.PairUntil = $null
            $picked = [Jeremias.WindowBridge]::UnderCursor()
            if ($null -ne $picked) {
                $desktop.Signature = @{Process=$picked.Process; ClassName=$picked.ClassName; Title=$picked.Title}
                $desktop.PetHandle=$picked.Handle; $desktop.PetPid=$picked.Pid; $desktop.LastDock=''; Save-Settings
                Show-PetNotice 'Pet selected · experimental'
            } else { Show-PetNotice 'Pet not found · try again' }
        }
    }
    $pet = $null
    if ($null -ne $desktop.Signature) {
        $pet = [Jeremias.WindowBridge]::Inspect($desktop.PetHandle)
        if ($null -ne $pet -and ($pet.Pid -ne $desktop.PetPid -or $pet.Process -ne $desktop.Signature.Process -or $pet.ClassName -ne $desktop.Signature.ClassName)) { $pet = $null }
        # Reconnect only a uniquely identified pet window. A generic/blank title is not safe to re-identify automatically.
        if ($null -eq $pet -and ($now - $desktop.LastScan).TotalSeconds -ge 2) {
            $desktop.LastScan = $now
            $title = [string]$desktop.Signature.Title
            if ($title -match '(?i)pet|mascot|jeremias|companion') {
                $found = @([Jeremias.WindowBridge]::Find([string]$desktop.Signature.Process,[string]$desktop.Signature.ClassName,$title))
                if ($found.Count -eq 1) { $pet=$found[0]; $desktop.PetHandle=$pet.Handle; $desktop.PetPid=$pet.Pid; $desktop.LastDock='' }
            }
        }
    }
    $hide = $desktop.Fullscreen -and [Jeremias.WindowBridge]::FullscreenOnWidgetMonitor($desktop.Hwnd,$desktop.PetHandle)
    if ($hide -ne $desktop.Hidden) {
        $desktop.Hidden = $hide
        if ($hide) { $window.Topmost=$false; $window.IsHitTestVisible=$false; $window.Opacity=0 }
        else { $window.Opacity=1; $window.IsHitTestVisible=$true; $window.Topmost=$desktop.Pin; $desktop.LastDock='' }
    }
    $docked = $false
    if ($null -ne $pet -and -not $hide) {
        # Position the real external overlay without activating, resizing, reparenting or changing its z-order.
        $origin = $window.PointToScreen([Windows.Point]::new(0,0)); $bottom = $window.PointToScreen([Windows.Point]::new($window.ActualWidth/2,$window.ActualHeight*90/322))
        $x = [int][Math]::Round($bottom.X - $pet.Bounds.Width/2); $y = [int][Math]::Round($bottom.Y - $pet.Bounds.Height)
        $key = '{0},{1},{2},{3},{4}' -f $pet.Handle,$x,$y,$pet.Bounds.Width,$pet.Bounds.Height
        if ($desktop.LastDock -ne $key) {
            if ([Jeremias.WindowBridge]::Move($pet,$x,$y)) { $desktop.LastDock=$key; $docked=$true } else { $desktop.LastDock='' }
        } else { $docked = ([Math]::Abs($pet.Bounds.Left-$x) -le 12 -and [Math]::Abs($pet.Bounds.Top-$y) -le 12) }
    } else { $desktop.LastDock='' }
    $controls.Mascot.Visibility = if ($docked) { 'Hidden' } else { 'Visible' }
    if ($null -eq $desktop.PairUntil) {
        if ($now -lt $desktop.NoticeUntil) { $controls.PetStatus.Text = $desktop.PairNotice }
        elseif ($docked) { $controls.PetStatus.Text = 'Jeremias · native pet linked' }
        elseif ($null -ne $pet) { $controls.PetStatus.Text = 'Pet not docked · relink' }
        elseif ($null -ne $desktop.Signature) { $controls.PetStatus.Text = 'Jeremias · local (pet hidden)' }
        else { $controls.PetStatus.Text = 'Jeremias · local animation' }
    }
}
$window.Add_SourceInitialized({ $desktop.Hwnd = [Windows.Interop.WindowInteropHelper]::new($window).Handle })
$menu = New-Object Windows.Controls.ContextMenu
$startup = New-Object Windows.Controls.MenuItem
$startup.Header = 'Start with Windows'; $startup.IsCheckable = $true; $startup.IsChecked = (Test-Path $startupPath)
$startup.Add_Click({
    try {
        if ($startup.IsChecked) {
            $shell = New-Object -ComObject WScript.Shell
            $link = $shell.CreateShortcut($startupPath)
            $link.TargetPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
            $link.Arguments = '-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $root 'WorldClock.ps1') + '"'

            $link.WorkingDirectory = $root
            $icon = Join-Path $root 'assets\JeremiasClock.ico'
            if (Test-Path $icon) { $link.IconLocation = $icon + ',0' }
            $link.Save()
        } else { Remove-Item $startupPath -ErrorAction SilentlyContinue }
    } catch { $startup.IsChecked = (Test-Path $startupPath); [void][Windows.MessageBox]::Show($_.Exception.Message,'Jeremias') }
})
$reset = New-Object Windows.Controls.MenuItem; $reset.Header = 'Reset position'
$reset.Add_Click({ $wa = [System.Windows.SystemParameters]::WorkArea; $window.Left=$wa.Right-$window.Width-14; $window.Top=$wa.Bottom-$window.Height-14; Save-Settings })
$sizeMenu = New-Object Windows.Controls.MenuItem; $sizeMenu.Header = 'Size'
foreach ($preset in @(@{Label='Small (60%)';Width=264},@{Label='Normal (100%)';Width=440},@{Label='Large (150%)';Width=660},@{Label='Extra large (200%)';Width=880})) {
    $item = New-Object Windows.Controls.MenuItem; $item.Header = $preset.Label; $item.Tag = $preset.Width
    $item.Add_Click({ param($sender,$e) Set-WidgetSize ([double]$sender.Tag); Save-Settings })
    [void]$sizeMenu.Items.Add($item)
}
$fullItem = New-Object Windows.Controls.MenuItem; $fullItem.Header = 'Hide in fullscreen'; $fullItem.IsCheckable=$true; $fullItem.IsChecked=$desktop.Fullscreen; $fullItem.IsEnabled=$bridgeAvailable
$fullItem.Add_Click({ $desktop.Fullscreen=$fullItem.IsChecked; Update-Desktop; Save-Settings })
$pairItem = New-Object Windows.Controls.MenuItem; $pairItem.Header = 'Link ChatGPT pet (point in 5s)'; $pairItem.IsEnabled=$bridgeAvailable
$pairItem.Add_Click({ $desktop.PairUntil=[DateTimeOffset]::UtcNow.AddSeconds(5); Update-Desktop })
$unpairItem = New-Object Windows.Controls.MenuItem; $unpairItem.Header = 'Unlink pet / local animation'
$unpairItem.Add_Click({ $desktop.PairUntil=$null; $desktop.Signature=$null; $desktop.PetHandle=[IntPtr]::Zero; $desktop.PetPid=0; $desktop.LastDock=''; Show-PetNotice 'Jeremias · local animation'; Update-Desktop; Save-Settings })
$quit = New-Object Windows.Controls.MenuItem; $quit.Header = 'Close'; $quit.Add_Click({ $window.Close() })
[void]$menu.Items.Add($startup); [void]$menu.Items.Add($reset); [void]$menu.Items.Add($sizeMenu); [void]$menu.Items.Add($fullItem); [void]$menu.Items.Add($pairItem); [void]$menu.Items.Add($unpairItem); [void]$menu.Items.Add($quit); $window.ContextMenu = $menu
$clockTimer = New-Object Windows.Threading.DispatcherTimer; $clockTimer.Interval = [TimeSpan]::FromMilliseconds(250); $clockTimer.Add_Tick({ Update-Clocks })
$desktopTimer = New-Object Windows.Threading.DispatcherTimer; $desktopTimer.Interval=[TimeSpan]::FromMilliseconds(500); $desktopTimer.Add_Tick({ try { Update-Desktop } catch { $controls.Mascot.Visibility='Visible'; $controls.PetStatus.Text='Local pet · integration unavailable' } })
$blinkTimer = New-Object Windows.Threading.DispatcherTimer; $blinkTimer.Interval = [TimeSpan]::FromSeconds(5)
$openTimer = New-Object Windows.Threading.DispatcherTimer; $openTimer.Interval = [TimeSpan]::FromMilliseconds(170)
$blinkTimer.Add_Tick({ $controls.Mascot.Source = $blink; $openTimer.Start() })
$openTimer.Add_Tick({ $openTimer.Stop(); $controls.Mascot.Source = $normal })
$window.Add_Closed({ $clockTimer.Stop(); $desktopTimer.Stop(); $blinkTimer.Stop(); $openTimer.Stop(); Save-Settings })
Update-Clocks; $clockTimer.Start(); $desktopTimer.Start(); $blinkTimer.Start(); [void]$window.ShowDialog()
} catch {
    [void][Windows.MessageBox]::Show($_.Exception.Message,'Jeremias World Clock - error')
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
