param([string]$Destination)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (!$Destination) { $Destination = Join-Path $root 'dist\phone-mirror-control-panel-v1.1.0-win64.zip' }
$parent = Split-Path ([IO.Path]::GetFullPath($Destination)) -Parent
$null = New-Item -ItemType Directory -Force -Path $parent
$items = @('Phone Mirror.exe','README.md','NOTICE','LICENSE','THIRD-PARTY.md','UI-preview.png','vendor','licenses','third-party-source')
foreach ($item in $items) { if (!(Test-Path (Join-Path $root $item))) { throw "Missing release item: $item" } }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$stream = [IO.File]::Open($Destination,[IO.FileMode]::Create)
$archive = New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($item in $items) {
        $entryPath=Join-Path $root $item
        $files=if ((Get-Item $entryPath).PSIsContainer) { @(Get-ChildItem -LiteralPath $entryPath -Recurse -File) } else { @(Get-Item $entryPath) }
        foreach ($file in $files) {
            if ($file.Name -in @('open_a_terminal_here.bat','scrcpy-noconsole.vbs','.gitkeep')) { continue }
            $relative=$file.FullName.Substring($root.Length+1).Replace('\','/')
            $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$file.FullName,('phone-mirror-control-panel/'+$relative),[IO.Compression.CompressionLevel]::Optimal)
        }
    }
} finally { $archive.Dispose(); $stream.Dispose() }
Get-Item $Destination | Select-Object FullName,Length
