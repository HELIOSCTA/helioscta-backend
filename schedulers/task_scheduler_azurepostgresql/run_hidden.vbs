' Runs a command with no visible window.
' Usage: wscript.exe run_hidden.vbs "cmd.exe /c ..."
WScript.Quit CreateObject("WScript.Shell").Run(WScript.Arguments(0), 0, True)
