local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(script.Parent.AdminConfig)
local Components = require(script.Parent.AdminComponents)

local plr = Players.LocalPlayer
local mouse = plr:GetMouse()

if plr.UserId ~= Config.OWNER_ID then 
	script:Destroy()
	return 
end

local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local AdminRemote = Remotes:WaitForChild("RTSAdminAction")

-- State
local activeTool = nil
local toolData = {}

-- Setup UI
local screenGui = Components.createGui(plr)
local mainFrame = Components.createMainFrame(screenGui)
local tabContainer, contentContainer = Components.createContainers(mainFrame)

-- Logic
local function clearContent()
	for _, c in ipairs(contentContainer:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

local function loadTab(tabData)
	clearContent()
	activeTool = nil

	for _, btnDef in ipairs(tabData.Buttons) do
		Components.createToolButton(contentContainer, btnDef.Text, btnDef.Color, function()
			if btnDef.Action then
				-- Immediate Action (Resources, Pop)
				AdminRemote:FireServer(btnDef.Action, btnDef.Data)
			elseif btnDef.Tool then
				-- Select Tool
				activeTool = btnDef.Tool
				toolData = btnDef.Data or {}
			end
		end)
	end
end

-- Create Tabs
for _, tab in ipairs(Config.TABS) do
	Components.createTabButton(tabContainer, tab.Name, function()
		loadTab(tab)
	end)
end
loadTab(Config.TABS[1]) -- Load first tab

-- Loops & Input
RunService.RenderStepped:Connect(function()
	if not screenGui.Enabled then 
		activeTool = nil 
		mouse.Icon = ""
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
	-- Toggle Panel
	if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.P then
		screenGui.Enabled = not screenGui.Enabled
		activeTool = nil
	end

	if not screenGui.Enabled or gp then return end

	-- Use Tool
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
			AdminRemote:FireServer("Destroy", { Target = model or target })
		end
	end
end)