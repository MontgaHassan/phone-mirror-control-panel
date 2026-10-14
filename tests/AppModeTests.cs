using System;
using System.Collections;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;
class AppModeTests {
    static void Assert(bool value,string message){if(!value)throw new Exception(message);}
    static object Field(object obj,string name){return obj.GetType().GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).GetValue(obj);}
    [STAThread] static int Main(string[] args) {
        var assembly=Assembly.LoadFrom(args[0]);var appType=assembly.GetType("AppEntry");
        var sample="scrcpy 4.0\nINFO: List of apps:\n * Settings                       com.android.settings\n - صيدلية                         com.example.pharmacy\n - A very long application title that wraps\n                                  com.example.longname\n - Settings                       com.android.settings\n";
        var items=(IList)appType.GetMethod("Parse").Invoke(null,new object[]{sample});
        Assert(items.Count==3,"App parser should handle system apps, Unicode, wrapping, and duplicates.");
        Assert(items.Cast<object>().Any(x=>(string)appType.GetField("Package").GetValue(x)=="com.example.longname"),"Wrapped app package was lost.");
        var options=(string[])appType.GetMethod("DisplayArguments").Invoke(null,new object[]{"com.example.pharmacy"});
        Assert(options.Contains("--new-display")&&options.Contains("--start-app=com.example.pharmacy"),"App mode must use a new display with the exact package.");
        Assert(options.Contains("--no-vd-system-decorations")&&options.Contains("--no-audio"),"App mode must omit main-display decorations and system audio.");
        foreach(var bad in new[]{"",null,"com.app;other","com.app\"","?browser"}) {
            bool rejected=false;try{appType.GetMethod("DisplayArguments").Invoke(null,new object[]{bad});}catch(TargetInvocationException){rejected=true;}Assert(rejected,"Invalid/unselected package must not fall back to full-phone mirroring.");
        }
        using(var form=(Form)Activator.CreateInstance(assembly.GetType("MirrorForm"),new object[]{true})) {
            var source=(ComboBox)Field(form,"source");source.SelectedIndex=1;
            Assert(!((Button)Field(form,"screenshot")).Enabled,"Main-phone screenshot must be disabled in app mode.");
            Assert(!((Button)Field(form,"home")).Enabled,"Main-phone Home must be disabled in app mode.");
            Assert(!((CheckBox)Field(form,"audio")).Checked&&!((CheckBox)Field(form,"audio")).Enabled,"Whole-phone audio must be off in app mode.");
            Assert(((Button)Field(form,"loadApps")).Enabled,"App listing must be enabled in app mode.");
            source.SelectedIndex=0;
            Assert(((Button)Field(form,"screenshot")).Enabled&&((Button)Field(form,"home")).Enabled,"Full-phone controls should be restored in full-phone mode.");
        }
        Console.WriteLine("Passed: app parsing, exact virtual-display options, invalid-package rejection, and mode-specific UI controls.");return 0;
    }
}
