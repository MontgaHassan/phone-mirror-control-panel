$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (!(Test-Path $compiler)) { $compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (!(Test-Path $compiler)) { throw 'Install .NET Framework 4.8 to compile the native launcher.' }
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.Xml.Linq.dll /reference:System.Core.dll "/win32manifest:$root\src\app.manifest" "/out:$root\Phone Mirror.exe" "$root\src\PhoneMirror.cs"
if($LASTEXITCODE -ne 0){throw 'Native build failed.'}
Get-Item -LiteralPath (Join-Path $root 'Phone Mirror.exe') | Select-Object Name,Length
