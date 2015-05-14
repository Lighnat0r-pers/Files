; ######################################################################################################
; ########################################### HEADER SECTION ###########################################
; ######################################################################################################

/*
Subheadings:

	#AUTO-EXECUTE
	FileList

*/

#SingleInstance force
GameWindowClassArray := {GTAVC:"Grand theft auto 3", GTA3:"Grand theft auto 3", GTASA:"Grand theft auto San Andreas", GTA4:"Grand theft auto IV"}
GameWindowNameArray := {GTAVC:"GTA: Vice City", GTA3:"GTA3", GTASA:"GTA: San Andreas", GTA4:"GTAIV"}
GameRunningAddressArray := {GTAVC:0x00400000, GTASA:0x00400000, GTA3:0x00400000}
CurrentGame = GTAVC

DefaultHotkey = F5
SettingsFileName := "QuicksaveSettings.ini"

; Read the hotkey from the file if it exists, if the file is invalid it gets the default hotkey.
IfExist, %SettingsFileName%
	IniRead, Hotkey, %SettingsFileName%, Hotkey, Hotkey, F5
else
{
	IniWrite, F5, %SettingsFileName%, Hotkey, Hotkey
	Hotkey := DefaultHotkey	
}

CurrentVersion = 1.2
VersionURL := "http://pastebin.com/download.php?i=pc9QbQCK"
ProgramName = Quicksave
gosub FileList
if A_IsCompiled = 1
	goto UpdateCheck
else
	goto Mainscript


FileList:
File1 := "newversionGTA VC Quicksave.exe"
ExecutableFile := File1
return


; ######################################################################################################
; ########################################### UPDATE CHECKER ###########################################
; ######################################################################################################

/*
Subheadings:

	UpdateCheck
	4ButtonYes
	4GuiClose/4GuiEscape/4ButtonNo

*/

UpdateCheck:
if (FileExist("Updater.cmd") != "")
	FileDelete, Updater.cmd
UrlDownloadToFile, %VersionURL%, Version.ini
if ErrorLevel = 0 ; Check if file downloaded successfully
	{
		IniRead, NewestVersion, Version.ini, Version, %ProgramName%
		if (NewestVersion != "Error" AND NewestVersion > CurrentVersion)
			{
				Gui 4:-MinimizeBox -MaximizeBox +LastFound
				Gui, 4:Font, Q3
				Gui, 4:Add, Text,, An update is available `(v%NewestVersion%`) `nWould you like to update now`?
				IniRead, DescriptionText, Version.ini, %ProgramName% Files, Description
				if (DescriptionText != "Error" AND DescriptionText != "")
					{
						Gui, 4:Font, w700 Q3 ; Bold
						Gui, 4:Add, Text,, Update description`:
						Gui, 4:Font, w400 Q3 ; Normal
						Gui, 4:Add, Text,h0 w0 Y+4,
						StringSplit, DescriptionTextArray, DescriptionText, `|
						Loop %DescriptionTextArray0%
							{
								Gui, 4:Add, Text,Y+1, % DescriptionTextArray%A_Index%
							}
					}
				Gui, 4:Add, Text,h0 w0 Y+4,
				Gui, 4:Add, Button, section default, Yes
				Gui, 4:Add, Button, ys, No
				Gui, 4:Show
				return
			}
	}	
FileDelete, Version.ini
goto Mainscript

4ButtonYes:
Gui, 4:Hide
SplashTextOn , 350 , , Downloading the new version. This might take some time...
Loop
	{
		If File%A_Index% =
			break
		File := File%A_Index%
		IniRead, FileLink, Version.ini, %ProgramName% Files, %File%
		UrlDownloadToFile, %FileLink%, %File%
	}
FileDelete, Version.ini
UpdateVar1 = `"%A_ScriptDir%\%ExecutableFile%`" ; Location of the newversion exe
UpdateVar2 = `"%A_ScriptFullPath%`" ; Location of the old (currently running) exe which will be overwritten
UpdateVar3 := DllCall("GetCurrentProcessId") ; Program PID so it can be closed
FileInstall, Updater.cmd, Updater.cmd, 1
Run, Updater.cmd %UpdateVar1% %UpdateVar2% %UpdateVar3%, ,
sleep 5000 ; Give the updater some time to close this program
ExitConfirmed = 1
exitapp

4GuiClose:
4GuiEscape:
4ButtonNo:
Gui, 4:Destroy
FileDelete, Version.ini
goto Mainscript
return


; ######################################################################################################
; ############################################ MAIN SECTION ############################################
; ######################################################################################################

/*
Subheadings:

	MainScript
	Quicksave
	GameRunningCheck

*/

Mainscript:
TrayTip, , Quicksave is now enabled (Hotkey is %Hotkey%). `n`nMade by Lighnat0r,20,
WindowClass := GameWindowClassArray[CurrentGame]
WindowName := GameWindowNameArray[CurrentGame]
GameRunningAddress := GameRunningAddressArray[CurrentGame]

; Wait until the game window is started. Check both the window class and window title to avoid false positives.
WinWait ahk_class %WindowClass%
WinGetTitle, CurrentWindowName
If (CurrentWindowName != WindowName)
	goto MainScript

; Get the Process Handle of GTA: Vice City for use in memory functions
WinGet, PID, PID
Memory(1, PID)

; Check if the game is started (which will set the ErrorLevel to !=0)
Process, Exist, %PID%
if ErrorLevel != 0
	VersionOffset := GameVersionCheck(CurrentGame) ; Check which version of the current game is used and which offset to use for memory addresses
else 
	goto MainScript
Hotkey, %Hotkey%, Quicksave,
SetTimer, GameRunningCheck, 500
return


Quicksave:
PlayerPointer := 0x007E4B8C+VersionOffset
CarPointer := 0x007E49C0+VersionOffset
OnMissionAddress := 0x00821764+VersionOffset
OnNotRealMissionAddress := 0x008224F0+VersionOffset
InTheBeginningDoneAddress := 0x008215F0+VersionOffset
SaveMenuAddress := 0x0086966B+VersionOffset
PlayerValue := Memory(3, PlayerPointer, 4)
CarValue := Memory(3, CarPointer, 4)
MissionValue := Memory(3, OnMissionAddress, 4) + Memory(3, OnNotRealMissionAddress, 4)

if ((Memory(3, GameRunningAddress, 1) = "Fail"))
	goto Mainscript
If (Memory(3, PlayerPointer, 4) = Memory(3, CarPointer, 4) AND Memory(3, OnMissionAddress, 4) != 1 AND if (Memory(3, InTheBeginningDoneAddress, 4) = 1))
	{
		Memory(4, SaveMenuAddress, 1, 1)
		sleep 1000
	}
return


GameRunningCheck:
if ((Memory(3, GameRunningAddress, 1) = "Fail"))
	goto Mainscript
return
