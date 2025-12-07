' Run Server Without Console Window
' Double-click this file to launch the server with NO console window
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run "godot --path """ & Replace(WScript.ScriptFullName, "\run_server.vbs", "") & """ res://source/server/server_world.tscn", 0, False
