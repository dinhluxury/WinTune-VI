using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
internal static class Launcher {
    [STAThread] private static int Main(string[] args) {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string script = Path.Combine(root, "WinTune.ps1");
        if (!File.Exists(script)) { MessageBox.Show("Thiếu WinTune.ps1. Hãy giải nén toàn bộ gói vào cùng một thư mục.", "WinTune VI"); return 1; }
        bool demo = Path.GetFileName(Application.ExecutablePath).IndexOf("Demo", StringComparison.OrdinalIgnoreCase) >= 0;
        bool probe = args.Length == 1 && args[0] == "/probe";
        bool updates = args.Length == 1 && args[0] == "/updates";
        if (args.Length > 0 && !probe && !updates) { MessageBox.Show("Tham số không được hỗ trợ.", "WinTune VI"); return 1; }
        string system = Environment.GetFolderPath(Environment.SpecialFolder.System);
        string host = Path.Combine(system, @"WindowsPowerShell\v1.0\powershell.exe");
        try {
            var info = new ProcessStartInfo(host, "-NoLogo -NoProfile -STA -ExecutionPolicy Bypass -File \"" + script + "\"" + (demo ? " -Simulation" : "") + (probe ? " -GuiProbe" : "") + (updates ? " -Updates" : ""));
            info.WorkingDirectory = root;
            info.UseShellExecute = false;
            info.CreateNoWindow = true;
            info.RedirectStandardError = probe;
            info.RedirectStandardOutput = probe;
            using (var process = Process.Start(info)) {
                if (!probe) return 0; // Release the small wrapper; PowerShell owns its WPF lifecycle/logs.
                var errors = process.StandardError.ReadToEndAsync();
                var output = process.StandardOutput.ReadToEndAsync();
                process.WaitForExit();
                string error = errors.Result;
                if (process.ExitCode != 0) {
                    try { File.WriteAllText(Path.Combine(root,"launcher-error.log"), error + Environment.NewLine + output.Result); } catch {}
                    Console.Error.WriteLine(error); // /probe must fail without a blocking dialog.
                }
                return process.ExitCode;
            }
        } catch (Exception ex) { MessageBox.Show(ex.Message, "WinTune VI"); return 1; }
    }
}
