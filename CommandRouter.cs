using System;
using System.IO;
using System.Diagnostics;
using System.Windows.Forms;
internal static class CommandRouter {
    static string Resolve() {
        string install = Directory.GetParent(AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar)).FullName;
        string current = Path.Combine(install, "current.txt");
        string app = Path.GetFullPath(File.ReadAllText(current).Trim());
        string apps = Path.Combine(install,"apps") + Path.DirectorySeparatorChar;
        if (!app.StartsWith(apps,StringComparison.OrdinalIgnoreCase)) throw new IOException("Đích mở nằm ngoài thư mục ứng dụng WinTune.");
        for(string p=app;!String.IsNullOrEmpty(p);p=Path.GetDirectoryName(p))
            if(Directory.Exists(p) && (File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0) throw new IOException("Không mở qua junction/symlink.");
        if(!File.Exists(Path.Combine(app,"WinTune.ps1"))) throw new IOException("Thiếu gói WinTune. Đăng ký lại từ bản portable đầy đủ.");
        return app;
    }
    [STAThread] static int Main(string[] args) {
        try {
            string mode=args.Length==0 ? "app" : args[0].ToLowerInvariant();
            if(args.Length>1 || (mode!="app" && mode!="demo" && mode!="update" && mode!="/probe" && mode!="/resolve" && mode!="help")) throw new ArgumentException("Dùng wintune, wintune demo hoặc wintune update.");
            if(mode=="help") {MessageBox.Show("wintune: mở ứng dụng\nwintune demo: mô phỏng\nwintune update: mở trang khởi chạy và cập nhật", "WinTune VI");return 0;}
            string root=Resolve();if(mode=="/resolve") {Console.WriteLine(root);return 0;}
            string exe=Path.Combine(root,mode=="demo" || mode=="/probe" ? "WinTune-Demo.exe" : "WinTune-VI.exe");
            var info=new ProcessStartInfo(exe,mode=="/probe" ? "/probe" : mode=="update" ? "/updates" : "");
            info.WorkingDirectory=root;info.UseShellExecute=false;
            using(var p=Process.Start(info)) {if(mode=="/probe") {p.WaitForExit();return p.ExitCode;}return 0;}
        } catch(Exception e) {MessageBox.Show(e.Message,"WinTune VI");return 1;}
    }
}
