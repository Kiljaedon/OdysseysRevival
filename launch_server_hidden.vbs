Option Explicit
Dim WshShell, exe, proj, scene, cmd
Set WshShell = CreateObject("WScript.Shell")
If WScript.Arguments.Count < 3 Then WScript.Quit
exe = WScript.Arguments(0)
proj = WScript.Arguments(1)
scene = WScript.Arguments(2)
' Build command line
cmd = Chr(34) & exe & Chr(34) & " --path " & Chr(34) & proj & Chr(34) & " " & scene
' Run with 0 (SW_HIDE) to hide the console window. 
' Godot GUI will still appear as it's a separate window.
WshShell.Run cmd, 0, False
