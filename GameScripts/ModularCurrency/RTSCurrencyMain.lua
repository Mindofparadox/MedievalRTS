local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")

local Config = require(script.Parent.CurrencyConfig)
local Components = require(script.Parent.CurrencyComponents)

local player = Players.LocalPlayer
local unitsFolder = Workspace:WaitForChild("RTSUnits")
local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local CameraReturn = Remotes:WaitForChild("CameraReturn")
local ClientNotify = Remotes:WaitForChild("ClientNotify")

-- 1. Setup UI
local gui = Components.createScreenGui(player)
local frame = Components.createMainFrame(gui)
local homeBtn = Components.createHomeButton(gui)

-- 2. Create Rows
local ValueLabels = {} 
for i, def in ipairs(Config.RESOURCES) do
	local _, valueLabel = Components.createRow(frame, def, i)
	ValueLabels[def.Key] = valueLabel
end

---------------------------------------------------------------------
-- LOGIC & OPTIMIZATION
---------------------------------------------------------------------
local refreshPending = false

local BUILDING_POP_COST = {
	Farm = 5,
	RTSSawmill = 5,
}

local function calculatePopulation()
	local pop = 0

	-- 1. Count Units
	for _, u in ipairs(unitsFolder:GetChildren()) do
		if u:GetAttribute("OwnerUserId") == player.UserId then
			pop += 1
		end
	end

	-- 2. Count Pop-Cost Buildings (NOTE: buildings are named after the tile, e.g. "Hex_...", so do NOT filter by name)
	for _, b in ipairs(Workspace:GetChildren()) do
		if b:IsA("Model") and b:GetAttribute("OwnerUserId") == player.UserId then
			local bType = b:GetAttribute("BuildingType")
			local cost = bType and BUILDING_POP_COST[bType]
			if cost then
				-- Match server logic: pop is consumed as soon as the building is placed (even while UnderConstruction)
				pop += cost
			end
		end
	end

	return pop
end

local function performRefresh()
	refreshPending = false

	-- Basic Resources
	ValueLabels.Gold.Text = tostring(player:GetAttribute("Gold") or 0)
	ValueLabels.Wood.Text = tostring(player:GetAttribute("Wood") or 0)
	ValueLabels.Stone.Text = tostring(player:GetAttribute("Stone") or 0)

	-- Population
	local maxPop = player:GetAttribute("MaxPopulation") or 10
	local currentPop = calculatePopulation()

	ValueLabels.Pop.Text = string.format("%d/%d", currentPop, maxPop)

	if currentPop >= maxPop then
		ValueLabels.Pop.TextColor3 = Config.COLORS.TextAlert
	else
		ValueLabels.Pop.TextColor3 = Config.COLORS.TextValue
	end
end

-- DEBOUNCE: Prevents the script from running 2000 times in 1 second

-- Pop flash (used when a player tries to exceed population cap)
local popFlashToken = 0
local function flashPopLabel()
	popFlashToken += 1
	local token = popFlashToken

	local label = ValueLabels and ValueLabels.Pop
	if not label then return end

	-- Base color depends on current state (full cap stays red)
	local maxPop = player:GetAttribute("MaxPopulation") or 10
	local currentPop = calculatePopulation()
	local baseColor = (currentPop >= maxPop) and Config.COLORS.TextAlert or Config.COLORS.TextValue

	-- Quick red flash (doesn't permanently change the state color)
	local function setColor(c)
		if popFlashToken ~= token then return end
		label.TextColor3 = c
	end

	task.spawn(function()
		for _ = 1, 3 do
			setColor(Config.COLORS.TextAlert)
			task.wait(0.12)
			setColor(baseColor)
			task.wait(0.12)
		end
	end)
end

local function pushNotify(title, text, duration)
	-- Some experiences disable Core; protect with pcall
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Notice",
			Text = text or "",
			Duration = duration or 2,
		})
	end)
end

-- Listen for server-side warnings (population cap, etc.)
ClientNotify.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end

	if payload.Kind == "PopFull" then
		if payload.FlashPop then
			flashPopLabel()
		end
		pushNotify(payload.Title or "Population full", payload.Text or "Not enough population capacity.", 2.5)
	end
end)

local function requestRefresh()
	if not refreshPending then
		refreshPending = true
		-- Wait until the end of the current frame to update
		RunService.Heartbeat:Wait()
		performRefresh()
	end
end

---------------------------------------------------------------------
-- LISTENERS
---------------------------------------------------------------------

-- Player Attributes
player:GetAttributeChangedSignal("Gold"):Connect(requestRefresh)
player:GetAttributeChangedSignal("Wood"):Connect(requestRefresh)
player:GetAttributeChangedSignal("Stone"):Connect(requestRefresh)
player:GetAttributeChangedSignal("MaxPopulation"):Connect(requestRefresh)

-- Unit Changes
unitsFolder.ChildAdded:Connect(requestRefresh)
unitsFolder.ChildRemoved:Connect(requestRefresh)

-- Building Changes
local function watchBuilding(model)
	if not model:IsA("Model") then return end

	-- Defer one tick so attributes (OwnerUserId/BuildingType/UnderConstruction) have time to be applied
	task.defer(function()
		if not model.Parent then return end

		local isBuilding = (model:GetAttribute("IsBuilding") == true) or (model:GetAttribute("BuildingType") ~= nil)
		if not isBuilding then return end

		requestRefresh()

		-- Update when construction state or type changes
		model:GetAttributeChangedSignal("UnderConstruction"):Connect(requestRefresh)
		model:GetAttributeChangedSignal("BuildingType"):Connect(requestRefresh)
		model:GetAttributeChangedSignal("OwnerUserId"):Connect(requestRefresh)
	end)
end

Workspace.ChildAdded:Connect(watchBuilding)
Workspace.ChildRemoved:Connect(function(child)
	if not child:IsA("Model") then return end

	-- Buildings are named after tiles (often "Hex_..."), so don't filter by name.
	-- Only refresh if it was actually a building.
	local isBuilding = (child:GetAttribute("IsBuilding") == true) or (child:GetAttribute("BuildingType") ~= nil)
	if isBuilding then
		requestRefresh()
	end
end)

-- Initialize existing buildings
for _, child in ipairs(Workspace:GetChildren()) do
	watchBuilding(child)
end

-- Home Button
homeBtn.MouseButton1Click:Connect(function()
	local basePos = player:GetAttribute("RTS_BasePos")
	if basePos then
		CameraReturn:Fire(basePos)
	end
end)

-- Initial Load
requestRefresh()