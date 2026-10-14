$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$temp=Join-Path ([IO.Path]::GetTempPath()) ('PhoneMirrorTests-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $temp
try {
    $test=Join-Path $temp 'AppModeTests.exe'
    & $compiler /nologo /reference:System.Windows.Forms.dll /reference:System.Core.dll "/out:$test" (Join-Path $root 'tests\AppModeTests.cs')
    if($LASTEXITCODE -ne 0){throw 'Test compilation failed.'}
    & $test (Join-Path $root 'Phone Mirror.exe')
    if($LASTEXITCODE -ne 0){throw 'App-mode checks failed.'}
} finally {
    if((Resolve-Path -LiteralPath $temp).Path.StartsWith([IO.Path]::GetTempPath(),[StringComparison]::OrdinalIgnoreCase)) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
