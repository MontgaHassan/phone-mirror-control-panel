// Phone Mirror: native Windows UI based on scrcpy. Licensed under Apache 2.0.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Xml.Linq;
using System.Reflection;

[assembly: AssemblyTitle("Phone Mirror")]
[assembly: AssemblyDescription("Native Windows control panel based on scrcpy")]
[assembly: AssemblyProduct("Phone Mirror Control Panel")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

sealed class Job : IDisposable {
    public Process Process;
    public Task<string> Output, Error;
    public Job(string file, string directory, IEnumerable<string> args) {
        var info = new ProcessStartInfo(file, String.Join(" ", args.Select(Quote))) {
            WorkingDirectory=directory, UseShellExecute=false, CreateNoWindow=true,
            RedirectStandardOutput=true, RedirectStandardError=true
        };
        info.EnvironmentVariables["ADB"] = Path.Combine(directory,"adb.exe");
        info.EnvironmentVariables["SCRCPY_SERVER_PATH"] = Path.Combine(directory,"scrcpy-server");
        Process = new Process { StartInfo=info };
        Process.Start(); Output=Process.StandardOutput.ReadToEndAsync(); Error=Process.StandardError.ReadToEndAsync();
    }
    // Standard Windows argv quoting; arguments never pass through a command shell.
    public static string Quote(string value) {
        var result=new StringBuilder("\""); int slashes=0;
        foreach (char c in value) {
            if (c=='\\') { slashes++; continue; }
            if (c=='"') { result.Append('\\',slashes*2+1); result.Append(c); }
            else { result.Append('\\',slashes); result.Append(c); }
            slashes=0;
        }
        result.Append('\\',slashes*2); return result.Append('"').ToString();
    }
    public async Task<string> Finish(int timeout) {
        if (!await Task.Run(()=>Process.WaitForExit(timeout))) {
            Process.Kill(); await Task.WhenAll(Output,Error);
            throw new TimeoutException("Device operation timed out. Check the cable, phone approval, IP address, and network.");
        }
        var text=await Output + await Error;
        if (Process.ExitCode!=0) throw new InvalidOperationException(text.Trim());
        return text.Trim();
    }
    public void Dispose() { Process.Dispose(); }
}

sealed class Device {
    public string Serial, Description;
    public override string ToString() { return Description; }
}

sealed class RoundedPanel : Panel {
    public RoundedPanel() { DoubleBuffered=true; }
    protected override void OnSizeChanged(EventArgs e) {
        base.OnSizeChanged(e); if (Width<40 || Height<40) return;
        using(var p=new GraphicsPath()) {
            const int d=28; p.AddArc(0,0,d,d,180,90); p.AddArc(Width-d,0,d,d,270,90);
            p.AddArc(Width-d,Height-d,d,d,0,90); p.AddArc(0,Height-d,d,d,90,90); p.CloseFigure();
            var old=Region; Region=new Region(p); if(old!=null)old.Dispose();
        }
    }
}

sealed class MirrorForm : Form {
    readonly string toolDir, savedDir, settingsFile;
    readonly Color background=ColorTranslator.FromHtml("#0D111B"), surface=ColorTranslator.FromHtml("#171E2D"),
        muted=ColorTranslator.FromHtml("#A7B3C8"), accent=ColorTranslator.FromHtml("#7C9AFF"), field=ColorTranslator.FromHtml("#222D40");
    ComboBox devices, quality;
    TextBox address, log;
    Label status;
    CheckBox full, off, top, audio;
    Button start, record, stop;
    Job session, activeAdb;
    bool busy, closing;
    readonly bool smoke;
    public MirrorForm(bool smokeTest) {
        smoke=smokeTest; toolDir=Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"vendor","scrcpy");
        savedDir=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"PhoneMirror","Saved");
        settingsFile=Path.Combine(savedDir,"settings.xml");
        Text="Phone Mirror"; ClientSize=new Size(1040,820); BackColor=background; ForeColor=Color.FromArgb(237,242,250);
        Font=new Font("Segoe UI",10); StartPosition=FormStartPosition.CenterScreen; FormBorderStyle=FormBorderStyle.FixedSingle;
        MaximizeBox=false; AutoScaleMode=AutoScaleMode.Dpi;
        LabelAt(this,"Phone Mirror",40,28,700,52,27,true);
        LabelAt(this,"Your phone. A bigger screen. Everything within reach.",44,86,720,30,12,false);
        var badge=LabelAt(this,"BASED ON SCRCPY 4.0",792,55,225,30,9,true); badge.ForeColor=accent;
        var left=Card(40,134,468,537); var wireless=Card(532,134,468,322); var actions=Card(532,469,468,202); var activity=Card(40,686,960,118);
        LabelAt(left,"Device & session",24,16,420,32,16,true);
        LabelAt(left,"Enable USB debugging and approve this computer on your phone.",24,51,420,40,10,false);
        devices=Combo(left,24,98,295); ButtonAt(left,"Refresh",335,94,109,40,RefreshDevices);
        LabelAt(left,"STREAM QUALITY",24,162,420,25,9,true).ForeColor=muted;
        quality=Combo(left,24,197,420); quality.Items.AddRange(new object[]{"Sharp","Balanced","Low delay"}); quality.SelectedIndex=1;
        full=Check(left,"Start fullscreen",24,257,false); off=Check(left,"Phone screen off",241,257,false);
        top=Check(left,"Always on top",24,296,false); audio=Check(left,"Forward audio",241,296,true);
        LabelAt(left,"Recording starts a new session. Stop saves the video.",24,344,420,30,9,false);
        start=ButtonAt(left,"Start mirror",24,386,205,48,()=>Mirror(false,false)); start.BackColor=accent; start.ForeColor=background;
        record=ButtonAt(left,"Start recording",241,386,203,48,()=>Mirror(true,false));
        stop=ButtonAt(left,"Stop session",24,447,205,40,()=>{StopMirror();return Task.FromResult(0);}); stop.ForeColor=Color.FromArgb(255,163,173); stop.Enabled=false;
        ButtonAt(left,"Open saved files",241,447,203,40,()=>{Directory.CreateDirectory(savedDir); Process.Start(new ProcessStartInfo("explorer.exe",Job.Quote(savedDir)){UseShellExecute=true});return Task.FromResult(0);});
        LabelAt(left,"Alt+F  Fullscreen     Alt+O  Screen off     Alt+B  Back",24,502,420,30,9,false);
        LabelAt(wireless,"Wireless connection",24,16,420,32,16,true);
        LabelAt(wireless,"Use the same Wi-Fi network as your phone.",24,51,420,28,10,false);
        ButtonAt(wireless,"Switch USB to Wi-Fi",24,92,203,44,()=>Mirror(false,true)); ButtonAt(wireless,"Pair device",239,92,205,44,Pair);
        LabelAt(wireless,"PHONE IP : PORT",24,152,420,25,9,true).ForeColor=muted;
        address=Input(wireless,24,181,184);
        ButtonAt(wireless,"Connect to phone",222,176,222,42,async()=>{ string endpoint=Endpoint(address.Text); Save(); await Adb("connect",endpoint); await RefreshDevices(); });
        LabelAt(wireless,"For Android Wireless debugging, pair first. Then enter the main connection IP:port (not the pairing port).",24,229,420,36,9,false);
        ButtonAt(wireless,"Disconnect Wi-Fi",24,269,420,38,async()=>{string serial=Selected();if(!serial.Contains(":"))throw new Exception("Select a Wi-Fi device first.");await Adb("disconnect",serial);await RefreshDevices();});
        LabelAt(actions,"Quick actions",24,10,420,32,16,true);
        ButtonAt(actions,"Save screenshot",24,51,420,44,Screenshot);
        ButtonAt(actions,"Home",24,110,130,42,()=>Key("3")); ButtonAt(actions,"Volume −",169,110,130,42,()=>Key("25")); ButtonAt(actions,"Volume +",314,110,130,42,()=>Key("24"));
        status=LabelAt(activity,"Ready. Connect your phone and click Refresh.",24,14,912,26,10,false);status.ForeColor=Color.FromArgb(168,223,200);
        log=Input(activity,24,49,912); log.Height=55; log.Multiline=true; log.ReadOnly=true; log.BorderStyle=BorderStyle.None;log.BackColor=surface; log.ScrollBars=ScrollBars.Vertical;log.Font=new Font("Consolas",9);
        try { if(File.Exists(settingsFile)){var xml=XElement.Load(settingsFile); address.Text=(string)xml.Element("Address")??""; var preset=(string)xml.Element("Preset"); if(quality.Items.Contains(preset))quality.SelectedItem=preset;} } catch { }
        FormClosing+=OnClosing;
        Shown+=async delegate {
            if(smoke) { using(var bmp=new Bitmap(Width,Height)){DrawToBitmap(bmp,new Rectangle(0,0,Width,Height));bmp.Save(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"UI-preview.png"));} Close();return; }
            await Guard(RefreshDevices);
        };
    }
    RoundedPanel Card(int x,int y,int w,int h){var p=new RoundedPanel{BackColor=surface};p.SetBounds(x,y,w,h);Controls.Add(p);return p;}
    Label LabelAt(Control parent,string text,int x,int y,int w,int h,int size,bool bold){var c=new Label{Text=text,ForeColor=bold?ForeColor:muted,BackColor=Color.Transparent,Font=new Font(bold?"Segoe UI Semibold":"Segoe UI",size)};c.SetBounds(x,y,w,h);parent.Controls.Add(c);return c;}
    TextBox Input(Control parent,int x,int y,int w){var c=new TextBox{BackColor=field,ForeColor=ForeColor,BorderStyle=BorderStyle.FixedSingle};c.SetBounds(x,y,w,32);parent.Controls.Add(c);return c;}
    ComboBox Combo(Control parent,int x,int y,int w){var c=new ComboBox{DropDownStyle=ComboBoxStyle.DropDownList,FlatStyle=FlatStyle.Flat,DrawMode=DrawMode.OwnerDrawFixed,ItemHeight=25,BackColor=field,ForeColor=ForeColor};c.SetBounds(x,y,w,32);c.DrawItem+=(s,e)=>{using(var b=new SolidBrush(field))e.Graphics.FillRectangle(b,e.Bounds);if(e.Index>=0)TextRenderer.DrawText(e.Graphics,c.Items[e.Index].ToString(),c.Font,e.Bounds,ForeColor,TextFormatFlags.VerticalCenter);};parent.Controls.Add(c);return c;}
    CheckBox Check(Control parent,string text,int x,int y,bool value){var c=new CheckBox{Text=text,Checked=value,ForeColor=ForeColor,Cursor=Cursors.Hand};c.SetBounds(x,y,203,28);parent.Controls.Add(c);return c;}
    Button ButtonAt(Control parent,string text,int x,int y,int w,int h,Func<Task> action){var c=new Button{Text=text,FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(38,51,74),ForeColor=ForeColor,Font=new Font("Segoe UI Semibold",10),Cursor=Cursors.Hand};c.FlatAppearance.BorderSize=0;c.FlatAppearance.MouseOverBackColor=Color.FromArgb(53,69,99);c.SetBounds(x,y,w,h);parent.Controls.Add(c);c.Click+=async(s,e)=>await Guard(action);return c;}
    async Task Guard(Func<Task> action){try{await action();}catch(Exception ex){if(!IsDisposed)Log(ex.Message);}}
    void Log(string message){if(IsDisposed)return;log.AppendText(message+Environment.NewLine);status.Text=message.Split('\n')[0].Trim();}
    string Selected(){var d=devices.SelectedItem as Device;if(d==null)throw new Exception("Select a ready device. Connect a data cable, approve USB debugging, and click Refresh.");return d.Serial;}
    static string Endpoint(string value){value=value.Trim();int port;var match=Regex.Match(value,@"^([a-zA-Z0-9.-]+):(\d{1,5})$");if(!match.Success||!Int32.TryParse(match.Groups[2].Value,out port)||port<1||port>65535)throw new Exception("Enter phone IP:port, for example 192.168.1.20:5555.");return value;}
    void Save(){Directory.CreateDirectory(savedDir);new XElement("Settings",new XElement("Address",address.Text.Trim()),new XElement("Preset",quality.SelectedItem??"Balanced")).Save(settingsFile);}
    async Task<string> Adb(params string[] args){if(busy)throw new Exception("Wait for the current device operation to finish.");busy=true;try{using(var job=new Job(Path.Combine(toolDir,"adb.exe"),toolDir,args)){activeAdb=job;var output=await job.Finish(25000);if(output.Length>0)Log(output);return output;}}finally{activeAdb=null;busy=false;}}
    async Task RefreshDevices(){string selected=devices.SelectedItem is Device?((Device)devices.SelectedItem).Serial:null;string output=await Adb("devices","-l");devices.Items.Clear();foreach(var line in output.Split('\n')){var m=Regex.Match(line.Trim(),@"^(\S+)\s+device\s*(.*)$");if(m.Success){var d=new Device{Serial=m.Groups[1].Value,Description=m.Groups[1].Value+"  "+m.Groups[2].Value};devices.Items.Add(d);if(d.Serial==selected)devices.SelectedItem=d;}else if(Regex.IsMatch(line,@"\s(unauthorized|offline)"))Log(line.Trim()+" — unlock phone and approve debugging, or reconnect.");}if(devices.SelectedIndex<0&&devices.Items.Count>0)devices.SelectedIndex=0;Log(devices.Items.Count>0?"Device list refreshed.":"No ready devices. Enable USB debugging, connect a data cable, and approve this PC.");}
    async Task Mirror(bool recording,bool wifi){if(session!=null)throw new Exception("Stop the current session first.");var args=new List<string>{"--serial",Selected(),"--window-title=Phone Mirror","--shortcut-mod=lalt","--disable-screensaver"};string preset=quality.SelectedItem.ToString();args.AddRange(preset=="Sharp"?new[]{"--max-size=1920","--video-bit-rate=12M","--max-fps=60"}:preset=="Low delay"?new[]{"--max-size=1024","--video-bit-rate=4M","--max-fps=60","--video-buffer=0"}:new[]{"--max-size=1280","--video-bit-rate=8M","--max-fps=60"});if(full.Checked)args.Add("--fullscreen");if(off.Checked)args.Add("--turn-screen-off");if(top.Checked)args.Add("--always-on-top");if(!audio.Checked)args.Add("--no-audio");if(wifi)args.Add("--tcpip");Save();string file=null;if(recording){file=Path.Combine(savedDir,"Recording-"+DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+".mkv");args.Add("--record="+file);}var job=new Job(Path.Combine(toolDir,"scrcpy.exe"),toolDir,args);session=job;start.Enabled=record.Enabled=false;stop.Enabled=true;Log(recording?"Recording started. Stop finishes and saves the video.":"Starting mirror…");try{await Task.Run(()=>job.Process.WaitForExit());string output=await job.Output+await job.Error;if(!IsDisposed){Log(output.Trim());Log(job.Process.ExitCode==0?(file==null?"Session finished.":"Recording saved: "+file):"Session ended with an error. Check the activity log.");}}finally{session=null;job.Dispose();if(!IsDisposed){start.Enabled=record.Enabled=true;stop.Enabled=false;if(closing)Close();}}}
    void StopMirror(){if(session==null)return;if(!session.Process.HasExited){if(!session.Process.CloseMainWindow()){Log("Mirror is still starting. Wait, then click Stop again.");return;}Log("Closing mirror and finalizing recording…");}}
    Task Key(string code){return Adb("-s",Selected(),"shell","input","keyevent",code);}
    async Task Screenshot(){string serial=Selected(),remote="/data/local/tmp/phone-mirror-"+Guid.NewGuid().ToString("N")+".png";Directory.CreateDirectory(savedDir);string file=Path.Combine(savedDir,"Screenshot-"+DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+".png");Exception failure=null;try{await Adb("-s",serial,"shell","screencap","-p",remote);await Adb("-s",serial,"pull",remote,file);Log("Screenshot saved: "+file);}catch(Exception ex){failure=ex;}try{await Adb("-s",serial,"shell","rm",remote);}catch{}if(failure!=null)throw failure;}
    async Task Pair(){using(var dialog=new Form{Text="Pair Wireless debugging",ClientSize=new Size(440,220),StartPosition=FormStartPosition.CenterParent,BackColor=background,ForeColor=ForeColor,Font=Font,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,MinimizeBox=false}){LabelAt(dialog,"Phone: Wireless debugging → Pair with pairing code",20,15,400,45,10,false);LabelAt(dialog,"Pairing IP:port",20,60,170,24,9,false);var endpoint=Input(dialog,20,85,400);LabelAt(dialog,"Six-digit pairing code",20,120,250,24,9,false);var code=Input(dialog,20,145,230);code.UseSystemPasswordChar=true;var button=new Button{Text="Pair",DialogResult=DialogResult.OK,BackColor=accent,FlatStyle=FlatStyle.Flat};button.SetBounds(285,165,135,35);dialog.Controls.Add(button);dialog.AcceptButton=button;if(dialog.ShowDialog(this)!=DialogResult.OK)return;string target=Endpoint(endpoint.Text);if(!Regex.IsMatch(code.Text,@"^\d{6}$"))throw new Exception("Enter the six-digit code shown on your phone.");var output=await Adb("pair",target,code.Text);if(output.IndexOf("Successfully paired",StringComparison.OrdinalIgnoreCase)<0)throw new Exception("Pairing was not confirmed. Check the code and pairing port. "+output);Log("Pairing completed. Connect with the main Wireless debugging IP:port.");}}
    void OnClosing(object sender,FormClosingEventArgs e){if(session!=null){e.Cancel=true;closing=true;StopMirror();return;}if(activeAdb!=null&&!activeAdb.Process.HasExited){e.Cancel=true;Log("Wait for the device operation to finish before closing.");return;}if(!smoke)try{Save();}catch{}}
}

static class Program {
    [STAThread] static int Main(string[] args) {
        Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
        try {
            string root=AppDomain.CurrentDomain.BaseDirectory;
            foreach(string file in new[]{"scrcpy.exe","adb.exe","scrcpy-server"})if(!File.Exists(Path.Combine(root,"vendor","scrcpy",file)))throw new FileNotFoundException("Missing bundled file: "+file+". Extract the whole ZIP before launching Phone Mirror.");
            if(args.Contains("--validate")){File.WriteAllText(Path.Combine(root,"validation.txt"),"Bundled runtime files found. Native executable validation passed.");return 0;}
            using(var form=new MirrorForm(args.Contains("--smoke-test")))Application.Run(form);
            return 0;
        } catch(Exception ex) {
            if(args.Contains("--smoke-test")||args.Contains("--validate")){File.WriteAllText(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"validation-error.txt"),ex.ToString());return 1;}
            MessageBox.Show(ex.Message,"Phone Mirror",MessageBoxButtons.OK,MessageBoxIcon.Error);return 1;
        }
    }
}
