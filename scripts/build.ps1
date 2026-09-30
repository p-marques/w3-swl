#requires -Version 5.1
<#
Creates a game-root ZIP from the existing runtime assets under src.
VERSION controls the archive name; this script never regenerates source files.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-StreamHash {
    param([System.IO.Stream] $Stream)

    $hasher = [System.Security.Cryptography.SHA256]::Create()
    try {
        return [System.BitConverter]::ToString($hasher.ComputeHash($Stream))
    }
    finally {
        $hasher.Dispose()
    }
}

$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$sourceRoot = Join-Path $repositoryRoot 'src'
$versionPath = Join-Path $repositoryRoot 'VERSION'
if (-not (Test-Path -LiteralPath $versionPath -PathType Leaf)) {
    throw "Missing version file: $versionPath"
}
$version = [System.IO.File]::ReadAllText($versionPath).Trim()
if ($version -notmatch '^[0-9]+\.[0-9]+(?:\.[0-9]+)?$') {
    throw 'VERSION must contain major.minor or major.minor.patch (for example, 3.0).'
}

# An explicit allowlist keeps development files and accidental copies out of releases.
$scriptPaths = @(
    'local/SetWeightLimit.ws'
)
$languages = @(
    'ar', 'br', 'cn', 'cz', 'de', 'en', 'es', 'esMX', 'fr',
    'hu', 'it', 'jp', 'kr', 'pl', 'ru', 'tr', 'ua', 'zh'
)
$contentPath = 'mods/modSWL/content'
$entryPaths = @('bin/config/r4game/user_config_matrix/pc/SWL.xml')
$entryPaths += @($scriptPaths | ForEach-Object { "$contentPath/scripts/$_" })
$entryPaths += @($languages | ForEach-Object { "$contentPath/$_.w3strings" })

# Read and hash every required file before touching an existing release archive.
$inputs = @{}
foreach ($entryPath in $entryPaths) {
    $sourcePath = Join-Path $sourceRoot $entryPath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Missing required release file: $sourcePath"
    }
    $stream = [System.IO.File]::OpenRead($sourcePath)
    try {
        if ($stream.Length -eq 0) {
            throw "Required release file is empty: $sourcePath"
        }
        $inputs[$entryPath] = [PSCustomObject]@{
            SourcePath = $sourcePath
            EntryPath = $entryPath
            Length = $stream.Length
            Hash = Get-StreamHash -Stream $stream
        }
    }
    finally {
        $stream.Dispose()
    }
}

$outputDirectory = Join-Path $repositoryRoot 'dist'
$releasePath = Join-Path $outputDirectory "SetWeightLimit-v$version.zip"
$temporaryArchive = Join-Path $outputDirectory ('.build-' + [guid]::NewGuid().ToString('N') + '.zip')
[System.IO.Directory]::CreateDirectory($outputDirectory) | Out-Null

try {
    $archiveStream = [System.IO.File]::Open(
        $temporaryArchive, [System.IO.FileMode]::CreateNew,
        [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new(
            $archiveStream, [System.IO.Compression.ZipArchiveMode]::Create, $true)
        try {
            foreach ($entryPath in ($entryPaths | Sort-Object)) {
                $entry = $archive.CreateEntry($entryPath, [System.IO.Compression.CompressionLevel]::Optimal)
                $sourceStream = [System.IO.File]::OpenRead($inputs[$entryPath].SourcePath)
                try {
                    $entryStream = $entry.Open()
                    try {
                        $sourceStream.CopyTo($entryStream)
                    }
                    finally {
                        $entryStream.Dispose()
                    }
                }
                finally {
                    $sourceStream.Dispose()
                }
            }
        }
        finally {
            $archive.Dispose()
        }
    }
    finally {
        $archiveStream.Dispose()
    }

    # Validate the finished ZIP's contents, including decompression and source hashes.
    $archive = [System.IO.Compression.ZipFile]::OpenRead($temporaryArchive)
    try {
        if ($archive.Entries.Count -ne $inputs.Count) {
            throw 'Release verification failed: unexpected entry count.'
        }
        $seen = @{}
        foreach ($entry in $archive.Entries) {
            if (-not $inputs.ContainsKey($entry.FullName) -or $seen.ContainsKey($entry.FullName)) {
                throw "Release verification failed: unexpected or duplicate entry '$($entry.FullName)'."
            }
            $expected = $inputs[$entry.FullName]
            if ($entry.FullName -cne $expected.EntryPath -or $entry.Length -ne $expected.Length) {
                throw "Release verification failed: path or length mismatch for '$($entry.FullName)'."
            }
            $entryStream = $entry.Open()
            try {
                if ((Get-StreamHash -Stream $entryStream) -cne $expected.Hash) {
                    throw "Release verification failed: content mismatch for '$($entry.FullName)'."
                }
            }
            finally {
                $entryStream.Dispose()
            }
            $seen[$entry.FullName] = $true
        }
    }
    finally {
        $archive.Dispose()
    }

    # Same-directory replacement publishes only a verified archive.
    if ([System.IO.File]::Exists($releasePath)) {
        # Pass a real null backup path; PowerShell binds $null as an empty string.
        [System.IO.File]::Replace($temporaryArchive, $releasePath, [NullString]::Value)
    }
    else {
        [System.IO.File]::Move($temporaryArchive, $releasePath)
    }
    Write-Output "Created $releasePath ($($inputs.Count) files)."
}
finally {
    if ([System.IO.File]::Exists($temporaryArchive)) {
        [System.IO.File]::Delete($temporaryArchive)
    }
}
