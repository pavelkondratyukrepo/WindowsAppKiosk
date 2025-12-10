' Run-LogoffHidden.vbs
' Wrapper to run the PowerShell script hidden
' Usage: wscript.exe Run-LogoffHidden.vbs [IdleMinutes]

Option Explicit

Dim objShell, strPSFile, args, strCommand

Set objShell = CreateObject("WScript.Shell")

strPSFile = Replace(WScript.ScriptFullName, ".vbs", ".ps1")

' Get arguments (IdleMinutes)
args = ""
If WScript.Arguments.Count > 0 Then
    args = " -IdleMinutes " & WScript.Arguments(0)
End If

' Construct command
' -WindowStyle Hidden is added to PowerShell, and the VBS run method uses 0 (Hide)
strCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & strPSFile & """" & args

' Run hidden (0), don't wait (False)
objShell.Run strCommand, 0, False
