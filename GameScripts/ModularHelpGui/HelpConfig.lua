local HelpConfig = {}

-- VISUALS
HelpConfig.COLORS = {
	MainBackground = Color3.fromRGB(30, 30, 35),
	HeaderBackground = Color3.fromRGB(40, 40, 45),
	ButtonBackground = Color3.fromRGB(40, 40, 45),
	KeyCapBackground = Color3.fromRGB(20, 20, 20),
	RowBackground = Color3.fromRGB(50, 50, 55),
	TextNormal = Color3.fromRGB(230, 230, 230),
	TextHeader = Color3.fromRGB(220, 220, 220),
	TextKey = Color3.fromRGB(255, 200, 80),
	TextSection = Color3.fromRGB(150, 150, 160),
	CloseRed = Color3.fromRGB(255, 100, 100),
	Stroke = Color3.fromRGB(80, 80, 90),
}

HelpConfig.FONTS = {
	Title = Enum.Font.GothamBlack,
	Action = Enum.Font.GothamMedium,
	Key = Enum.Font.GothamBold,
}

HelpConfig.SIZES = {
	WindowSize = UDim2.fromOffset(500, 620),
	ButtonSize = UDim2.fromOffset(50, 50),
}

-- DATA: The list of controls to display
HelpConfig.CONTROLS_DATA = {
	{
		Section = "- CAMERA -",
		Entries = {
			{Key = "W, A, S, D", Action = "Pan Camera Position"},
			{Key = "Scroll Wheel", Action = "Zoom In / Out"},
			{Key = "MMB Press", Action = "Rotate Camera Angle"},
		}
	},
	{
		Section = "- SELECTION -",
		Entries = {
			{Key = "Left Click", Action = "Select Unit / Interact"},
			{Key = "LMB Drag", Action = "Box Select Multiple Units"},
			{Key = "Ctrl + LMB Drag", Action = "Box Select Trees Only"},
			{Key = "Double Click", Action = "Select All Units of Type"},
		}
	},
	{
		Section = "- COMMANDS -",
		Entries = {
			{Key = "Right Click", Action = "Move / Attack / Work"},
			{Key = "Shift + RMB", Action = "Queue Multiple Orders"},
			{Key = "RMB Drag", Action = "Set Unit Facing Direction"},
			{Key = "C Key", Action = "Cancel Selection / Stop"},
		}
	},
	{
		Section = "- ACTIONS -",
		Entries = {
			{Key = "F Key", Action = "Mark Tree for Chopping"},
			{Key = "G Key", Action = "Mark Stone for Mining"},
			{Key = "Q / E", Action = "Rotate Building Placement"},
			{Key = "Esc / RMB (placing)", Action = "Cancel Building Placement"},
		}
	},
	{
		Section = "- GARRISON -",
		Entries = {
			{Key = "E Key (on Tower)", Action = "Garrison Archers (RMB Move to Ungarrison)"},
		}
	}
}

return HelpConfig
