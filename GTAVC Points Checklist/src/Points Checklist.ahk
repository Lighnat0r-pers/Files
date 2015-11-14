#include lib_json.ahk
#EscapeChar `
#CommentFlag ;

; ######################################################################################################
; ########################################### HEADER SECTION ###########################################
; ######################################################################################################

/*
Subheadings:

	#AUTO-EXECUTE
	CreateArrays
	FileList
	DefaultSettings
	SetVariablesDependentOnSettings
	WriteSettingsFile
	ReadSettingsFile
*/
; Only one instance of the program can be running at a time.
#SingleInstance Force
; SetWinDelay, 0 is necessary to make the semi-transparent background window move without delay.
SetWinDelay, 0
; Tell the program what to do if it is closed.
OnExit, ExitSequence
; Change the name of the program in the tray menu, then remove the standard tray items
; and add the ones relevant to this program.
SplitPath, A_ScriptName,,,,ScriptNameNoExt
menu, tray, tip, %ScriptNameNoExt%
menu, tray, NoStandard
menu, tray, Add, Restart Script, RestartSequence
menu, tray, Add, Exit, ExitSequence
Voice := ComObjCreate("SAPI.SpVoice")
SetFormat, FloatFast, 0.1

gosub DefaultSettings
SettingsFileName = %ScriptNameNoExt% Config`.ini
ifExist,%SettingsFileName%
	gosub ReadSettingsFile
else
	gosub WriteSettingsFile
goto CreateArrays

CreateArrays:
; Create some arrays needed to find the game and to see if it's still running. Both the window class and name are used for improved accuracy.
GameWindowClassArray := {GTAVC:"Grand theft auto 3"}
GameWindowNameArray := {GTAVC:"GTA: Vice City"}
GameRunningAddressArray := {GTAVC:0x00400000}
; The requirements array is created later because it depends on settings chosen by the user.
goto WelcomeScreen


; These default settings will be used if they haven't been configured otherwise in the settings file.
DefaultSettings:
TextColour = FFFFFF
BackColour = 333333
MaximumRows = 25
RefreshRate = 500
TextSmoothing = 0
OutputWindowBoldText = 0
AlwaysOnTop = 0
VoiceEnabled = 1
TextListViewWidth := 325

GameName = GTA VC
GameNameNoSpace = GTAVC
return

; Save the settings to the settings file.
WriteSettingsFile:
IniWrite, %TextColour%, %SettingsFileName%, Options, Text colour
IniWrite, %BackColour%, %SettingsFileName%, Options, Background colour
IniWrite, %MaximumRows%, %SettingsFileName%, Options, Maximum rows
IniWrite, %TextSmoothing%, %SettingsFileName%, Options, Text Smoothing
IniWrite, %OutputWindowBoldText%, %SettingsFileName%, Options, Bold Output Text
IniWrite, %AlwaysOnTop%, %SettingsFileName%, Options, Always On Top
IniWrite, %VoiceEnabled%, %SettingsFileName%, Options, Voice Enabled
return

; Read the settings from the settings file.
ReadSettingsFile:
IniRead, TextColour, %SettingsFileName%, Options, Text colour
IniRead, BackColour, %SettingsFileName%, Options, Background colour
IniRead, MaximumRows, %SettingsFileName%, Options, Maximum rows
IniRead, TextSmoothing, %SettingsFileName%, Options, Text Smoothing
IniRead, OutputWindowBoldText, %SettingsFileName%, Options, Bold Output Text
IniRead, AlwaysOnTop, %SettingsFileName%, Options, Always On Top
IniRead, VoiceEnabled, %SettingsFileName%, Options, Voice Enabled
return

; ######################################################################################################
; ########################################### WELCOME WINDOW ###########################################
; ######################################################################################################

/*
Subheadings:

	WelcomeScreen
	2GuiClose/2GuiEscape/2ButtonClose
	2GuiContextMenu
	2ButtonConfirm
	SelectGameCode
*/

; Create the welcome window. First the minimize and maximize buttons are removed, and LastFound is set so
; functions affecting the window later will automatically act on this one without having to specify.
; Next the background colour is set and then, dependent on the settings, the font options are set.
; If the window is even slightly transparent, the font gets maximum boldness, and if text smoothing
; is off or if the window is again even slightly transparent, text smoothing is turned off (having
; it turned on with a transparent background creates ugly borders). It proceeds to add the text and
; other controls to the window, some of which have somewhat specific placement settings, such as
; width or position relative to the previous control. Some empty text controls are also created to
; create some space between the controls above and below it. If any level of transparency is in play,
; the background window is made entirely transparent and some preparations are made for faking a
; semi-transparent background. After the gui is rendered, a second window is created which is locked
; to the first. It consists of just a background which is semi-transparent. (Within one window, it is
; possible to make either the background completely transparent, or the entire window, including controls,
; semi-transparent. This is the only decent solution I have found. It does have some issues (see readme)
; but nothing major.) The background window is set to be the owner of the real window, to avoid it being
; selectable which would push the background over the other window. Even if the background is completely
; transparent, the background window is still created, because otherwise clicks would fall through (this
; only happens if a specific colour is made transparent as is the case for the real window, it doesn't
; happen if the entire window is made completely transparent as is the case for the background window.)
WelcomeScreen:
TeamNamePlaceholder := "Please enter a team name here."
gui 2:-MinimizeBox -MaximizeBox +LastFound
gui, 2:Color, %BackColour%, %BackColour%
if AlwaysOnTop = 1
	Winset, AlwaysOnTop, On
WelcomeWindowWidth := 250
if (TextSmoothing = 0)
	gui, 2:Font, Q3
gui, font, s14, Verdana
gui, 2:Add, Text,c%TextColour% center w%WelcomeWindowWidth%, Welcome to the Points Checklist!
gui, 2:Add, Text,c%TextColour% y+5 center w%WelcomeWindowWidth%, Created by`: Lighnat0r
gui, 2:Add, Edit, c%TextColour% y+15 center w%WelcomeWindowWidth% vTeamName, %TeamNamePlaceholder%
gui, 2:Add, Button, y+10 xs section, Start
gui, 2:Add, Button, ys, Close
gui, 2:Show,
return

; What happens if the user tries to close the window.
2GuiClose:
2GuiEscape:
2ButtonClose:
CurrentGUI = 2
exitapp
return

2ButtonStart:
gui, 5:submit
gui, 2:submit
if (!TeamName || TeamName = TeamNamePlaceholder) {
	Msgbox, Please enter a team name.
	Gui, 5:Restore
	Gui, 2:Restore
	return
}
CurrentGame = %GameNameNoSpace%

; Now that the options are selected, we can create the requirements array.
CurrentLoopCode = CreateRequirementsArray
gosub Requirements
Goto OutputWindow

; Create the requirements array. It is initialised the first time this subroutine is
; called, then it can be populated.
CreateRequirementsArray:
if RequirementsArrayCreated != 1
{
	RequirementsArrayIndex = 1
	RequirementsArray := {}
	RequirementsArrayCreated = 1
}
else {
	RequirementsArrayIndex += 1
}

; Create the array with all the requirements. Each name signifies an object created below
; which contains all the properties belonging to it. The name of the array
; is unique for each game/special mode even though currently only one of them
; can exist at a time. This way hotswitching can be added later without the
; the program breaking here. It might also avoid issues caused by multiple
; games using the same icon. The IconName is used instead of the Name because it does not
; contain any spaces which would can't be used in an object name.
RequirementsArray.Insert(IconName)
; Now create the object with its properties. Store the type and icon name,
; then loop to store all the addresses defined with the corresponding
; length and custom code flags. Again add the name of the game and the special
; mode to avoid issues.
%IconName% := {} ; Create the object
%IconName%.Insert("Name", Name)
%IconName%.Insert("Type", Type)
%IconName%.Insert("PointsPer", PointsPer)
if (!PointsPerText) {
	PointsPerText := PointsPer
}
%IconName%.Insert("PointsPerText", PointsPerText)
%IconName%.Insert("ValueOld", 0)
; Loop through all the defined addresses, adding them to the object if they are defined.
; Immediately after adding them, clear the address and its length and custom code flags
; in preparation of adding the next requirement once this subroutine is called again.
Loop
{
	if Address%A_Index% =
		break
	%IconName%.Insert("Address"A_Index, Address%A_Index%)
	if Address%A_Index%Length =
		Address%A_Index%Length = 4 ; Default length
	%IconName%.Insert("AddressLength"A_Index, Address%A_Index%Length)
	%IconName%.Insert("AddressCustomCode"A_Index, Address%A_Index%CustomCode)
	Address%A_Index% =
	Address%A_Index%Length =
	Address%A_Index%CustomCode =
}
; Also reset all the other variables. Only the optional variables need to be reset,
; but resetting all variables makes sure they doesn't cause any issues.
Name =
IconName =
PointsPer =
PointsPerText =
Type =
return

; ######################################################################################################
; ########################################### OUTPUT WINDOW ############################################
; ######################################################################################################

/*
Subheadings:

	OutputWindow
	GuiClose/GuiEscape
	GuiContextMenu
	MoveWindow
	WM_LBUTTONDOWN
	TextPopulateListView
	IconsPopulateListView
*/

OutputWindow:
Gui 1:-MinimizeBox -MaximizeBox +LastFound
Gui, 1:Default
if AlwaysOnTop = 1
	Winset, AlwaysOnTop, On
If (OutputWindowBoldText = 1)
	Gui, 1:Font, w1000
If (TextSmoothing = 0)
	Gui, 1:Font, Q3
MaxValueLengthInPixels = 0
Gui, 1:Add, ListView, c%TextColour% vRequirementsListView Background%BackColour% gMoveWindow w%TextListViewWidth% Count20 -Multi -E0x200 section -Hdr, Name|Value|Required

; For each requirement in the requirements array, add it to the list view.
; At the start of every requirement, check if the list view exceeds the maximum
; length and create a new one in necessary.
For Index, IconName in RequirementsArray
{
	; Create the entry in the listview. Check if PointsPer is defined, if not leave it out.
	LV_Add("", %IconName%.Name, 0, (%IconName%.PointsPer != "" ? " * "%IconName%.PointsPer : ""))
}
TotalRows := LV_GetCount()
gui, 1:Color, %BackColour%, %BackColour%
gui 1:-Caption
OnMessage(0x201, "WM_LBUTTONDOWN")
LV_ModifyCol() ; Set the width for the columns
; We want padding with the current layout of the listview. This padding is the area between the
; list views but also the padding between the columns.
ListViewTargetWidth = 50
Loop % LV_GetCount("Column")
{
	SendMessage, 4125, A_Index-1, 0, SysListView321  ; 4125 is LVM_GETCOLUMNWIDTH.
	ListViewTargetWidth += %ErrorLevel%
}
GuiControl, Move, RequirementsListView, w%ListViewTargetWidth%
; For text mode: each text has a height of 21 pixels with 4 pixels vertical padding at the top, 2 pixels at the bottom, for a total of 17.
ListViewHeight := TotalRows*27
Guicontrol, Move, RequirementsListView, h%ListViewHeight%
; Set the height of the window in pixels. We can describe the window in three parts:
; From the top of the window (so including the button) to the list view, which is 35 pixels.
; The height of the list view (the first list view is always the longest so use that one).
; Padding at the bottom, which can be chosen as whatever. We will use 5 here.
ControlGetPos,,,,RequirementsListViewHeight,SysListView321,,,
GuiHeight := 35+RequirementsListViewHeight+5
ControlGetPos,,,RequirementsListViewWidth,,SysListView321,,,
GuiWidth := RequirementsListViewWidth+16
; Check if this is the first time the window is shown or if it is redrawn after changing the output type.
; If it is being redrawn, use the saved position of the original window to draw it at the same position.
gui, 1:Show, h%GuiHeight% w%GuiWidth%
; Proceed to the MainScript, which is where the output is updated. Since we don't want to start the
; MainScript after changing the output (since it will be running already), we check for that. If the
; MainScript would be launched every time, we would quickly reach the maximum number of simultaneous
; threads causing the whole program to become unresponsive. Not to mention the memory leaking from having
; a lot of threads running.
gosub ResetOutput
goto MainScript

GuiClose:
GuiEscape:
CurrentGUI = 1
exitapp
return

; The following items are added to the right click menu.
GuiContextMenu:
Menu, OutputRightClick, Add, Restart Script, RestartSequence
Menu, OutputRightClick, Add, Exit, GuiClose
Menu, OutputRightClick, Show
return

; When the user clicks on any of the controls and moves the mouse, this will drag the window with it.
MoveWindow: ; For clicking on controls
PostMessage, 0xA1, 2,,, A     ; Drag window on click
return

; When the user clicks in the window (but not on the controls) and moves the mouse, this will drag the window with it.
WM_LBUTTONDOWN(wParam, lParam) ; For clicking anywhere else in the window
{
	PostMessage, 0xA1, 2,,, A     ; Drag window on click
}

; ######################################################################################################
; ########################################### UPDATE OUTPUT ############################################
; ######################################################################################################

/*
Subheadings:

	MainScript
	UpdateOutputCode
	ResetOutputCode
*/


MainScript:

; Get the window class and name of the selected game from the array.
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
	ExitApp
}
; Check if the game is started (which will set the ErrorLevel to !=0),
; then check which version of the current game is used and which offset to use for memory addresses.
Process, Exist, %PID%
If ErrorLevel != 0
	VersionOffset := GameVersionCheck(CurrentGame)
else
	goto MainScript
; Show a tray tip to the user explaining what the program will do next.
Traytip, %ScriptNameNoExt%, The program is now running in the background and will update automatically, 20,

if (VoiceEnabled) {
	if (VersionOffset != -0x2FF8) {
		Voice.Speak("<silence msec='400'/>You get 100 bonus points for not using the scrubby Japanese version. no Duping.", 1 + 2 + 8)
	}
	else {
		Voice.Speak("<silence msec='400'/>You get 100 bonus points for using the Japanese version. <pron sym='y eh s d uw p ih ng' />.", 1 + 2 + 8)
	}
}
; Get which address to check if the game is still running.
GameRunningAddress := GameRunningAddressArray[CurrentGame]
; This While-loop will remain active as long as the game is running. The code in it updates the output.
; The loop checks if the output type is changed because it needs to realize that in order to keep
; updating the output.
counter = 11
While Memory(3, GameRunningAddress, 1) != "Fail"
{
	gosub UpdateOutput
	if (counter > 10) {
		gosub UpdateRequest
		counter = 0
	}
	sleep %RefreshRate%
	counter += 1
}
; If the while-loop breaks (meaning the game is no longer running),
; return to the start of the 'main script' where the program will wait until the game is started.
goto MainScript


; Code which updates the output.
UpdateOutput:
RowNumber = 1
For Index, IconName in RequirementsArray
{
	; The current value is reset to stop information from carrying over from the previous requirement.
	CurrentValue := 0
	; Loop to read all the memory addresses belonging to the current requirement.
	; Get the address, length and customcode flags from the requirements array.
	; If type is set, the read value can be converted to a float and custom code
	; located in the requirement list can be executed. At the end of the loop,
	; The variable 'CurrentValue' contains the finalized value of the requirement.
	Loop
	{
		ReadAddress := %IconName%["Address"A_Index]
		if ReadAddress =
			break
		ReadLength := %IconName%["AddressLength"A_Index]

		MemoryValue := Memory(3, ReadAddress+VersionOffset, ReadLength, %IconName%.Type)
		if (%IconName%["AddressCustomCode"A_Index] = 1)
			gosub %IconName%Address%A_Index%CustomCode
		CurrentValue += %MemoryValue%
	}
	; Only update the output if the value found in this cycle is not the same as the value found in the last cycle.
	if (IconName = "Points" OR CurrentValue != %IconName%.ValueOld)
	{
		; Update the output.
		LV_Modify(RowNumber,"Col2", CurrentValue)
		LV_Modify(RowNumber, "Col3", (%IconName%.PointsPer != "" ? " * "%IconName%.PointsPer : ""))
		UpdatedValueLengthChar := StrLen(CurrentValue)
		; Check the length of the new value and make the output wider if it's too small.
		UpdatedValueLengthInPixels := UpdatedValueLengthChar*12+12
		if (UpdatedValueLengthInPixels > MaxValueLengthInPixels)
		{
			LV_ModifyCol(2,UpdatedValueLengthInPixels)
			MaxValueLengthInPixels := UpdatedValueLengthInPixels
		}

		if (VoiceEnabled AND IconName = "Points" AND CurrentValue != %IconName%.ValueOld) {
			Voice.Rate := 1
			Voice.Speak("<pitch absmiddle = '2'/> You now have <rate speed='-2'><emph>" MemoryValue "</emph></rate>Points.", 1 + 2 + 8)
		}

		; Store the value found this cycle to compare the next cycle against.
		%IconName%.ValueOld := CurrentValue
	}

	RowNumber += 1
}
return

; For each requirement in the requirements array, set the value in the listview(s) back.
; At the start of every requirement, check if the
; current row exceeds the maximum length and jump to the next list view in necessary.
ResetOutput:
RowNumber = 1
For Index, IconName in RequirementsArray
{
	%IconName%.ValueOld := 0
	LV_Modify(RowNumber,"Col2", 0)
	RowNumber += 1
}
return

UpdateRequest:
Request := {}
Request.Insert("Team", TeamName)
Request.Insert("Points", [])
For Index, IconName in RequirementsArray
{
	Object := {}
	Object.Insert("ID", IconName)
	Object.Insert("Name", %IconName%.Name)
	Object.Insert("Value", %IconName%.ValueOld)
	Object.Insert("PointsPerValue", %IconName%.PointsPer)
	Object.Insert("PointsPerValueText", %IconName%.PointsPerText)
	Request.Points.Push(Object)
}

JSON := JSON_to(Request, 0)

POST := "data=" JSON ""
WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
WebRequest.Open("POST", "http://www.speedrun.com/gta_points_blindfolded/ajax_points_checklist.php", false)
WebRequest.setRequestHeader("Content-Type", "application/x-www-form-urlencoded")
WebRequest.Send(POST)

return

; ######################################################################################################
; ########################################### RESTART/EXIT SEQUENCE ####################################
; ######################################################################################################

RestartSequence:
reload
sleep 100
return

ExitSequence:
exitapp

; ######################################################################################################
; ########################################### GTA: Vice City ###########################################
; ######################################################################################################

Requirements:
Name = Total Points
IconName = Points
Address1CustomCode = 1
Address1 := 0x008226E8 ; DUMMY ADDRESS
gosub %CurrentLoopCode%
Name = Hidden Packages
IconName = HiddenPackage
PointsPer = 3
Address1 := 0x008226E8
gosub %CurrentLoopCode%
Name = Robberies
IconName = Robbery
PointsPer = 4
Address1 := 0x00822A6C
gosub %CurrentLoopCode%
Name = Unique Jumps
IconName = UniqueJump
PointsPer = 6
Address1 := 0x00821EDC
gosub %CurrentLoopCode%
Name = Rampages
IconName = Rampage
PointsPer = 7
Address1 := 0x0082286C
gosub %CurrentLoopCode%
Name = Missions
IconName = Missions
PointsPer = 10
Address1CustomCode = 1
Address2CustomCode = 1
Address3CustomCode = 1
Address1  := 0x008291F0 ; RC Raider
Address2  := 0x00829344 ; RC Bandit
Address3  := 0x00829714 ; RC Baron
Address4  := 0x008217CC ; PCJ Playground
Address5  := 0x008217FC ; Cone Crazy
Address6  := 0x0082182C ; Trial By Dirt
Address7  := 0x00821830 ; Test Track
Address8  := 0x00822B40 ; Downtown
Address9  := 0x00822B44 ; Ocean Beach
Address11 := 0x00822B48 ; Vice Point
Address12 := 0x00822B4C ; Little Haiti
Address13 := 0x00822B74 ; Hotring
Address14 := 0x00822B78 ; Bloodring
Address15 := 0x0082135C ; Dirtring
Address16 := 0x00822B50 ; Terminal Velocity
Address17 := 0x00822B54 ; Ocean Drive
Address18 := 0x00822B58 ; Border Run
Address19 := 0x00822B5C ; Capital Cruise
Address20 := 0x00822B60 ; Tour
Address21 := 0x00822B64 ; VC Endurance
Address22 := 0x00821600 ; The Party
Address23 := 0x00821604 ; Back Alley Brawl
Address24 := 0x00821608 ; Jury Fury
Address25 := 0x0082160C ; Riot
Address26 := 0x00821648 ; Death Row
Address27 := 0x0082162C ; The Chase
Address28 := 0x00821630 ; Phnom Penh '86
Address29 := 0x00821634 ; The Fastest Boat
Address30 := 0x00821638 ; Supply And Demand
Address31 := 0x0082163C ; Rub Out
Address32 := 0x008216A8 ; Shakedown
Address33 := 0x008216AC ; Bar Brawl
Address34 := 0x008216B0 ; Cop Land
Address35 := 0x008216B4 ; Cap The Collector
Address36 := 0x008216B8 ; Keep Your Friends Close
Address37 := 0x00821650 ; Four Iron
Address38 := 0x00821654 ; Demolition Man
Address39 := 0x00821658 ; Two Bit Hit
Address40 := 0x008216DC ; Stunt Boat Challenge
Address41 := 0x008216E0 ; Cannon Fodder
Address42 := 0x008216E4 ; Naval Engagement
Address43 := 0x008216E8 ; Trojan Voodoo
Address44 := 0x008216F0 ; Juju Scramble
Address45 := 0x008216F4 ; Bombs Away
Address46 := 0x008216F8 ; Dirty Lickin's
Address47 := 0x00821700 ; Love Juice
Address48 := 0x00821704 ; Psycho Killer
Address49 := 0x00821708 ; Publicity Tour
Address50 := 0x008216CC ; Alloy Wheels Of Steel
Address51 := 0x008216D0 ; Messing With The Man
Address52 := 0x008216D4 ; Hog Tied
Address53 := 0x00821678 ; Gun Runner
Address54 := 0x0082167C ; Boomshine Saigon
Address55 := 0x00821614 ; Treacherous Swine
Address56 := 0x00821618 ; Mall Shootout
Address57 := 0x0082161C ; Guardian Angels
Address58 := 0x00821620 ; Sir Yes Sir
Address59 := 0x00821624 ; All Hands On Deck
Address60 := 0x00821728 ; Road Kill
Address61 := 0x0082172C ; Waste The Wife
Address62 := 0x00821730 ; Autocide
Address63 := 0x00821734 ; Check Out At The Check In
Address64 := 0x00821738 ; Loose Ends
Address65 := 0x00821684 ; Recruitment Drive
Address66 := 0x00821688 ; Dildo Dodo
Address67 := 0x0082168C ; Martha's Mug Shot
Address68 := 0x00821690 ; G-Spotlight
Address69 := 0x00821750 ; VIP
Address70 := 0x00821754 ; Friendly Rivalry
Address71 := 0x00821758 ; Cabmaggedon
Address72 := 0x00821BFC ; Checkpoint Charlie
Address73 := 0x008216C0 ; Spilling The Beans
Address74 := 0x008216C4 ; Hit The Courier
Address75 := 0x00821660 ; No Escape
Address76 := 0x00821664 ; The Shootist
Address77 := 0x00821668 ; The Driver
Address78 := 0x0082166C ; The Job
Address79 := 0x008223A0 ; Pole Position
Address80 := 0x00821C10 ; Distribution
Address81 := 0x00822414 ; SSA List 1
Address82 := 0x00822418 ; SSA List 2
Address83 := 0x0082241C ; SSA List 3
Address84 := 0x00822420 ; SSA List 4
Address85 := 0x008215F8 ; An Old Friend
Address86 := 0x008215F0 ; In The Beginning
gosub %CurrentLoopCode%
Name = Properties
IconName = Properties
PointsPer = 6
Address1 := 0x00978E08 ; Properties Owned
gosub %CurrentLoopCode%
Name = Taxi Fares
IconName = TaxiDriver
PointsPer = 1
Address1 := 0x00821844
gosub %CurrentLoopCode%
Name = Vigilante Max Level
IconName = Vigilante
PointsPer = 10
Address1 := 0x0094DD60
gosub %CurrentLoopCode%
Name = Pizzas Delivered
IconName = PizzaDelivery
Type = Float
PointsPer = 0.5
Address1 := 0x00978780
gosub %CurrentLoopCode%
Name = Firefighter Completed
IconName = Firefighter
PointsPer = 6
Address1 := 0x00822B3C
gosub %CurrentLoopCode%
Name = Paramedic Max Level
IconName = Paramedic
PointsPer = 0
PointsPerText := "10n"
Address1CustomCode = 1
Address1 := 0x00978DB8
Address1Length := 1
gosub %CurrentLoopCode%
return

MissionsAddress1CustomCode:
MissionsAddress2CustomCode:
MissionsAddress3CustomCode:
if VersionOffset = -0x2FF8 ; Game is version JP
{
	; This fixes the offset for the JP version for these addresses.
	MemoryValue := Memory(3, ReadAddress+VersionOffset + 8, ReadLength)
}
return

ParamedicAddress1CustomCode:
Paramedic.PointsPer := MemoryValue * 10
return

PointsAddress1CustomCode:

MemoryValue := 0
MemoryValue := MemoryValue + HiddenPackage.ValueOld * HiddenPackage.PointsPer
MemoryValue := MemoryValue + Robbery.ValueOld * Robbery.PointsPer
MemoryValue := MemoryValue + UniqueJump.ValueOld * UniqueJump.PointsPer
MemoryValue := MemoryValue + Rampage.ValueOld * Rampage.PointsPer
MemoryValue := MemoryValue + Properties.ValueOld * Properties.PointsPer
MemoryValue := MemoryValue + TaxiDriver.ValueOld * TaxiDriver.PointsPer
MemoryValue := MemoryValue + Vigilante.ValueOld * Vigilante.PointsPer
MemoryValue := MemoryValue + PizzaDelivery.ValueOld * PizzaDelivery.PointsPer
MemoryValue := MemoryValue + Firefighter.ValueOld * Firefighter.PointsPer
MemoryValue := MemoryValue + Paramedic.ValueOld * Paramedic.PointsPer
return
