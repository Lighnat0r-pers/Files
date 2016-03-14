


; ######################################################################################################
; ########################################### HEADER SECTION ###########################################
; ######################################################################################################

/*
Subheadings:

	#AUTO-EXECUTE
	FileList
	OpenReadme
*/


; Only one instance of the program can be running at a time.
#SingleInstance Force
; Tell the program what to do if it is closed.
OnExit, ExitSequence
; Change the name of the program in the tray menu, then remove the standard tray items
; and add the ones relevant to this program.
SplitPath, A_ScriptName,,,,ProgramNameNoExt
menu, tray, tip, %ProgramNameNoExt%
menu, tray, NoStandard
menu, tray, Add, Restart Program, RestartSequence
menu, tray, Add, Exit, ExitSequence
; RefreshRate: Used throughout the program, for example as a sleep time between loops.
RefreshRate = 20 ; In ms
; Create some arrays needed to find the game and to see if it's still running. Both the window class and name are used for improved accuracy.
GameWindowClassArray := {GTAVC:"Grand theft auto 3", GTA3:"Grand theft auto 3", GTASA:"Grand theft auto San Andreas", GTA4:"Grand theft auto IV"}
GameWindowNameArray := {GTAVC:"GTA: Vice City", GTA3:"GTA3", GTASA:"GTA: San Andreas", GTA4:"GTAIV"}
GameRunningAddressArray := {GTAVC:0x00400000, GTASA:0x00400000, GTA3:0x00400000}
TrayTip, San Andreas OHKO Mod, The program will automatically change the required settings for the OHKO Mod. To close the program right click on the tray icon here and select exit. `n`nMade by Lighnat0r,20,
CurrentGame = GTASA
FileInstall, Extra1.wav, Extra1.wav
FileInstall, Extra2.wav, Extra2.wav
; Enable debug functions if they exist and if the program is not compiled.
; This way normal users can't (accidentally) activate them.
If (IsLabel("DebugFunctions") AND A_IsCompiled != 1)
	gosub DebugFunctions
goto MainScript




; ######################################################################################################
; ############################################ MAIN SECTION ############################################
; ######################################################################################################

/*
Subheadings:

	MainScript
	SetFilesMain
	SetOriginalValues
*/

MainScript:

; Get the window class and name of the game from the array.
WindowClass := GameWindowClassArray[CurrentGame]
WindowName := GameWindowNameArray[CurrentGame]
; Wait until the game window is started. Check both the window class and window title to avoid false positives.
WinWait ahk_class %WindowClass%
WinGetTitle, CurrentWindowName
If (CurrentWindowName != WindowName)
	goto MainScript
; Get the Process Handle of the game for use in memory functions.
; If the process handle cannot be retrieved, try to restart the program
; with admin privileges to see if that fixes the problem.
; If it can still not be retrieved with admin privileges, the program
; cannot function properly so it will shut itself down.
WinGet, PID, PID
ErrorLevel := Memory(1, PID)
If ErrorLevel != 0
{
	If A_IsAdmin = 0
	{
		msgbox Error accessing the game. `nThe program will now try to restart with admin privileges.
		Run *RunAs "%A_ScriptFullPath%"
	}
	Else
	{
		msgbox Error accessing the game. `nThe program cannot continue operating.`n%Error%.
		Error := GetLastErrorMessage()
	}
	ExitConfirmed = 1
	ExitApp
}

; Check if the game is started (which will set the ErrorLevel to !=0)
Process, Exist, %PID%
if ErrorLevel != 0
	VersionOffset := GameVersionCheck(CurrentGame) ; Check which version of the current game is used and which offset to use for memory addresses
else
	goto MainScript
If VersionOffset = 0x75770
{
	msgbox This version of San Andreas is not (yet) supported. Sorry!
	ExitConfirmed = 1
	exitapp
}
GameRunningAddress := GameRunningAddressArray[CurrentGame]
IntroDoneAddress := 0x00A499C0+VersionOffset
OnMissionAddress := 0x00A49FC4+VersionOffset
PlayerStateOffset := 0x530 ; DWord
HealthOffset := 0x540 ; Float
ArmourOffset := 0x548 ; Float
MaxHealthTarget := 5.682 ; Multiplied by 0.176 for actual value, 1.0.
MaxHealthTargetActual := 1.0001 ; Add 0.0001 for safety. The game has a tendency to round 1.0 down to 0.0, resulting in an endless death loop.
MaxHealthOriginal := 569.0
MaxArmourTarget := 0
MaxArmourOriginal := 100



If VersionOffset = 0x75130
{
	MaxHealthAddress := 0x00C0BDC8 ; Float, multiply by 0.176 for actual value.
	MaxArmourAddress := 0x00C0F9E0 ; 1 Byte
	PlayerPointer := 0x00C0F890 ; 0xB6F5F0 is the same.
}
Else
{
	MaxHealthAddress := 0x00B793E0+VersionOffset ; Float, multiply by 0.176 for actual value.
	MaxArmourAddress := 0x00B7CEE8+VersionOffset ; 1 Byte
	PlayerPointer := 0x00B7CD98+VersionOffset
}
If VersionOffset = 0
	HealthBarDrawCallAddress := 0x00589395 ; NOP 5 bytes to stop draw.
Else If VersionOffset = 0x2680
	HealthBarDrawCallAddress := 0x00589B65 ; NOP 5 bytes to stop draw.
Else If VersionOffset = 0x75130
	HealthBarDrawCallAddress := 0x00597263 ; NOP 5 bytes to stop draw.

While Memory(3, GameRunningAddress, 1) != "Fail"
{
	; Don't do anything if a game is not loaded.
	if (Memory(3, IntroDoneAddress, 4) != 1)
		continue
	; Don't do anything if the player is not defined.
	if (Memory(3, PlayerPointer, 4) = 0)
		continue
	; Get the non static addresses.
	HealthAddress := Memory(5, PlayerPointer, HealthOffset)
	ArmourAddress := Memory(5, PlayerPointer, ArmourOffset)
	PlayerStateAddress := Memory(5, PlayerPointer, PlayerStateOffset)
	; Check the max health and armour, update them to the target values if required.
	If (Memory(3, MaxHealthAddress, 4, "Float") > MaxHealthTarget)
		Memory(4, MaxHealthAddress, MaxHealthTarget, 4, "Float")
	If (Memory(3, MaxArmourAddress, 1) > MaxArmourTarget)
		Memory(4, MaxArmourAddress, MaxArmourTarget, 1)
	; Disable the function call that draws the health bar. Store the original value
	; to be able to restore it when closing this program. The function it calls is
	; at a different location on each version, so by reading it here we don't have
	; to define or know the location for each version.
	If (Memory(3, HealthBarDrawCallAddress, 1) != 0x90)
		Loop 5
		{
			HealthBarDrawCall%A_Index%Original := Memory(3, HealthBarDrawCallAddress+A_Index-1, 1)
			Memory(4, HealthBarDrawCallAddress+A_Index-1, 0x90, 1)
		}
	; Make sure the current health and armour do not exceed the maximum for whatever reason.
	If (Memory(3, HealthAddress, 4, "Float") > MaxHealthTargetActual)
		Memory(4, HealthAddress, MaxHealthTargetActual, 4, "Float")
	If (Memory(3, ArmourAddress, 4, "Float") > MaxArmourTarget)
		Memory(4, ArmourAddress, MaxArmourTarget, 4, "Float")
	; Play Extra1.wav if the player dies, play Extra2.wav when the player is arrested.
	PlayerState := Memory(3, PlayerStateAddress, 1)
	If (PlayerState = 55 AND SoundPlaying != 1)
	{
		SoundPlaying = 1
		SoundPlay, Extra1.wav
		SetTimer, SoundTimeout, -7000
	}
	Else If (PlayerState = 63 AND SoundPlaying != 1)
	{
		SoundPlaying = 1
		SoundPlay, Extra2.wav
		SetTimer, SoundTimeout, -7000
	}
	sleep %RefreshRate%
}
goto MainScript

SoundTimeout:
SoundPlaying = 0
return


RestoreValues:
; Restore the original max health and armour (note that max increases due to
; completing side-missions are not taken into account).
Memory(4, MaxHealthAddress, MaxHealthOriginal, 4, "Float")
Memory(4, MaxArmourAddress, MaxArmourOriginal, 1)
; Restore the function call that draws the health bar.
Loop 5
	Memory(4, HealthBarDrawCallAddress+A_Index-1, HealthBarDrawCall%A_Index%Original, 1)
If A_IsCompiled = 1
{
	FileDelete, Extra1.wav
	FileDelete, Extra2.wav
}
return


; ######################################################################################################
; ########################################### RESTART/EXIT SEQUENCE ####################################
; ######################################################################################################

/*
Subheadings:

	RestartSequence
	ExitSequence
	3ButtonYes
	3ButtonNo/3GuiClose/3GuiEscape
*/

;Restart the program
RestartSequence:
ReloadingProgram = 1
reload
sleep 100
return


; What happens when the program is closed
ExitSequence:
If (ExitConfirmed = 1 or ReloadingProgram = 1)
{
	gosub RestoreValues
	sleep 100
	Exitapp
}
else
{
		if CurrentGUI != 
			gui %CurrentGUI%:+disabled
		gui 3:-MinimizeBox -MaximizeBox +owner%CurrentGUI% +LastFound
		Gui, 3:Font, Q3
		Gui, 3:Add, Text,, Are you sure you want to exit the program?
		Gui, 3:Add, Button, Default section, Yes
		Gui, 3:Add, Button, ys, No
		gui, 3:Show
		return
}

3ButtonYes:
ExitConfirmed = 1
ExitApp

3ButtonNo:
3GuiClose:
3GuiEscape:
if CurrentGUI != 
	gui %CurrentGUI%:-disabled
gui, 3:destroy
return


; ######################################################################################################
; ########################################### DEBUG STUFF ##############################################
; ######################################################################################################


DebugFunctions:
Hotkey, F7, DebugListvars, On
return


DebugListvars:
Listvars
return
