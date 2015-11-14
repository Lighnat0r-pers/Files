#include lib_json.ahk
#EscapeChar `
#CommentFlag ;

; ######################################################################################################
; ########################################### HEADER SECTION ###########################################
; ######################################################################################################

/*
Subheadings:

	#AUTO-EXECUTE
	DefaultSettings
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
ComObjError(false)
Voice := ComObjCreate("SAPI.SpVoice")
SetFormat, FloatFast, 0.1

gosub DefaultSettings
SettingsFileName = %ScriptNameNoExt% Config`.ini
ifExist,%SettingsFileName%
	gosub ReadSettingsFile
else
	gosub WriteSettingsFile
goto WelcomeScreen


; These default settings will be used if they haven't been configured otherwise in the settings file.
DefaultSettings:
TextColour = FFFFFF
BackColour = 333333
MaximumRows = 25
RefreshRate = 5000
TextSmoothing = 0
OutputWindowBoldText = 0
AlwaysOnTop = 0
VoiceEnabled = 1
TextListViewWidth := 325
;PostUrl := "http://www.speedrun.com/gta_points_blindfolded/ajax_points_checklist.php"
GetUrl := "http://www.speedrun.com/gta_points_blindfolded/points_checklist.php"

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
IniWrite, %GetUrl%, %SettingsFileName%, Options, Url To Get Results From
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
IniRead, GetUrl, %SettingsFileName%, Options, Url To Get Results From
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
TeamNamePlaceholder := "Please enter your team name here."
gui 2:-MinimizeBox -MaximizeBox +LastFound
gui, 2:Color, %BackColour%, %BackColour%
if AlwaysOnTop = 1
	Winset, AlwaysOnTop, On
WelcomeWindowWidth := 250
if (TextSmoothing = 0)
	gui, 2:Font, Q3
gui, font, s14, Verdana
gui, 2:Add, Text,c%TextColour% center w%WelcomeWindowWidth%, Welcome to the Points Checklist! - Slave version
gui, 2:Add, Text,c%TextColour% y+5 center w%WelcomeWindowWidth%, Created by`: Lighnat0r
gui, 2:Add, Edit, c%TextColour% y+15 center w%WelcomeWindowWidth% vTeamName -WantReturn, %TeamNamePlaceholder%
gui, 2:Add, Button, y+10 xs section default, Start
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
	Msgbox, Please enter a valid team name.
	Gui, 5:Restore
	Gui, 2:Restore
	return
}

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

; Show a tray tip to the user explaining what the program will do next.
Traytip, %ScriptNameNoExt%, The program is now running in the background and will update automatically, 20,


Loop
{
	gosub GetData
	if (Data) {
		gosub UpdateOutput
	}
	sleep %RefreshRate%
}
goto MainScript


; Code which updates the output.
UpdateOutput:
RowNumber = 1
For Index, IconName in RequirementsArray
{
	CurrentValue := Data[IconName].Value

	; Update the output.
	LV_Modify(RowNumber,"Col2", CurrentValue)
	LV_Modify(RowNumber, "Col3", (Data[IconName].PointsPerValue != "" ? " * "Data[IconName].PointsPerValue : ""))
	UpdatedValueLengthChar := StrLen(CurrentValue)
	; Check the length of the new value and make the output wider if it's too small.
	UpdatedValueLengthInPixels := UpdatedValueLengthChar*12+12
	if (UpdatedValueLengthInPixels > MaxValueLengthInPixels)
	{
		LV_ModifyCol(2,UpdatedValueLengthInPixels)
		MaxValueLengthInPixels := UpdatedValueLengthInPixels
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
	LV_Modify(RowNumber,"Col2", 0)
	RowNumber += 1
}
return

GetData:
Data := ""
WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
WebRequest.Open("GET", GetUrl, false)
WebRequest.Send()

Raw := json_from(WebRequest.ResponseText)

if (Raw[TeamName]) {
	Data := Raw[TeamName]
}
else {
	;msgbox Team not found. ; TODO remove
}

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
gosub %CurrentLoopCode%
Name = Hidden Packages
IconName = HiddenPackage
PointsPer = 3
gosub %CurrentLoopCode%
Name = Robberies
IconName = Robbery
PointsPer = 4
gosub %CurrentLoopCode%
Name = Unique Jumps
IconName = UniqueJump
PointsPer = 6
gosub %CurrentLoopCode%
Name = Rampages
IconName = Rampage
PointsPer = 7
gosub %CurrentLoopCode%
Name = Missions
IconName = Missions
PointsPer = 10
gosub %CurrentLoopCode%
Name = Properties
IconName = Properties
PointsPer = 6
gosub %CurrentLoopCode%
Name = Taxi Fares
IconName = TaxiDriver
PointsPer = 1
gosub %CurrentLoopCode%
Name = Vigilante Max Level
IconName = Vigilante
PointsPer = 10
gosub %CurrentLoopCode%
Name = Pizzas Delivered
IconName = PizzaDelivery
Type = Float
PointsPer = 0.5
gosub %CurrentLoopCode%
Name = Firefighter Completed
IconName = Firefighter
PointsPer = 6
gosub %CurrentLoopCode%
Name = Paramedic Max Level
IconName = Paramedic
PointsPer = 0
PointsPerText := "10n"
gosub %CurrentLoopCode%
return

