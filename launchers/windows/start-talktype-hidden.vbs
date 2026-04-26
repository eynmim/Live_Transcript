' start-talktype-hidden.vbs
' Launch talktype completely detached and hidden — used by toggle-talktype.ps1.
' wscript.exe + WshShell.Run with style 0 / bWaitOnReturn=False is the most
' reliable way on Windows to spawn a fully detached background process.

Set fs = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")

sScriptDir   = fs.GetParentFolderName(WScript.ScriptFullName)
sLaunchersDir = fs.GetParentFolderName(sScriptDir)
sProjectRoot = fs.GetParentFolderName(sLaunchersDir)

' Locate Git Bash. Fall back gracefully if unavailable.
arrCandidates = Array( _
    sh.ExpandEnvironmentStrings("%ProgramFiles%\Git\bin\bash.exe"), _
    sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%\Git\bin\bash.exe"), _
    sh.ExpandEnvironmentStrings("%LOCALAPPDATA%\Programs\Git\bin\bash.exe") _
)
sBash = ""
For Each c In arrCandidates
    If fs.FileExists(c) Then
        sBash = c
        Exit For
    End If
Next
If sBash = "" Then
    MsgBox "Git Bash not found. Install Git for Windows.", vbCritical, "talktype"
    WScript.Quit 1
End If

' Convert F:\Transcript_Proj  ->  /f/Transcript_Proj  (Cygwin/MSYS style)
sDrive    = LCase(Left(sProjectRoot, 1))
sRest     = Replace(Mid(sProjectRoot, 3), "\", "/")
sBashRoot = "/" & sDrive & sRest

' Add Ollama to PATH (winget installs to %LOCALAPPDATA%\Programs\Ollama which
' isn't always on Git Bash PATH after a fresh shell)
sUser    = sh.ExpandEnvironmentStrings("%USERNAME%")
sOllama  = "/c/Users/" & sUser & "/AppData/Local/Programs/Ollama"

' The actual command: run `./talktype dev` in the foreground so bash stays
' alive holding the npm/electron/whisper-server tree. When the toggle's
' "stop" path kills electron+children, bash exits naturally.
sCmd = "export PATH='" & sOllama & "':$PATH; cd '" & sBashRoot & "'; ./talktype dev"

' Quote-escape for cmd-style argument passing
Function Esc(s)
    Esc = Replace(s, """", """""")
End Function

sFull = """" & sBash & """ -c """ & Esc(sCmd) & """"

' Run hidden (style 0), don't wait — fully detached
sh.Run sFull, 0, False
