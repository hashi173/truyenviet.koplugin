$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$plugin = Join-Path $root "truyenviet.koplugin"
$dist = Join-Path $root "dist"
$archive = Join-Path $dist "truyenviet.koplugin.zip"

if (-not (Test-Path -LiteralPath $plugin -PathType Container)) {
    throw "Không tìm thấy thư mục plugin: $plugin"
}

New-Item -ItemType Directory -Path $dist -Force | Out-Null

$reparsePoints = Get-ChildItem -LiteralPath $plugin -Recurse -Force |
    Where-Object {
        $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint
    }
if ($reparsePoints) {
    $paths = ($reparsePoints.FullName -join [Environment]::NewLine)
    throw "Plugin chứa liên kết/reparse point không hợp lệ:`n$paths"
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$stream = [System.IO.File]::Open(
    $archive,
    [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::ReadWrite,
    [System.IO.FileShare]::None
)
$zip = [System.IO.Compression.ZipArchive]::new(
    $stream,
    [System.IO.Compression.ZipArchiveMode]::Create,
    $false
)

try {
    Get-ChildItem -LiteralPath $plugin -Recurse -File -Force | ForEach-Object {
        $entryName = $_.FullName.Substring($root.Length + 1).Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            $_.FullName,
            $entryName,
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null
    }
}
finally {
    $zip.Dispose()
    $stream.Dispose()
}

Write-Output $archive
