param([switch]$ValidateOnly, [switch]$SmokeTest)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'
$script:toolDir = Join-Path $PSScriptRoot 'vendor\scrcpy'
$env:ADB = Join-Path $script:toolDir 'adb.exe'
$env:SCRCPY_SERVER_PATH = Join-Path $script:toolDir 'scrcpy-server'
$script:session = $null
$script:lastRecord = $null
$script:pending = $null
$dataDir = Join-Path $PSScriptRoot 'Saved'
$null = New-Item -ItemType Directory -Force -Path $dataDir
$settingsFile = Join-Path $dataDir 'settings.json'
$script:saved = @{ Address=''; Preset='Balanced' }
if (Test-Path $settingsFile) { try { $s = Get-Content $settingsFile -Raw | ConvertFrom-Json; $script:saved.Address = [string]$s.Address; $script:saved.Preset = [string]$s.Preset } catch {} }
function Quote-Arg([string]$value) {
    if ($value.Contains('"') -or $value.EndsWith('\')) { throw 'Unsupported character in command argument.' }
    return '"' + $value + '"'
}
function Start-Tool([string]$name, [string[]]$arguments, [switch]$Capture) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $script:toolDir $name
    $info.WorkingDirectory = $script:toolDir
    $info.Arguments = (($arguments | ForEach-Object { Quote-Arg $_ }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $info
    $null = $p.Start()
    return @{ Process=$p; Out=$p.StandardOutput.ReadToEndAsync(); Err=$p.StandardError.ReadToEndAsync(); Started=[DateTime]::Now }
}
function Save-Settings {
    @{ Address=$address.Text.Trim(); Preset=[string]$preset.SelectedItem } | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
}
function Log([string]$message) { $log.AppendText("$message`r`n"); $status.Text = $message.Split("`n")[0] }
function Selected-Serial {
    if ($devices.SelectedIndex -lt 0) { throw 'Select a ready device first. Click Refresh after connecting your phone.' }
    return $script:serials[$devices.SelectedIndex]
}
function Begin-Adb([string[]]$arguments, [string]$action) {
    if ($script:pending) { throw 'Wait for the current device operation to finish.' }
    $script:pending = Start-Tool 'adb.exe' $arguments -Capture
    $script:pending.Action = $action
    Log 'Working…'
}
function Mirror([bool]$record, [bool]$wifiSetup=$false) {
    if ($script:session -and !$script:session.Process.HasExited) { throw 'Stop the current session before starting another.' }
    $serial = Selected-Serial
    $args = @('--serial', $serial, '--window-title=Phone Mirror', '--shortcut-mod=lalt', '--disable-screensaver')
    switch ([string]$preset.SelectedItem) {
        'Sharp' { $args += @('--max-size=1920','--video-bit-rate=12M','--max-fps=60') }
        'Balanced' { $args += @('--max-size=1280','--video-bit-rate=8M','--max-fps=60') }
        'Low delay' { $args += @('--max-size=1024','--video-bit-rate=4M','--max-fps=60','--video-buffer=0') }
    }
    if ($fullscreen.Checked) { $args += '--fullscreen' }
    if ($screenOff.Checked) { $args += '--turn-screen-off' }
    if ($top.Checked) { $args += '--always-on-top' }
    if (!$audio.Checked) { $args += '--no-audio' }
    if ($wifiSetup) { $args += '--tcpip' }
    if ($record) { $script:lastRecord = Join-Path $dataDir ('Recording-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.mkv'); $args += ('--record=' + $script:lastRecord) }
    Save-Settings
    $script:session = Start-Tool 'scrcpy.exe' $args -Capture
    Log $(if ($record) { 'Recording session starting. Stop closes the mirror and finalizes the video.' } else { 'Mirroring session starting…' })
}
function Stop-Mirror {
    if ($script:session -and !$script:session.Process.HasExited) {
        if (!$script:session.Process.CloseMainWindow()) { Log 'The mirror is still starting. Wait, then click Stop again.'; return }
        Log 'Closing mirror and finalizing recording…'
    }
}
if ($ValidateOnly) {
    foreach ($name in @('scrcpy.exe','adb.exe','scrcpy-server')) { if (!(Test-Path (Join-Path $script:toolDir $name))) { throw "Missing $name" } }
    'Launcher validation passed.'
    exit
}
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Phone Mirror • scrcpy Control Panel'
$form.ClientSize = New-Object System.Drawing.Size(760,720)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI',10)
$form.BackColor = [System.Drawing.Color]::FromArgb(245,247,250)
function Label([string]$text,[int]$x,[int]$y,[int]$width=710) {
    $c = New-Object System.Windows.Forms.Label; $c.Text=$text; $c.SetBounds($x,$y,$width,28); $form.Controls.Add($c); return $c
}
function Button([string]$text,[int]$x,[int]$y,[int]$width,[scriptblock]$handler) {
    $c=New-Object System.Windows.Forms.Button; $c.Text=$text; $c.SetBounds($x,$y,$width,36)
    $c.Add_Click({ try { & $handler } catch { Log $_.Exception.Message } }.GetNewClosure()); $form.Controls.Add($c); return $c
}
function Check([string]$text,[int]$x,[int]$y,[bool]$checked=$false) {
    $c=New-Object System.Windows.Forms.CheckBox; $c.Text=$text; $c.SetBounds($x,$y,175,28); $c.Checked=$checked; $form.Controls.Add($c); return $c
}
$null=Label 'PHONE MIRROR' 24 18
$null=Label 'Connect your Android phone, choose a preset, and start.' 24 50
$null=Label 'USB: enable Developer options → USB debugging, then approve this PC on your phone.' 24 84
$devices=New-Object System.Windows.Forms.ComboBox; $devices.DropDownStyle='DropDownList'; $devices.SetBounds(24,120,535,30); $form.Controls.Add($devices)
$script:serials=@()
$null=Button 'Refresh' 574 117 160 { Begin-Adb @('devices','-l') 'devices' }
$null=Label 'Quality' 24 165 80
$preset=New-Object System.Windows.Forms.ComboBox; $preset.DropDownStyle='DropDownList'; $preset.SetBounds(104,163,180,30); $null=$preset.Items.AddRange(@('Sharp','Balanced','Low delay')); $preset.SelectedItem=$script:saved.Preset; if ($preset.SelectedIndex -lt 0) { $preset.SelectedIndex=1 }; $form.Controls.Add($preset)
$fullscreen=Check 'Start fullscreen' 24 205
$screenOff=Check 'Phone screen off' 205 205
$top=Check 'Always on top' 386 205
$audio=Check 'Forward audio' 567 205 $true
$null=Button 'Start mirror' 24 245 165 { Mirror $false }
$null=Button 'Start recording' 205 245 165 { Mirror $true }
$null=Button 'Stop session' 386 245 165 { Stop-Mirror }
$null=Button 'Open saved files' 567 245 167 { Start-Process explorer.exe -ArgumentList (Quote-Arg $dataDir) }
$null=Label 'WI-FI CONNECTION' 24 300
$null=Label 'Same network: use USB → Wi-Fi once, or pair through Android Wireless debugging.' 24 328
$address=New-Object System.Windows.Forms.TextBox; $address.SetBounds(24,362,270,30); $address.Text=$script:saved.Address; $form.Controls.Add($address)
$null=Button 'Connect address' 306 358 140 {
    $value=$address.Text.Trim()
    if ($value -notmatch '^[a-zA-Z0-9.-]+:[0-9]{1,5}$' -or [int]($value.Split(':')[-1]) -notin 1..65535) { throw 'Enter phone IP:port, for example 192.168.1.20:5555.' }
    Save-Settings; Begin-Adb @('connect',$value) 'connect'
}
$null=Button 'USB → Wi-Fi' 458 358 140 { Mirror $false $true }
$null=Button 'Pair device' 610 358 124 {
    $dialog=New-Object System.Windows.Forms.Form; $dialog.Text='Pair Wireless debugging'; $dialog.ClientSize=New-Object System.Drawing.Size(430,180); $dialog.StartPosition='CenterParent'
    $hint=New-Object System.Windows.Forms.Label; $hint.Text='On phone: Wireless debugging → Pair with pairing code.'; $hint.SetBounds(15,12,405,40); $dialog.Controls.Add($hint)
    $endpoint=New-Object System.Windows.Forms.TextBox; $endpoint.SetBounds(15,55,395,28); $dialog.Controls.Add($endpoint)
    $code=New-Object System.Windows.Forms.TextBox; $code.SetBounds(15,90,200,28); $code.UseSystemPasswordChar=$true; $dialog.Controls.Add($code)
    $ok=New-Object System.Windows.Forms.Button; $ok.Text='Pair'; $ok.SetBounds(290,130,120,32); $ok.DialogResult='OK'; $dialog.Controls.Add($ok); $dialog.AcceptButton=$ok
    if ($dialog.ShowDialog($form) -eq 'OK') {
        if ($endpoint.Text -notmatch '^[a-zA-Z0-9.-]+:[0-9]{1,5}$' -or $code.Text -notmatch '^\d{6}$') { throw 'Enter the pairing IP:port and six-digit code shown on your phone.' }
        Begin-Adb @('pair',$endpoint.Text,$code.Text) 'pair'
    }
    $dialog.Dispose()
}
$null=Label 'Pairing uses a different port. Then connect using the main Wireless debugging IP:port.' 24 400
$null=Button 'Disconnect Wi-Fi' 24 437 165 {
    $serial=Selected-Serial; if (!$serial.Contains(':')) { throw 'Select a Wi-Fi device to disconnect.' }; Begin-Adb @('disconnect',$serial) 'disconnect'
}
$null=Button 'Screenshot' 205 437 165 {
    $serial=Selected-Serial
    $script:shotRemote='/data/local/tmp/scrcpy-control-' + [Guid]::NewGuid().ToString('N') + '.png'
    $script:shotLocal=Join-Path $dataDir ('Screenshot-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.png')
    Begin-Adb @('-s',$serial,'shell','screencap','-p',$script:shotRemote) 'shot'
    $script:pending.Serial=$serial
}
$null=Button 'Home' 386 437 105 { Begin-Adb @('-s',(Selected-Serial),'shell','input','keyevent','3') 'key' }
$null=Button 'Volume −' 501 437 110 { Begin-Adb @('-s',(Selected-Serial),'shell','input','keyevent','25') 'key' }
$null=Button 'Volume +' 621 437 113 { Begin-Adb @('-s',(Selected-Serial),'shell','input','keyevent','24') 'key' }
$null=Label 'In mirror: Alt+F fullscreen • Alt+O screen off • Alt+Shift+O screen on • Alt+B back' 24 486
$null=Label 'Recording begins with a new session. Stop finishes it. Settings apply on next start.' 24 513
$status=Label 'Ready. Connect your phone and click Refresh.' 24 550
$log=New-Object System.Windows.Forms.TextBox; $log.Multiline=$true; $log.ReadOnly=$true; $log.ScrollBars='Vertical'; $log.SetBounds(24,583,710,112); $form.Controls.Add($log)
$timer=New-Object System.Windows.Forms.Timer; $timer.Interval=300
$timer.Add_Tick({
    try {
        if ($script:pending) {
            $job=$script:pending
            if (!$job.Process.HasExited -and ([DateTime]::Now-$job.Started).TotalSeconds -gt 25) { $job.Process.Kill(); Log 'Device operation timed out. Check cable, phone authorization, address, and network.' }
            if ($job.Process.HasExited -and $job.Out.IsCompleted -and $job.Err.IsCompleted) {
                $script:pending=$null; $output=$job.Out.Result + $job.Err.Result
                if ($job.Process.ExitCode -ne 0) { Log ('Operation failed: ' + $output); return }
                switch ($job.Action) {
                    'devices' {
                        $devices.Items.Clear(); $script:serials=@()
                        foreach ($line in ($output -split "`r?`n")) {
                            if ($line -match '^(\S+)\s+device\s*(.*)$') { $script:serials += $Matches[1]; $null=$devices.Items.Add($Matches[1]+'  '+$Matches[2]) }
                            elseif ($line -match '^(\S+)\s+(unauthorized|offline)') { Log ($Matches[1] + ': ' + $Matches[2] + '. Unlock phone and approve USB debugging; reconnect if offline.') }
                        }
                        if ($devices.Items.Count) { $devices.SelectedIndex=0; Log 'Device list refreshed.' } else { Log 'No ready devices. Enable USB debugging, connect a data cable, and approve this PC on the phone.' }
                    }
                    'connect' { Log $output; Begin-Adb @('devices','-l') 'devices' }
                    'disconnect' { Log $output; Begin-Adb @('devices','-l') 'devices' }
                    'pair' { Log ($output + ' Connect using the main Wireless debugging address next.') }
                    'shot' { Begin-Adb @('-s',$job.Serial,'pull',$script:shotRemote,$script:shotLocal) 'pull'; $script:pending.Serial=$job.Serial }
                    'pull' { Log ('Screenshot saved: ' + $script:shotLocal); Begin-Adb @('-s',$job.Serial,'shell','rm',$script:shotRemote) 'cleanup' }
                    'cleanup' { }
                    default { Log 'Done.' }
                }
                $job.Process.Dispose()
            }
        }
        if ($script:session -and $script:session.Process.HasExited -and $script:session.Out.IsCompleted -and $script:session.Err.IsCompleted) {
            $job=$script:session; $script:session=$null
            Log ($job.Out.Result + $job.Err.Result)
            if ($job.Process.ExitCode -eq 0) { Log 'Session finished. Recordings and screenshots are in Saved.' } else { Log 'Session ended with an error. See the log above for details; verify device authorization and connection.' }
            $job.Process.Dispose()
        }
    } catch { Log $_.Exception.Message }
})
$form.Add_FormClosing({
    if ($script:session -and !$script:session.Process.HasExited) { $_.Cancel=$true; Stop-Mirror; Log 'Wait for the session to finish, then close the panel.' }
    else { Save-Settings; $timer.Stop(); if ($script:pending -and !$script:pending.Process.HasExited) { $script:pending.Process.Kill() } }
})
# Modern desktop layout. Existing handlers and device operations are preserved.
[System.Windows.Forms.Application]::EnableVisualStyles()
$form.Text = 'Phone Mirror'
$form.ClientSize = New-Object System.Drawing.Size(1040,820)
$form.AutoScaleMode = 'Dpi'
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#0D111B')
$form.ForeColor = [Drawing.ColorTranslator]::FromHtml('#EDF2FA')
$form.Font = New-Object Drawing.Font('Segoe UI',10)
$surface = [Drawing.ColorTranslator]::FromHtml('#171E2D')
$muted = [Drawing.ColorTranslator]::FromHtml('#A7B3C8')
$accent = [Drawing.ColorTranslator]::FromHtml('#7C9AFF')
$script:roundControls = @()
function Round-Control($control, [int]$radius=14) {
    $path=New-Object Drawing.Drawing2D.GraphicsPath
    $d=$radius*2; $w=$control.Width; $h=$control.Height
    $path.AddArc(0,0,$d,$d,180,90); $path.AddArc($w-$d,0,$d,$d,270,90)
    $path.AddArc($w-$d,$h-$d,$d,$d,0,90); $path.AddArc(0,$h-$d,$d,$d,90,90); $path.CloseFigure()
    $control.Region=New-Object Drawing.Region($path); $path.Dispose()
}
function Card([int]$x,[int]$y,[int]$w,[int]$h) {
    $panel=New-Object Windows.Forms.Panel; $panel.SetBounds($x,$y,$w,$h); $panel.BackColor=$surface
    $children=@($form.Controls | Where-Object { $_.Left -ge $x -and $_.Top -ge $y -and ($_.Right -le ($x+$w)) -and ($_.Bottom -le ($y+$h)) }); $form.Controls.Add($panel); Round-Control $panel 20; foreach ($child in $children) { $cx=$child.Left-$x; $cy=$child.Top-$y; $panel.Controls.Add($child); $child.Location=New-Object Drawing.Point($cx,$cy) }; $panel.SendToBack()
}
function Move-Control($c,[int]$x,[int]$y,[int]$w,[int]$h) { $c.SetBounds($x,$y,$w,$h) }
foreach ($c in @($form.Controls)) {
    $c.ForeColor=$form.ForeColor
    if ($c -is [Windows.Forms.Button]) {
        $c.FlatStyle='Flat'; $c.FlatAppearance.BorderSize=0
        $c.BackColor=[Drawing.ColorTranslator]::FromHtml('#26334A')
        $c.FlatAppearance.MouseOverBackColor=[Drawing.ColorTranslator]::FromHtml('#354563')
        $c.Cursor=[Windows.Forms.Cursors]::Hand
        $c.Font=New-Object Drawing.Font('Segoe UI Semibold',10)
        switch ($c.Text) {
            'Refresh' { Move-Control $c 375 228 109 40 }
            'Start mirror' { Move-Control $c 64 520 205 48; $c.BackColor=$accent; $c.ForeColor=[Drawing.ColorTranslator]::FromHtml('#0D1424'); $c.FlatAppearance.MouseOverBackColor=[Drawing.ColorTranslator]::FromHtml('#9DB2FF') }
            'Start recording' { Move-Control $c 281 520 203 48 }
            'Stop session' { Move-Control $c 64 581 205 40; $c.ForeColor=[Drawing.ColorTranslator]::FromHtml('#FFA3AD') }
            'Open saved files' { Move-Control $c 281 581 203 40 }
            'Connect address' { Move-Control $c 754 310 222 42; $c.Text='Connect to phone' }
            'USB → Wi-Fi' { Move-Control $c 556 226 203 44; $c.Text='Switch USB to Wi-Fi' }
            'Pair device' { Move-Control $c 771 226 205 44 }
            'Disconnect Wi-Fi' { Move-Control $c 556 403 420 38 }
            'Screenshot' { Move-Control $c 556 520 420 44; $c.Text='Save screenshot' }
            'Home' { Move-Control $c 556 579 130 42 }
            'Volume −' { Move-Control $c 701 579 130 42 }
            'Volume +' { Move-Control $c 846 579 130 42 }
        }
        Round-Control $c 10
    } elseif ($c -is [Windows.Forms.Label]) {
        $c.BackColor=[Drawing.Color]::Transparent; $c.ForeColor=$muted
        switch -Wildcard ($c.Text) {
            'PHONE MIRROR' { $c.Text='Phone Mirror'; Move-Control $c 40 29 650 48; $c.Font=New-Object Drawing.Font('Segoe UI Semibold',27); $c.ForeColor=$form.ForeColor }
            'Connect your Android*' { $c.Text='Your phone. A bigger screen. Everything within reach.'; Move-Control $c 44 86 720 30; $c.Font=New-Object Drawing.Font('Segoe UI',12) }
            'USB: enable*' { $c.Text='Enable USB debugging and approve this computer on your phone.'; Move-Control $c 64 183 420 40 }
            'Quality' { $c.Text='STREAM QUALITY'; Move-Control $c 64 296 420 25; $c.Font=New-Object Drawing.Font('Segoe UI Semibold',9) }
            'WI-FI CONNECTION' { $c.Text='Wireless connection'; Move-Control $c 556 150 420 30; $c.Font=New-Object Drawing.Font('Segoe UI Semibold',16); $c.ForeColor=$form.ForeColor }
            'Same network:*' { $c.Text='Use the same Wi-Fi network as your phone.'; Move-Control $c 556 185 420 28 }
            'Pairing uses*' { $c.Text='For Android Wireless debugging, pair first. Then enter the main connection IP:port (not the pairing port).'; Move-Control $c 556 363 420 36; $c.Font=New-Object Drawing.Font('Segoe UI',9) }
            'In mirror:*' { $c.Text='Alt+F  Fullscreen     Alt+O  Screen off     Alt+B  Back'; Move-Control $c 64 636 420 30; $c.Font=New-Object Drawing.Font('Segoe UI',9) }
            'Recording begins*' { $c.Text='Recording starts a new session. Stop saves the video.'; Move-Control $c 64 478 420 30; $c.Font=New-Object Drawing.Font('Segoe UI',9) }
        }
    } elseif ($c -is [Windows.Forms.ComboBox] -or $c -is [Windows.Forms.TextBox]) {
        $c.BackColor=[Drawing.ColorTranslator]::FromHtml('#222D40'); $c.ForeColor=$form.ForeColor
        if ($c -is [Windows.Forms.ComboBox]) { $c.FlatStyle='Flat'; $c.DrawMode='OwnerDrawFixed'; $c.ItemHeight=25; $c.Add_DrawItem({ param($sender,$eventArgs) $brush=New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#222D40')); $eventArgs.Graphics.FillRectangle($brush,$eventArgs.Bounds); $brush.Dispose(); if ($eventArgs.Index -ge 0) { [Windows.Forms.TextRenderer]::DrawText($eventArgs.Graphics,[string]$sender.Items[$eventArgs.Index],$sender.Font,$eventArgs.Bounds,[Drawing.ColorTranslator]::FromHtml('#EDF2FA'),[Windows.Forms.TextFormatFlags]::VerticalCenter) } }) } else { $c.BorderStyle='FixedSingle' }
    } elseif ($c -is [Windows.Forms.CheckBox]) {
        $c.BackColor=$surface; $c.Cursor=[Windows.Forms.Cursors]::Hand
    }
}
Move-Control $devices 64 232 295 32
Move-Control $preset 64 331 420 32
Move-Control $fullscreen 64 391 210 28
Move-Control $screenOff 281 391 203 28
Move-Control $top 64 430 210 28
Move-Control $audio 281 430 203 28
Move-Control $address 556 315 184 32
Move-Control $status 64 700 912 26
$status.ForeColor=[Drawing.ColorTranslator]::FromHtml('#A8DFC8')
Move-Control $log 64 735 912 55
$log.BackColor=$surface; $log.BorderStyle='None'; $log.Font=New-Object Drawing.Font('Consolas',9); $log.ForeColor=$muted
$deviceHeading=Label 'Device & session' 64 150 420
$deviceHeading.Font=New-Object Drawing.Font('Segoe UI Semibold',16); $deviceHeading.ForeColor=$form.ForeColor; $deviceHeading.BackColor=[Drawing.Color]::Transparent; $deviceHeading.Height=32
$quickHeading=Label 'Quick actions' 556 469 420
$quickHeading.Font=New-Object Drawing.Font('Segoe UI Semibold',16); $quickHeading.ForeColor=$form.ForeColor; $quickHeading.BackColor=[Drawing.Color]::Transparent; $quickHeading.Height=32
$badge=Label 'BASED ON SCRCPY 4.0' 792 55 220
$badge.Font=New-Object Drawing.Font('Segoe UI Semibold',9); $badge.ForeColor=$accent; $badge.BackColor=[Drawing.Color]::Transparent
$ipHint=Label 'PHONE IP : PORT' 556 286 420
$ipHint.Font=New-Object Drawing.Font('Segoe UI Semibold',9); $ipHint.ForeColor=$muted; $ipHint.BackColor=[Drawing.Color]::Transparent
Card 40 134 468 537
Card 532 134 468 322
Card 532 469 468 202
Card 40 686 960 118
$quickHeading.Top=10

if ($SmokeTest) { $form.Add_Shown({ $bmp=New-Object Drawing.Bitmap($form.Width,$form.Height); $form.DrawToBitmap($bmp,(New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height))); $bmp.Save((Join-Path $PSScriptRoot "UI-preview.png")); $bmp.Dispose(); $form.Close() }) }
$timer.Start()
[System.Windows.Forms.Application]::Run($form)
$timer.Dispose(); $form.Dispose()
