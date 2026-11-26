function Show-TodayPanel {
    param([Windows.Window]$Owner, [Parameter(Mandatory)][string]$Path)

    [xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Jeremias Today" Width="640" Height="510" MinWidth="430" MinHeight="330"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False" FontFamily="Segoe UI" FontSize="14"
        Background="#141719" Foreground="#F2F5F0">
    <Window.Resources>
        <Style TargetType="Label">
            <Setter Property="Foreground" Value="#F2F5F0"/>
            <Setter Property="Padding" Value="0,4"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Padding" Value="12,5"/>
            <Setter Property="Margin" Value="8,0,0,0"/>
        </Style>
    </Window.Resources>
    <DockPanel Margin="16" LastChildFill="True">
        <StackPanel DockPanel.Dock="Top" Margin="0,0,0,12">
            <TextBlock Text="Today" FontSize="25" FontWeight="SemiBold"/>
            <TextBlock x:Name="LocalDate" Foreground="#A3ACA6" TextWrapping="Wrap"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Bottom" Margin="0,12,0,0">
            <TextBlock x:Name="StoreWarning" Foreground="#E9C88D" TextWrapping="Wrap"/>
            <Grid>
                <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                <TextBlock x:Name="Status" Foreground="#A3ACA6" TextWrapping="Wrap" VerticalAlignment="Center"
                           AutomationProperties.LiveSetting="Polite"/>
                <Button x:Name="ClosePanel" Grid.Column="1" IsCancel="True" Content="Close"/>
            </Grid>
        </StackPanel>
        <TabControl Background="#212626" Padding="0">
            <TabItem x:Name="AgendaTab" Header="_Agenda">
                <Grid Margin="12">
                    <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
                    <CheckBox x:Name="ShowPast" Content="Include past entries" Foreground="#F2F5F0" Margin="0,0,0,8"/>
                    <ListBox Grid.Row="1" x:Name="AgendaList" AutomationProperties.Name="Calendar entries"/>
                    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" MaxHeight="155">
                        <StackPanel>
                            <Label Content="Event _title" Target="{Binding ElementName=EntryTitle}"/>
                            <TextBox x:Name="EntryTitle"/>
                            <Grid>
                                <Grid.ColumnDefinitions><ColumnDefinition Width="105"/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
                                <StackPanel Margin="0,0,8,0">
                                    <Label Content="_Kind" Target="{Binding ElementName=EntryKind}"/>
                                    <ComboBox x:Name="EntryKind" SelectedIndex="0">
                                        <ComboBoxItem Content="Meeting"/><ComboBoxItem Content="Focus"/>
                                    </ComboBox>
                                </StackPanel>
                                <StackPanel Grid.Column="1" Margin="0,0,8,0">
                                    <Label Content="_Start (local)" Target="{Binding ElementName=EntryStart}"/>
                                    <TextBox x:Name="EntryStart"/>
                                </StackPanel>
                                <StackPanel Grid.Column="2">
                                    <Label Content="_End (local)" Target="{Binding ElementName=EntryEnd}"/>
                                    <TextBox x:Name="EntryEnd"/>
                                </StackPanel>
                            </Grid>
                            <TextBlock Text="Use yyyy-MM-dd HH:mm." Foreground="#A3ACA6" Margin="0,5"/>
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                                <Button x:Name="NewEntry" Content="_New event"/><Button x:Name="SaveEntry" Content="Save _event"/>
                            </StackPanel>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>
            </TabItem>
            <TabItem x:Name="NotesTab" Header="_Notes">
                <Grid Margin="12">
                    <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="3*"/></Grid.ColumnDefinitions>
                    <DockPanel Margin="0,0,12,0">
                        <Label DockPanel.Dock="Top" Content="Searc_h notes" Target="{Binding ElementName=NoteSearch}"/>
                        <TextBox DockPanel.Dock="Top" x:Name="NoteSearch" Margin="0,0,0,8"/>
                        <ListBox x:Name="NoteList" AutomationProperties.Name="Matching notes"/>
                    </DockPanel>
                    <DockPanel Grid.Column="1">
                        <Label DockPanel.Dock="Top" Content="Note _title" Target="{Binding ElementName=NoteTitle}"/>
                        <TextBox DockPanel.Dock="Top" x:Name="NoteTitle"/>
                        <Label DockPanel.Dock="Top" Content="Note _body" Target="{Binding ElementName=NoteText}"/>
                        <StackPanel DockPanel.Dock="Bottom" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,8,0,0">
                            <Button x:Name="NewNote" Content="_New note"/><Button x:Name="SaveNote" Content="_Save note"/>
                        </StackPanel>
                        <TextBox x:Name="NoteText" AcceptsReturn="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"/>
                    </DockPanel>
                </Grid>
            </TabItem>
        </TabControl>
    </DockPanel>
</Window>
'@
    $reader = [System.Xml.XmlNodeReader]::new($markup)
    try { $panel = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
    if ($null -ne $Owner) { $panel.Owner = $Owner }
    $controls = @{}
    foreach ($name in 'LocalDate','StoreWarning','Status','ShowPast','AgendaList','EntryTitle','EntryKind','EntryStart','EntryEnd','NewEntry','SaveEntry','NoteSearch','NoteList','NoteTitle','NoteText','NewNote','SaveNote') {
        $controls[$name] = $panel.FindName($name)
    }

    $data = Read-ProductivityStore -Path $Path
    $state = @{ Data = $data; NoteId = $null; EntryId = $null }
    $controls.StoreWarning.Text = [string]$data.Warning
    $format = 'yyyy-MM-dd HH:mm'
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $zone = [TimeZoneInfo]::Local
    $controls.LocalDate.Text = '{0}  |  {1}' -f [DateTime]::Now.ToString('D'), $zone.DisplayName

    function ConvertTo-TodayUtc([string]$value) {
        $localTime = [DateTime]::MinValue
        if (-not [DateTime]::TryParseExact($value.Trim(), $format, $culture, [Globalization.DateTimeStyles]::None, [ref]$localTime)) {
            throw 'Enter the start and end as yyyy-MM-dd HH:mm.'
        }
        if ($zone.IsInvalidTime($localTime) -or $zone.IsAmbiguousTime($localTime)) {
            throw 'This time is skipped or repeated by a clock change. Choose a nearby unambiguous local time.'
        }
        return [DateTimeOffset]::new([TimeZoneInfo]::ConvertTimeToUtc($localTime, $zone))
    }

    function Get-TodayInstant($value) {
        return [DateTimeOffset]::Parse([string]$value, $culture)
    }

    function Refresh-TodayAgenda {
        $controls.AgendaList.Items.Clear()
        $now = [DateTimeOffset]::UtcNow
        $sorted = $state.Data.Entries | Sort-Object { Get-TodayInstant $_.StartUtc }
        foreach ($entry in $sorted) {
            if (-not $controls.ShowPast.IsChecked -and (Get-TodayInstant $entry.EndUtc) -le $now) { continue }
            $start = [TimeZoneInfo]::ConvertTime((Get-TodayInstant $entry.StartUtc), $zone)
            $end = [TimeZoneInfo]::ConvertTime((Get-TodayInstant $entry.EndUtc), $zone)
            $item = [Windows.Controls.ListBoxItem]::new()
            $item.Content = '{0} | {1} - {2} | {3}' -f $entry.Kind, $start.ToString('MMM d HH:mm'), $end.ToString('MMM d HH:mm'), $entry.Title
            $item.Tag = $entry
            [void]$controls.AgendaList.Items.Add($item)
        }
        if ($controls.AgendaList.Items.Count -eq 0) { $controls.Status.Text = 'No entries in this view.' }
    }

    function Refresh-TodayNotes {
        $controls.NoteList.Items.Clear()
        $query = $controls.NoteSearch.Text.Trim()
        foreach ($note in $state.Data.Notes) {
            $matches = -not $query -or $note.Title.IndexOf($query, [StringComparison]::CurrentCultureIgnoreCase) -ge 0 -or $note.Text.IndexOf($query, [StringComparison]::CurrentCultureIgnoreCase) -ge 0
            if (-not $matches) { continue }
            $item = [Windows.Controls.ListBoxItem]::new()
            $item.Content = $note.Title
            $item.Tag = $note
            [void]$controls.NoteList.Items.Add($item)
        }
    }

    function Reset-TodayEntry {
        $controls.AgendaList.SelectedIndex = -1
        $state.EntryId = $null
        $controls.EntryTitle.Clear()
        $controls.EntryKind.SelectedIndex = 0
        $start = [DateTime]::Now.AddMinutes(5)
        $controls.EntryStart.Text = $start.ToString($format, $culture)
        $controls.EntryEnd.Text = $start.AddMinutes(30).ToString($format, $culture)
    }

    $controls.NewEntry.Add_Click({
        Reset-TodayEntry
        [void]$controls.EntryTitle.Focus()
    })
    $controls.ShowPast.Add_Click({
        $controls.Status.Text = ''
        Refresh-TodayAgenda
    })
    $controls.AgendaList.Add_SelectionChanged({
        $selected = $controls.AgendaList.SelectedItem
        if ($null -eq $selected) { return }
        $entry = $selected.Tag
        $state.EntryId = $entry.Id
        $controls.EntryTitle.Text = $entry.Title
        $controls.EntryKind.SelectedIndex = if ($entry.Kind -eq 'Focus') { 1 } else { 0 }
        $controls.EntryStart.Text = [TimeZoneInfo]::ConvertTime((Get-TodayInstant $entry.StartUtc), $zone).ToString($format, $culture)
        $controls.EntryEnd.Text = [TimeZoneInfo]::ConvertTime((Get-TodayInstant $entry.EndUtc), $zone).ToString($format, $culture)
        $controls.Status.Text = ''
    })
    $controls.SaveEntry.Add_Click({
        try {
            $title = $controls.EntryTitle.Text.Trim()
            if (-not $title) { throw 'Enter a title for this event.' }
            $start = ConvertTo-TodayUtc $controls.EntryStart.Text
            $end = ConvertTo-TodayUtc $controls.EntryEnd.Text
            if ($end -le $start) { throw 'The end must be after the start.' }
            $id = if ($state.EntryId) { $state.EntryId } else { [Guid]::NewGuid().ToString() }
            $entry = @{
                Id = $id; Title = $title; Kind = [string]$controls.EntryKind.SelectedItem.Content
                StartUtc = $start.ToString('o', $culture); EndUtc = $end.ToString('o', $culture)
            }
            $newData = @{ Notes = $state.Data.Notes; Entries = @($state.Data.Entries | Where-Object Id -ne $id) + @($entry) }
            Save-ProductivityStore -Path $Path -Data $newData
            $state.Data = $newData
            $state.EntryId = $id
            Refresh-TodayAgenda
            $controls.StoreWarning.Text = ''
            $controls.Status.Text = 'Event saved.'
        } catch { $controls.Status.Text = $_.Exception.Message }
    })

    $controls.NoteSearch.Add_TextChanged({ Refresh-TodayNotes })
    $controls.NoteList.Add_SelectionChanged({
        $selected = $controls.NoteList.SelectedItem
        if ($null -eq $selected) { return }
        $state.NoteId = $selected.Tag.Id
        $controls.NoteTitle.Text = $selected.Tag.Title
        $controls.NoteText.Text = $selected.Tag.Text
        $controls.Status.Text = ''
    })
    $controls.NewNote.Add_Click({
        $controls.NoteList.SelectedIndex = -1
        $state.NoteId = $null
        $controls.NoteTitle.Clear()
        $controls.NoteText.Clear()
        [void]$controls.NoteTitle.Focus()
    })
    $controls.SaveNote.Add_Click({
        try {
            $title = $controls.NoteTitle.Text.Trim()
            if (-not $title) { throw 'Enter a title for this note.' }
            $id = if ($state.NoteId) { $state.NoteId } else { [Guid]::NewGuid().ToString() }
            $note = @{ Id = $id; Title = $title; Text = $controls.NoteText.Text }
            $newData = @{ Entries = $state.Data.Entries; Notes = @($state.Data.Notes | Where-Object Id -ne $id) + @($note) }
            Save-ProductivityStore -Path $Path -Data $newData
            $state.Data = $newData
            $state.NoteId = $id
            Refresh-TodayNotes
            $controls.StoreWarning.Text = ''
            $controls.Status.Text = 'Note saved.'
        } catch { $controls.Status.Text = $_.Exception.Message }
    })

    Reset-TodayEntry
    Refresh-TodayAgenda
    Refresh-TodayNotes
    [void]$panel.ShowDialog()
}
