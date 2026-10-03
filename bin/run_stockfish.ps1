param(
    [string]$Engine,
    [string]$CommandsFile,
    [string]$LogFile,
    [string]$DllPath,
    [int]$TimeoutMs = 20000
)
$ErrorActionPreference = "Stop"
try {
    if (-not (Test-Path -LiteralPath $DllPath)) {
        Add-Type -OutputAssembly $DllPath -OutputType Library -TypeDefinition @"
using System;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Threading;
public static class UciRun {
    public static int Run(string engine, string commandsFile, string logFile, int timeoutMs) {
        var psi = new ProcessStartInfo();
        psi.FileName = engine;
        psi.UseShellExecute = false;
        psi.RedirectStandardInput = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.CreateNoWindow = true;
        var p = new Process();
        p.StartInfo = psi;
        var sb = new StringBuilder();
        var gate = new object();
        var done = new ManualResetEvent(false);
        var latest = new System.Collections.Generic.Dictionary<int, string>();
        var pending = new StringBuilder();
        var lastFlush = DateTime.MinValue;
        Action flushLatest = delegate() {
            string[] rows;
            lock (gate) {
                rows = new string[latest.Count];
                latest.Values.CopyTo(rows, 0);
            }
            var snap = new StringBuilder();
            foreach (var row in rows)
                snap.AppendLine(row);
            try {
                using (var fs = new FileStream(logFile, FileMode.Create, FileAccess.Write, FileShare.ReadWrite))
                using (var sw = new StreamWriter(fs))
                    sw.Write(snap.ToString());
            } catch { }
        };
        Action flushPending = delegate() {
            string chunk;
            lock (gate) {
                if (pending.Length == 0) return;
                chunk = pending.ToString();
                pending.Length = 0;
            }
            try {
                using (var fs = new FileStream(logFile + ".stream", FileMode.Append, FileAccess.Write, FileShare.ReadWrite))
                using (var sw = new StreamWriter(fs))
                    sw.Write(chunk);
            } catch { }
        };
        p.OutputDataReceived += delegate(object s, DataReceivedEventArgs e) {
            if (e.Data == null) return;
            bool flush = false;
            lock (gate) {
                sb.AppendLine(e.Data);
                if (e.Data.Contains(" pv ")) {
                    int mpv = 1;
                    int mark = e.Data.IndexOf(" multipv ");
                    if (mark >= 0) {
                        int start = mark + 9;
                        int end = e.Data.IndexOf(' ', start);
                        string digits = end < 0 ? e.Data.Substring(start) : e.Data.Substring(start, end - start);
                        int parsed;
                        if (int.TryParse(digits, out parsed) && parsed > 0)
                            mpv = parsed;
                    }
                    latest[mpv] = e.Data;
                    pending.AppendLine(e.Data);
                    if ((DateTime.UtcNow - lastFlush).TotalMilliseconds >= 40.0) {
                        flush = true;
                        lastFlush = DateTime.UtcNow;
                    }
                }
            }
            if (flush) {
                flushLatest();
                flushPending();
            }
            if (e.Data.StartsWith("bestmove ")) {
                flushLatest();
                flushPending();
                done.Set();
            }
        };
        p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e) { };
        p.Start();
        p.BeginOutputReadLine();
        p.BeginErrorReadLine();
        foreach (var line in File.ReadAllLines(commandsFile))
            p.StandardInput.WriteLine(line);
        p.StandardInput.Flush();
        done.WaitOne(timeoutMs);
        try { p.StandardInput.WriteLine("quit"); p.StandardInput.Close(); } catch { }
        if (!p.WaitForExit(3000)) { try { p.Kill(); } catch { } }
        string text;
        lock (gate) { text = sb.ToString(); }
        try { File.WriteAllText(logFile + ".full", text); } catch { }
        return text.Contains("bestmove ") ? 0 : 2;
    }
}
"@
    }
    Add-Type -Path $DllPath
    $code = [UciRun]::Run($Engine, $CommandsFile, $LogFile, $TimeoutMs)
    exit $code
} catch {
    [System.IO.File]::WriteAllText($LogFile, ($_ | Out-String))
    exit 1
}
