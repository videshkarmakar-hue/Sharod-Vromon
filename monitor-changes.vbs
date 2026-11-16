' ==========================================
' Sharad Vromon - File Change Monitor
' ==========================================
' Monitors source files and triggers APK build agent

Dim projectDir
projectDir = "C:\sharad-project"

Dim fso, hashFile, currentHash
Set fso = CreateObject("Scripting.FileSystemObject")
Set hashFile = fso.OpenTextFile(projectDir & "\.hash_cache", 8, True)

' Write initial hash state
Dim initFile
initFile = projectDir & "\VERSION"
If fso.FileExists(initFile) Then
    currentHash = GetFileHash(initFile)
    hashFile.WriteLine "VERSION:" & currentHash
End If

' Check important files
Dim filesToWatch
filesToWatch = Array("app/build.gradle.kts", "build.gradle.kts", "README.md")

Dim i
For i = LBound(filesToWatch) To UBound(filesToWatch)
    Dim filePath
    filePath = projectDir & "\" & filesToWatch(i)
    If fso.FileExists(filePath) Then
        currentHash = GetFileHash(filePath)
        Dim savedHash
        hashFile.WriteLine filesToWatch(i) & ":" & currentHash
    End If
Next
hashFile.Close

' ==========================================
' Helper Functions
' ==========================================

Function GetFileHash(filePath)
    Dim shell, stream
    Set shell = CreateObject("WScript.Shell")
    
    On Error Resume Next
    Set stream = shell.Exec("certutil -hashfile """ & filePath & """ MD5")
    On Error GoTo 0
    
    Dim output, hashLine
    output = stream.StdOut.ReadAll
    GetFileHash = ""
    
    If Err.Number = 0 Then
        Dim lines
        lines = Split(output, vbCrLf)
        If UBound(lines) >= 1 Then
            hashLine = lines(1)
            ' Extract just the hash part (after "MD5")
            Dim parts
            parts = Split(hashLine, " ")
            If UBound(parts) >= 1 Then
                GetFileHash = parts(1)
            End If
        End If
    End If
End Function

WScript.Echo "File change monitor started for: " & projectDir
WScript.Echo "Watching: VERSION, app/build.gradle.kts, build.gradle.kts, README.md"
WScript.Echo "Press Ctrl+C to stop..."

' Main monitoring loop
Do
    WScript.Sleep 3000 ' Check every 3 seconds
    
    ' Check VERSION file
    If fso.FileExists(projectDir & "\VERSION") Then
        currentHash = GetFileHash(projectDir & "\VERSION")
        Dim savedV
        savedV = ReadSavedHash("VERSION")
        If currentHash <> savedV Then
            WScript.Echo ">>> VERSION file changed! Triggering build agent..."
            Call TriggerBuildAgent
            ' Update saved hash
            WriteSavedHash "VERSION", currentHash
        End If
    End If
    
    ' Check other files
    Dim f
    For Each f In filesToWatch
        If fso.FileExists(projectDir & "\" & f) Then
            currentHash = GetFileHash(projectDir & "\" & f)
            Dim savedF
            savedF = ReadSavedHash(f)
            If currentHash <> savedF Then
                WScript.Echo ">>> " & f & " changed! Triggering build agent..."
                Call TriggerBuildAgent
                ' Update saved hash
                WriteSavedHash f, currentHash
            End If
        End If
    Next
Loop

Sub WriteSavedHash(fileName, hashValue)
    Dim tempFile, tempHashFile
    Set tempFile = fso.OpenTextFile(projectDir & "\~hash_temp.tmp", 8, True)
    
    Dim hashContent
    hashContent = fileName & ":"
    
    ' Read existing hash file and rewrite without the old entry for this file
    Dim hashFile
    Set hashFile = fso.OpenTextFile(projectDir & "\.hash_cache", 1, False)
    Dim lineContent
    Do Not While Not hashFile.AtEndOfStream
        lineContent = hashFile.ReadLine
        Dim lineParts
        lineParts = Split(lineContent, ":")
        If UBound(lineParts) < 1 Or lineParts(0) <> fileName Then
            tempFile.WriteLine lineContent
        End If
    Loop
    hashFile.Close
    tempFile.Close
    
    ' Append new hash
    Set appendFile = fso.OpenTextFile(projectDir & "\.hash_cache", 8, True)
    appendFile.WriteLine fileName & ":" & hashValue
    appendFile.Close
    
    ' Replace original file
    fso.DeleteFile projectDir & "\.hash_cache"
    fso.MoveFile projectDir & "\~hash_temp.tmp", projectDir & "\.hash_cache"
End Sub

Function ReadSavedHash(fileName)
    ReadSavedHash = ""
    If Not fso.FileExists(projectDir & "\.hash_cache") Then
        ReadSavedHash = ""
        Exit Function
    End If
    
    Dim hashFile
    Set hashFile = fso.OpenTextFile(projectDir & "\.hash_cache", 1, False)
    Dim lineContent
    Do Not While Not hashFile.AtEndOfStream
        lineContent = hashFile.ReadLine
        Dim lineParts
        lineParts = Split(lineContent, ":")
        If UBound(lineParts) >= 1 And lineParts(0) = fileName Then
            ReadSavedHash = lineParts(1)
            Exit Function
        End If
    Loop
    hashFile.Close
End Sub

Sub TriggerBuildAgent()
    Dim wsh
    Set wsh = CreateObject("WScript.Shell")
    
    WScript.Echo "   -> Executing build-apk-agent.bat..."
    wsh.Run "cmd /c ""%~dp0build-apk-agent.bat""", 1, True
    
    WScript.Echo "   -> Build agent completed. Waiting for next change..."
    WScript.Echo "   -> Press Ctrl+C to stop this monitor."
End Sub