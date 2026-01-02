-- StarterPlayerScripts / RTSAdminPanel.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local plr = Players.LocalPlayer
local mouse = plr:GetMouse()

-- [[ CONFIGURATION ]]
local OWNER_ID = 1962138076 -- REPLACE THIS WITH YOUR USER ID!
if plr.UserId ~= OWNER_ID then 
	script:Destroy() 
	return 
end

local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local AdminRemote = Remotes:WaitForChild("RTSAdminAction")

-- [[ GUI CREATION ]]
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RTSAdmin"
screenGui.ResetOnSpawn = false
screenGui.Enabled = false -- Hidden by default
screenGui.Parent = plr:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.fromOffset(500, 350)
mainFrame.Position = UDim2.fromScale(0.5, 0.5)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(255, 0, 255) -- Purple Border
mainFrame.Parent = screenGui

local title = Instance.new("TextLabel", mainFrame)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBlack
title.Text = "  ADMIN CONTROL PANEL (Owner Only)"
title.TextXAlignment = Enum.TextXAlignment.Left

-- [[ TABS ]]
local tabContainer = Instance.new("Frame", mainFrame)
tabContainer.Position = UDim2.new(0, 0, 0, 30)
tabContainer.Size = UDim2.new(0, 100, 1, -30)
tabContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 40)

local contentContainer = Instance.new("Frame", mainFrame)
contentContainer.Position = UDim2.new(0, 110, 0, 40)
contentContainer.Size = UDim2.new(1, -120, 1, -50)
contentContainer.BackgroundTransparency = 1

local tabs = {"Units", "Buildings", "Map", "Resources", "Tools"}
local activeTool = nil 
local toolData = {}

local function clearContent()
	contentContainer:ClearAllChildren()
end

local function createGrid()
	local g = Instance.new("UIGridLayout", contentContainer)
	g.CellSize = UDim2.fromOffset(110, 40)
	g.CellPadding = UDim2.fromOffset(10, 10)
	return g
end

local function makeBtn(text, color, callback)
	local b = Instance.new("TextButton", contentContainer)
	b.BackgroundColor3 = color or Color3.fromRGB(60, 60, 70)
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Text = text

	local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 4)
	b.MouseButton1Click:Connect(callback)
	return b
end

-- [[ TOOL LOOP ]]
RunService.RenderStepped:Connect(function()
	if not screenGui.Enabled then 
		activeTool = nil 
		return 
	end

	if activeTool then
		mouse.Icon = "rbxasset://textures/ArrowCursor.png"
		if activeTool == "Destroy" then
			mouse.Icon = "rbxasset://textures/DragCursor.png"
		elseif activeTool == "PaintTile" then
			mouse.Icon = "rbxasset://textures/StudioToolbox/PaintBucket.png"
		end
	else
		mouse.Icon = ""
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.P then
		screenGui.Enabled = not screenGui.Enabled
		activeTool = nil
	end

	if not screenGui.Enabled then return end
	if gp then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 and activeTool then
		local hit = mouse.Hit.Position
		local target = mouse.Target

		if activeTool == "SpawnUnit" then
			AdminRemote:FireServer("SpawnUnit", {
				Type = toolData.UnitType, 
				Pos = hit, 
				Enemy = toolData.IsEnemy
			})

		elseif activeTool == "PaintTile" and target then
			local tile = target:FindFirstAncestorOfClass("Model")
			if tile and string.match(tile.Name, "^Hex") then
				AdminRemote:FireServer("Tile", { Target = tile, TileName = toolData.TileName })
			end

		elseif activeTool == "PlaceBuild" then
			AdminRemote:FireServer("Building", { Name = toolData.BuildName, Pos = hit })

		elseif activeTool == "Destroy" and target then
			local model = target:FindFirstAncestorOfClass("Model")
			AdminRemote:FireServer("Destroy", {Target = model or target})
		end
	end
end)

-- [[ TAB LOGIC ]]
-- [[ TAB LOGIC ]]
local function loadTab(name)
	clearContent()
	activeTool = nil

	if name == "Units" then
		createGrid()
		-- FRIENDLY UNITS (GREEN)
		makeBtn("My Builder", Color3.fromRGB(50, 150, 50), function()
			activeTool = "SpawnUnit"
			toolData = { UnitType = "Builder", IsEnemy = false }
		end)
		makeBtn("My Peasant", Color3.fromRGB(50, 150, 50), function()
			activeTool = "SpawnUnit"
			toolData = { UnitType = "WarPeasant", IsEnemy = false }
		end)
		-- [[ ADDED ARCHER HERE ]] --
		makeBtn("My Archer", Color3.fromRGB(50, 150, 50), function()
			activeTool = "SpawnUnit"
			toolData = { UnitType = "Archer", IsEnemy = false }
		end)

		-- ENEMY UNITS (RED)
		makeBtn("Enemy Builder", Color3.fromRGB(180, 50, 50), function()
			activeTool = "SpawnUnit"
			toolData = { UnitType = "Builder", IsEnemy = true }
		end)
		makeBtn("Enemy Peasant", Color3.fromRGB(180, 50, 50), function()
			activeTool = "SpawnUnit"
			toolData = { UnitType = "WarPeasant", IsEnemy = true }
		end)
		-- [[ ADDED ARCHER HERE ]] --
		makeBtn("Enemy Archer", Color3.fromRGB(180, 50, 50), function()
			activeTool = "SpawnUnit"
			toolData = { UnitType = "Archer", IsEnemy = true }
		end)

	elseif name == "Buildings" then
		createGrid()
		-- PLACE BUILDINGS (click world to place)
		makeBtn("Barracks", Color3.fromRGB(100, 100, 200), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "RTSBarracks" }
		end)
		makeBtn("Archer Tower", Color3.fromRGB(100, 100, 200), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "ArcherTower" }
		end)
		makeBtn("Palisade", Color3.fromRGB(120, 120, 160), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "Palisade" }
		end)
		makeBtn("Palisade II", Color3.fromRGB(120, 120, 160), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "Palisade2" }
		end)
		makeBtn("House", Color3.fromRGB(70, 140, 70), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "House" }
		end)
		makeBtn("Farm", Color3.fromRGB(70, 140, 70), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "Farm" }
		end)
		makeBtn("Sawmill", Color3.fromRGB(70, 140, 70), function()
			activeTool = "PlaceBuild"
			toolData = { BuildName = "RTSSawmill" }
		end)

	elseif name == "Map" then
		createGrid()
		local tiles = {"GrassTile", "DirtTile", "StoneTile", "WaterTile", "SandTile"}
		for _, t in ipairs(tiles) do
			makeBtn(t, Color3.fromRGB(80, 80, 100), function()
				activeTool = "PaintTile"
				toolData = { TileName = t }
			end)
		end

	elseif name == "Resources" then
		createGrid()
		makeBtn("+1000 Gold", Color3.fromRGB(255, 200, 50), function() AdminRemote:FireServer("Resources", {Gold=1000}) end)
		makeBtn("+1000 Wood", Color3.fromRGB(160, 100, 50), function() AdminRemote:FireServer("Resources", {Wood=1000}) end)
		makeBtn("+1000 Stone", Color3.fromRGB(140, 140, 140), function() AdminRemote:FireServer("Resources", {Stone=1000}) end)
		makeBtn("+10 PopCap", Color3.fromRGB(80, 200, 255), function() AdminRemote:FireServer("Population", {Delta=10}) end)
		makeBtn("-10 PopCap", Color3.fromRGB(80, 200, 255), function() AdminRemote:FireServer("Population", {Delta=-10}) end)
		makeBtn("Reset Res", Color3.fromRGB(200, 50, 50), function() AdminRemote:FireServer("Resources", {Gold=-999999, Wood=-999999}) end)

	elseif name == "Tools" then
		createGrid()
		makeBtn("DESTROYER", Color3.fromRGB(255, 0, 0), function() activeTool = "Destroy" end)
		makeBtn("Force Barracks", Color3.fromRGB(100, 100, 200), function() activeTool = "PlaceBuild"; toolData = {BuildName="RTSBarracks"} end)
	end
end

local layout = Instance.new("UIListLayout", tabContainer)
layout.Padding = UDim.new(0, 5)

for _, name in ipairs(tabs) do
	local b = Instance.new("TextButton", tabContainer)
	b.Size = UDim2.new(1, 0, 0, 40)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	b.TextColor3 = Color3.new(1,1,1)
	b.Font = Enum.Font.GothamBold
	b.Text = name
	b.MouseButton1Click:Connect(function() loadTab(name) end)
end

loadTab("Units")