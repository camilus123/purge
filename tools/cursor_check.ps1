# Developer check: starts the release build the way a double-click would, waits, and reports
# whether Windows is still drawing a mouse cursor (and which one). Used to verify cursor capture.
[CmdletBinding(PositionalBinding = $false)]
param([double]$Wait = 7, [string]$Exe = (Join-Path $PSScriptRoot "..\build\purge.exe"))
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CursorProbe {
    [StructLayout(LayoutKind.Sequential)] public struct POINT { public int x; public int y; }
    [StructLayout(LayoutKind.Sequential)] public struct CURSORINFO { public int cbSize; public int flags; public IntPtr hCursor; public POINT pt; }
    [DllImport("user32.dll")] public static extern bool GetCursorInfo(ref CURSORINFO pci);
    [DllImport("user32.dll")] public static extern IntPtr LoadCursor(IntPtr hInstance, int name);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    public static string Probe() {
        CURSORINFO ci = new CURSORINFO(); ci.cbSize = Marshal.SizeOf(typeof(CURSORINFO));
        GetCursorInfo(ref ci);
        string name = "other";
        if (ci.hCursor == IntPtr.Zero) name = "none";
        else if (ci.hCursor == LoadCursor(IntPtr.Zero, 32512)) name = "arrow";
        else if (ci.hCursor == LoadCursor(IntPtr.Zero, 32514)) name = "wait ring";
        else if (ci.hCursor == LoadCursor(IntPtr.Zero, 32650)) name = "arrow with ring (app starting)";
        return "showing=" + ((ci.flags & 1) != 0) + " cursor=" + name + " at " + ci.pt.x + "," + ci.pt.y;
    }
}
"@
$p = Start-Process -FilePath $Exe -PassThru
foreach ($t in @(1.0, 2.0, ($Wait - 3.0))) {
	Start-Sleep -Seconds $t
	$fg = [CursorProbe]::GetForegroundWindow()
	Write-Host ("t+{0,4:n1}s  {1}  game_in_front={2}" -f ((Get-Date) - $p.StartTime).TotalSeconds, [CursorProbe]::Probe(), ($fg -eq $p.MainWindowHandle))
	$p.Refresh()
}
Stop-Process -Id $p.Id -Force
