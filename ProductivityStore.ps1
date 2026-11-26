function ConvertTo-ProductivityUtc([object]$Value) {
    $instant = [DateTimeOffset]::MinValue
    $culture = [Globalization.CultureInfo]::InvariantCulture
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime() }
    if ($Value -is [DateTime] -and $Value.Kind -ne 'Unspecified') {
        return ([DateTimeOffset]$Value).ToUniversalTime()
    }
    if ($Value -is [string] -and $Value -match '(?:Z|[+-]\d{2}:\d{2})$' -and
        [DateTimeOffset]::TryParse($Value, $culture, [Globalization.DateTimeStyles]::None, [ref]$instant)) {
        return $instant.ToUniversalTime()
    }
    throw [IO.InvalidDataException]::new('An agenda time is missing its UTC offset or is invalid.')
}

function ConvertTo-ProductivitySnapshot([object]$Data) {
    if ($null -eq $Data -or $Data.Notes -isnot [array] -or $Data.Entries -isnot [array]) {
        throw [IO.InvalidDataException]::new('Notes and agenda entries must be collections.')
    }

    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $notes = @(foreach ($note in $Data.Notes) {
        if ($note.Id -isnot [string] -or [string]::IsNullOrWhiteSpace($note.Id) -or
            $note.Title -isnot [string] -or [string]::IsNullOrWhiteSpace($note.Title) -or
            $note.Text -isnot [string] -or -not $ids.Add($note.Id)) {
            throw [IO.InvalidDataException]::new('A note is invalid or has a duplicate ID.')
        }
        [pscustomobject]@{ Id = $note.Id; Title = $note.Title; Text = $note.Text }
    })

    $ids.Clear()
    $entries = @(foreach ($entry in $Data.Entries) {
        if ($entry.Id -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.Id) -or
            $entry.Title -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.Title) -or
            $entry.Kind -cnotin 'Meeting', 'Focus' -or -not $ids.Add($entry.Id)) {
            throw [IO.InvalidDataException]::new('An agenda entry is invalid or has a duplicate ID.')
        }
        $start = ConvertTo-ProductivityUtc $entry.StartUtc
        $end = ConvertTo-ProductivityUtc $entry.EndUtc
        if ($start -ge $end) { throw [IO.InvalidDataException]::new('An agenda entry must end after it starts.') }
        [pscustomobject]@{
            Id = $entry.Id
            Title = $entry.Title
            Kind = $entry.Kind
            StartUtc = $start.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
            EndUtc = $end.ToString('o', [Globalization.CultureInfo]::InvariantCulture)
        }
    })

    return [pscustomobject][ordered]@{
        Version = 1
        Notes = $notes
        Entries = $entries
    }
}

function Import-ProductivityStoreFile([string]$Path) {
    $json = [IO.File]::ReadAllText($Path)
    try {
        $parsed = ConvertFrom-Json -InputObject $json -ErrorAction Stop
    } catch {
        throw [IO.InvalidDataException]::new('The productivity file contains invalid JSON.', $_.Exception)
    }
    if ($null -eq $parsed -or ($parsed.Version -isnot [int] -and $parsed.Version -isnot [long])) {
        throw [IO.InvalidDataException]::new('The productivity file has no valid version.')
    }
    if ($parsed.Version -ne 1) { throw [NotSupportedException]::new('This productivity file uses an unsupported version.') }
    return ConvertTo-ProductivitySnapshot $parsed
}

function Read-ProductivityStore {
    param([Parameter(Mandatory)][string]$Path)

    $warning = $null
    try {
        $data = Import-ProductivityStoreFile $Path
    } catch [IO.FileNotFoundException], [IO.DirectoryNotFoundException] {
        $data = $null
    } catch {
        $data = $null
        $warning = 'Local notes and agenda could not be read. Check the productivity file before saving.'
    }

    if ($null -eq $data) {
        try {
            $data = Import-ProductivityStoreFile ($Path + '.bak')
            $warning = 'Local notes and agenda were recovered from the backup.'
        } catch [IO.FileNotFoundException], [IO.DirectoryNotFoundException] {
        } catch {
            $warning = 'The local notes and agenda backup could not be read. Check the productivity files before saving.'
        }
    }
    if ($null -eq $data) {
        $data = [pscustomobject]@{ Version = 1; Notes = @(); Entries = @() }
    }
    $data | Add-Member -NotePropertyName Warning -NotePropertyValue $warning
    return $data
}

function Save-ProductivityStore {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Data
    )

    $pending = $null
    try {
        $snapshot = ConvertTo-ProductivitySnapshot $Data
        $destination = [IO.Path]::GetFullPath($Path)
        $directory = [IO.Path]::GetDirectoryName($destination)
        $null = [IO.Directory]::CreateDirectory($directory)
        $pending = Join-Path $directory ('.productivity-' + [Guid]::NewGuid().ToString('N') + '.tmp')
        $json = ConvertTo-Json -InputObject $snapshot -Depth 6 -ErrorAction Stop
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
        $stream = [IO.FileStream]::new($pending, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        try {
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush($true)
        } finally {
            $stream.Dispose()
        }

        if (-not [IO.File]::Exists($destination)) {
            [IO.File]::Move($pending, $destination)
            return
        }

        try {
            $null = Import-ProductivityStoreFile $destination
        } catch [IO.InvalidDataException] {
            # Replacing malformed JSON without creating a backup preserves the last valid backup.
            [IO.File]::Replace($pending, $destination, [NullString]::Value)
            return
        }
        [IO.File]::Replace($pending, $destination, ($destination + '.bak'))
    } catch {
        throw [InvalidOperationException]::new(('Could not save local notes and agenda. ' + $_.Exception.Message), $_.Exception)
    } finally {
        if ($null -ne $pending -and [IO.File]::Exists($pending)) {
            try { [IO.File]::Delete($pending) } catch { }
        }
    }
}
