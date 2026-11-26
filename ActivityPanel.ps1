function Show-ActivityPanel {
    param([Windows.Window]$Owner, [string]$Path, [string]$AgendaPath, [string]$CalendarPath)
    [xml]$markup = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="Jeremias Activity" Width="680" Height="565" MinWidth="420" MinHeight="440"
 WindowStartupLocation="CenterOwner" ShowInTaskbar="False" FontSize="14"
 Background="#141719" Foreground="#F2F5F0">
 <Grid Margin="16">
   <Grid.RowDefinitions>
     <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
     <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
     <RowDefinition Height="Auto"/>
   </Grid.RowDefinitions>
   <StackPanel>
     <TextBlock Text="Activity" FontSize="25" FontWeight="SemiBold"/>
     <TextBlock Text="Local-only checks run while Jeremias is open." TextWrapping="Wrap"/>
   </StackPanel>
   <StackPanel Grid.Row="1" Margin="0,8">
     <TextBlock Text="Watch a local or selected-calendar meeting for overlaps"/>
     <DockPanel>
       <Button DockPanel.Dock="Right" x:Name="Watch" Content="_Watch meeting" Margin="8,0,0,0"/>
       <ComboBox x:Name="Meetings" DisplayMemberPath="Label" AutomationProperties.Name="Eligible meetings"/>
     </DockPanel>
   </StackPanel>
   <ListBox Grid.Row="2" x:Name="Responsibilities" DisplayMemberPath="Label" AutomationProperties.Name="Responsibilities"/>
   <WrapPanel Grid.Row="3" Margin="0,8">
     <Button x:Name="Pause" Content="Pause or _resume future checks" Margin="0,0,8,0"/>
     <Button x:Name="Refresh" Content="Check _now"/>
   </WrapPanel>
   <ListBox Grid.Row="4" x:Name="Runs" DisplayMemberPath="Label" AutomationProperties.Name="Run history"/>
   <TextBox Grid.Row="5" x:Name="Details" IsReadOnly="True" TextWrapping="Wrap" MaxHeight="105"
    VerticalScrollBarVisibility="Auto" AutomationProperties.Name="Run details" Margin="0,6"/>
   <DockPanel Grid.Row="6">
     <Button DockPanel.Dock="Right" IsCancel="True" Content="Close"/>
     <Button DockPanel.Dock="Right" x:Name="CancelRun" Content="Request _cancellation" Margin="0,0,8,0" IsEnabled="False"/>
     <TextBlock x:Name="Status" TextWrapping="Wrap" AutomationProperties.LiveSetting="Polite"/>
   </DockPanel>
 </Grid>
</Window>
"@
    $reader = [Xml.XmlNodeReader]::new($markup)
    try { $panel = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
    if ($Owner) { $panel.Owner = $Owner }
    $view = @{}
    foreach ($name in 'Meetings','Watch','Responsibilities','Pause','Refresh','Runs','Details','CancelRun','Status') {
        $view[$name] = $panel.FindName($name)
    }
    $update = {
        $state = Read-ResponsibilityStore $Path
        $agenda = Read-ProductivityStore $AgendaPath
        $calendar = Read-JeremiasCalendarCache -Path $CalendarPath
        $view.Meetings.ItemsSource = @(Get-JeremiasActivityMeetingChoices -Agenda $agenda -Calendar $calendar)
        $view.Watch.IsEnabled = -not $agenda.Warning -and $view.Meetings.Items.Count -gt 0
        $titles = @{}
        $view.Responsibilities.ItemsSource = @(foreach ($r in $state.Responsibilities) {
            $titles[$r.Id] = $r.Title
            $flag = if ($r.Paused) { 'Paused' } else { 'Watching' }
            [pscustomobject]@{ Id = $r.Id; Paused = $r.Paused; Label = "$flag - $($r.Title) [$($r.SourceId); $($r.Owner)]" }
        })
        $view.Runs.ItemsSource = @(foreach ($run in ($state.Runs | Select-Object -Last 200 | Sort-Object CreatedUtc -Descending)) {
            $statusText = if ($run.Status -eq 'CancellationRequested') { 'Cancellation requested (not yet confirmed)' } else { $run.Status }
            [pscustomobject]@{ Run = $run; Label = "$statusText - $($titles[$run.ResponsibilityId])" }
        })
        $view.Status.Text = if ($agenda.Warning) { [string]$agenda.Warning } else { "Calendar snapshot: $($calendar.Status). No automatic network refresh." }
    }
    $view.Refresh.Add_Click({
        try { $null = Invoke-JeremiasResponsibilityChecks $Path $AgendaPath $CalendarPath; & $update }
        catch { $view.Status.Text = $_.Exception.Message }
    })
    $view.Watch.Add_Click({
        try {
            $meeting = $view.Meetings.SelectedItem
            if (-not $meeting) { throw 'Select a meeting first.' }
            if ($meeting.Scope -ceq 'Calendar') {
                $fresh = Read-JeremiasCalendarCache -Path $CalendarPath
                if ($fresh.Status -cne 'Fresh' -or $fresh.CalendarId -cne $meeting.SourceId -or
                    -not ($fresh.Entries | Where-Object { $_.Id -ceq $meeting.Id -and $_.Revision -ceq $meeting.Revision })) {
                    throw 'Calendar selection changed. Reopen Activity and select the current meeting.'
                }
            }
            $null = New-MeetingResponsibility -Path $Path -Title $meeting.Title -SourceId $meeting.SourceId -MeetingId $meeting.Id -Scope $meeting.Scope
            $null = Invoke-JeremiasResponsibilityChecks $Path $AgendaPath $CalendarPath
            & $update
        } catch { $view.Status.Text = $_.Exception.Message }
    })
    $view.Pause.Add_Click({
        try {
            $r = $view.Responsibilities.SelectedItem
            if (-not $r) { throw 'Select a responsibility first.' }
            Set-ResponsibilityPaused $Path $r.Id (-not $r.Paused)
            & $update
        } catch { $view.Status.Text = $_.Exception.Message }
    })
    $view.Runs.Add_SelectionChanged({
        $run = $view.Runs.SelectedItem.Run
        $view.CancelRun.IsEnabled = $run.Status -eq 'Running'
        $view.Details.Text = if ($run) {
            "$($run.CreatedUtc) | $($run.Provider) | $($run.Status)" + [Environment]::NewLine +
                $run.Summary + [Environment]::NewLine + ($run.Citations -join [Environment]::NewLine)
        } else { '' }
    })
    $view.CancelRun.Add_Click({
        try {
            $run = $view.Runs.SelectedItem.Run
            if (-not $run) { throw 'Select a run first.' }
            $null = Set-ResponsibilityRunStatus $Path $run.Id 'RequestCancellation'
            & $update
            $view.Status.Text = 'Cancellation requested. The run has not confirmed a stop.'
        } catch { $view.Status.Text = $_.Exception.Message }
    })
    try { & $update } catch { $view.Status.Text = $_.Exception.Message }
    [void]$panel.ShowDialog()
}
