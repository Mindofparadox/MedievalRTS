--// StarterPlayerScripts / RTSController.lua
--// Selection, Command Move, Path Visuals, Hover Highlights, AND HEALTH BARS

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local CommandMove = Remotes:WaitForChild("CommandMove")
local CommandGarrisonTower = Remotes:WaitForChild("CommandGarrisonTower")
local PathUpdate = Remotes:WaitForChild("PathUpdate")
local CommandChopTree = Remotes:WaitForChild("CommandChopTree")
local CommandCancel = Remotes:WaitForChild("CommandCancel")
local ToggleTreeMark = Remotes:WaitForChild("ToggleTreeMark")
local RecruitUnit = Remotes:WaitForChild("RecruitUnit")
local UpdateBaseQueue = Remotes:WaitForChild("UpdateBaseQueue")
local CommandPlaceBuilding = Remotes:WaitForChild("CommandPlaceBuilding") -- Ensure this exists
local VisualEffect = Remotes:WaitForChild("VisualEffect")
local DeleteUnit = Remotes:WaitForChild("DeleteUnit")


local unitsFolder = workspace:WaitForChild("RTSUnits")
local startPlacement, cancelPlacement, updateGhost

-- [[ PLACEMENT STATE ]]
local isPlacing = false
local placementGhost = nil
local recruitConnection = nil -- Store the button connection here
local placementName = nil
local placementRotation = 0 -- 0 to 5
local placementOffset = CFrame.new()
local currentSelectedBuilding = nil -- Global tracker for the script

-- [[ 1. NEW HELPER FUNCTION ]] --
local function getIgnoreList()
	local list = { unitsFolder }

	-- Ignore the building ghost itself
	if placementGhost then
		table.insert(list, placementGhost)
	end

	-- Ignore Decorative Grass so we can click "through" it
	local decor = workspace:FindFirstChild("RTS_Decor")
	if decor then table.insert(list, decor) end

	-- Ignore Resource Nodes (Rocks) so we snap to the ground
	local res = workspace:FindFirstChild("ResourceNodes")
	if res then table.insert(list, res) end

	return list
end
---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local BUILDER_RANGE = 18 
local HEALTH_BAR_SHOW_DIST = 60 -- Distance to show health bars


-- [[ NEW: RESPONSIVE SCALING FUNCTION ]] --
local function makeResponsive(frame)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = frame

	local function update()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize

		-- 1. Base Scale on Height (Target: 900px height standard)
		local targetHeight = 900
		local scale = math.clamp(vp.Y / targetHeight, 0.6, 1.3)

		-- 2. Width Constraint (Ensure it never exceeds screen width)
		-- We use the frame's offset width to check if it fits
		local frameWidth = frame.Size.X.Offset
		if frameWidth > 0 then
			local maxScale = (vp.X * 0.9) / frameWidth -- Keep 90% screen width max
			if scale > maxScale then
				scale = maxScale
			end
		end

		uiScale.Scale = scale
	end

	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

---------------------------------------------------------------------
-- UI: SELECTION & ACTION PANEL
---------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "RTSSelectionGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local selBox = Instance.new("Frame")
selBox.Visible = false
selBox.BackgroundTransparency = 0.8
selBox.BorderSizePixel = 1
selBox.Parent = gui

-- [[ 1. ACTION PANEL (RECRUITMENT & QUEUE) ]] --
local actionFrame = Instance.new("Frame")
actionFrame.Name = "ActionFrame"
actionFrame.Size = UDim2.fromOffset(420, 160) -- Wider and taller for cards
actionFrame.AnchorPoint = Vector2.new(0.5, 1) 
actionFrame.Position = UDim2.new(0.5, 0, 0.98, 0) -- Bottom Center
actionFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
actionFrame.BorderSizePixel = 0
actionFrame.Visible = false
actionFrame.Parent = gui

makeResponsive(actionFrame) 

local afCorner = Instance.new("UICorner", actionFrame)
afCorner.CornerRadius = UDim.new(0, 8)

local afStroke = Instance.new("UIStroke", actionFrame)
afStroke.Color = Color3.fromRGB(60, 60, 60)
afStroke.Thickness = 1.5

-- Container for Unit Cards
local unitsContainer = Instance.new("ScrollingFrame")
unitsContainer.Name = "UnitsContainer"
unitsContainer.BackgroundTransparency = 1
unitsContainer.Position = UDim2.new(0, 10, 0, 35)
unitsContainer.Size = UDim2.new(1, -20, 0, 90)
unitsContainer.CanvasSize = UDim2.new(0, 0, 0, 0) -- Auto-scales
unitsContainer.ScrollBarThickness = 4
unitsContainer.Parent = actionFrame

local unitsLayout = Instance.new("UIListLayout", unitsContainer)
unitsLayout.FillDirection = Enum.FillDirection.Horizontal
unitsLayout.SortOrder = Enum.SortOrder.LayoutOrder
unitsLayout.Padding = UDim.new(0, 10)

-- Header Title
local menuTitle = Instance.new("TextLabel")
menuTitle.Name = "Title"
menuTitle.Text = "BUILDING NAME"
menuTitle.Font = Enum.Font.GothamBlack
menuTitle.TextSize = 14
menuTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
menuTitle.BackgroundTransparency = 1
menuTitle.Size = UDim2.new(1, -20, 0, 30)
menuTitle.Position = UDim2.new(0, 15, 0, 0)
menuTitle.TextXAlignment = Enum.TextXAlignment.Left
menuTitle.Parent = actionFrame

-- [[ QUEUE VISUALIZATION ]] --
local queuePanel = Instance.new("Frame")
queuePanel.Name = "QueuePanel"
queuePanel.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
queuePanel.Size = UDim2.new(1, 0, 0, 30)
queuePanel.Position = UDim2.new(0, 0, 1, -30)
queuePanel.BorderSizePixel = 0
queuePanel.Parent = actionFrame

local qLayout = Instance.new("UIListLayout", queuePanel)
qLayout.FillDirection = Enum.FillDirection.Horizontal
qLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
qLayout.VerticalAlignment = Enum.VerticalAlignment.Center
qLayout.Padding = UDim.new(0, 4)

local queueLabel = Instance.new("TextLabel")
queueLabel.Name = "QueueLabel" -- Keeps track of text status
queueLabel.Text = "QUEUE EMPTY"
queueLabel.Font = Enum.Font.GothamBold
queueLabel.TextSize = 10
queueLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
queueLabel.Size = UDim2.new(0, 100, 1, 0)
queueLabel.BackgroundTransparency = 1
queueLabel.Parent = queuePanel

-- [[ HELPER: RESET QUEUE UI ]] --
local function resetQueueUI()
	-- Clear all visual slots (Frames) but keep the Layout and TextLabel
	for _, c in ipairs(queuePanel:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	-- Reset Label
	queueLabel.Visible = true
	queueLabel.Text = "QUEUE EMPTY"
end

-- [[ CLIENT UNIT DATA (For visuals) ]] --
local CLIENT_UNIT_DATA = {
	Builder = { Name="Builder", Icon="rbxassetid://116085849000507", Cost="100 G | 50 W" },
	WarPeasant = { Name="Peasant", Icon="rbxassetid://10900985226", Cost="75 G | 25 W" },
	Archer = { Name="Archer", Icon="rbxassetid://169974129", Cost="100 G | 80 W" }
}

-- Helper: Create a nice Unit Card
local function createUnitCard(unitType, callback)
	local data = CLIENT_UNIT_DATA[unitType] or {Name=unitType, Icon="", Cost="???"}

	local btn = Instance.new("ImageButton")
	btn.Name = unitType.."_Card"
	btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
	btn.Size = UDim2.fromOffset(80, 90)
	btn.AutoButtonColor = false
	btn.Parent = unitsContainer

	local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 6)

	-- Hover Effect
	btn.MouseEnter:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(55, 55, 60) end)
	btn.MouseLeave:Connect(function() btn.BackgroundColor3 = Color3.fromRGB(45, 45, 50) end)

	-- Icon
	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(40, 40)
	icon.Position = UDim2.new(0.5, 0, 0, 8)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Image = data.Icon
	icon.Parent = btn

	-- Name
	local name = Instance.new("TextLabel")
	name.Text = data.Name
	name.Font = Enum.Font.GothamBold
	name.TextSize = 11
	name.TextColor3 = Color3.new(1,1,1)
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1,0,0,15)
	name.Position = UDim2.new(0,0,0,50)
	name.Parent = btn

	-- Cost
	local cost = Instance.new("TextLabel")
	cost.Text = data.Cost
	cost.Font = Enum.Font.Gotham
	cost.TextSize = 9
	cost.TextColor3 = Color3.fromRGB(255, 200, 80) -- Gold color
	cost.BackgroundTransparency = 1
	cost.Size = UDim2.new(1,0,0,15)
	cost.Position = UDim2.new(0,0,0,65)
	cost.Parent = btn

	btn.MouseButton1Click:Connect(callback)
end

-- Helper: Refresh the Action Menu
local function refreshActionMenu(title, unitsList, buildModel)
	menuTitle.Text = string.upper(title)

	-- Clear old cards
	for _, c in ipairs(unitsContainer:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end

	-- Create new cards
	for _, uType in ipairs(unitsList) do
		createUnitCard(uType, function()
			-- Click Logic
			RecruitUnit:FireServer(uType, buildModel)
		end)
	end
end


---------------------------------------------------------------------
-- [[ 2. CONSTRUCTION GUI SYSTEM ]]
---------------------------------------------------------------------

-- Toggle Button (HUD) - Next to Home Button
local openBuildBtn = Instance.new("TextButton")
openBuildBtn.Name = "OpenBuildMenuBtn"
openBuildBtn.Text = "BUILD"
openBuildBtn.Font = Enum.Font.GothamBlack
openBuildBtn.TextSize = 14
openBuildBtn.TextColor3 = Color3.new(1, 1, 1)
openBuildBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
openBuildBtn.AutoButtonColor = true
-- Positioned left of the Home Button
openBuildBtn.Position = UDim2.new(1, -80, 1, -25) 
openBuildBtn.Size = UDim2.fromOffset(80, 40)
openBuildBtn.AnchorPoint = Vector2.new(1, 1)
openBuildBtn.Parent = gui

local obCorner = Instance.new("UICorner", openBuildBtn)
obCorner.CornerRadius = UDim.new(0, 6)

-- Main Construction Window
local buildFrame = Instance.new("Frame")
buildFrame.Name = "ConstructionGUI"
-- [[ CHANGED WIDTH FROM 460 TO 550 TO FIT TABS ]] --
buildFrame.Size = UDim2.fromOffset(550, 300) 
buildFrame.Position = UDim2.fromScale(0.5, 0.5) -- Center Screen
buildFrame.AnchorPoint = Vector2.new(0.5, 0.5)
buildFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
buildFrame.BorderSizePixel = 0
buildFrame.Visible = false
buildFrame.Parent = gui

makeResponsive(buildFrame) -- <--- Auto-Scale Applied

local bfCorner = Instance.new("UICorner", buildFrame)
bfCorner.CornerRadius = UDim.new(0, 8)

-- Header
local buildTitle = Instance.new("TextLabel")
buildTitle.Text = "CONSTRUCTION"
buildTitle.Font = Enum.Font.GothamBlack
buildTitle.TextSize = 14
buildTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
buildTitle.BackgroundTransparency = 1
buildTitle.Size = UDim2.new(1, -40, 0, 30)
buildTitle.Position = UDim2.new(0, 15, 0, 0)
buildTitle.TextXAlignment = Enum.TextXAlignment.Left
buildTitle.Parent = buildFrame

-- Close Button
local closeBuildBtn = Instance.new("TextButton")
closeBuildBtn.Text = "X"
closeBuildBtn.Font = Enum.Font.GothamBold
closeBuildBtn.TextSize = 14
closeBuildBtn.TextColor3 = Color3.fromRGB(200, 100, 100)
closeBuildBtn.BackgroundTransparency = 1
closeBuildBtn.Size = UDim2.fromOffset(30, 30)
closeBuildBtn.Position = UDim2.new(1, -35, 0, 0)
closeBuildBtn.Parent = buildFrame

-- Tabs Container
local tabsContainer = Instance.new("Frame")
tabsContainer.Name = "Tabs"
tabsContainer.BackgroundTransparency = 1
tabsContainer.Position = UDim2.new(0, 10, 0, 35)
tabsContainer.Size = UDim2.new(1, -20, 0, 25)
tabsContainer.Parent = buildFrame

local tabsLayout = Instance.new("UIListLayout", tabsContainer)
tabsLayout.FillDirection = Enum.FillDirection.Horizontal
tabsLayout.Padding = UDim.new(0, 5)

-- Content Area
local contentArea = Instance.new("Frame")
contentArea.Name = "Content"
contentArea.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
contentArea.Position = UDim2.new(0, 10, 0, 70)
contentArea.Size = UDim2.new(1, -20, 1, -80)
contentArea.Parent = buildFrame

local contentCorner = Instance.new("UICorner", contentArea)
contentCorner.CornerRadius = UDim.new(0, 6)

-- [[ Logic: Tabs ]]
local buildCategories = {
	"Production", "Fortifications", "Housing", 
	"Military", "Stockpiles", "Infrastructure", "Trade"
}

local categoryFrames = {}
local tabButtons = {}

-- Helper to count client-side buildings for UI updates
-- [[ HELPER: Count Buildings & Update Prices ]]
local function getClientBuildingCount(bType)
	local count = 0
	local myId = player.UserId
	for _, b in ipairs(workspace:GetChildren()) do
		if b:IsA("Model") and b:GetAttribute("OwnerUserId") == myId and b:GetAttribute("BuildingType") == bType then
			count = count + 1
		end
	end
	return count
end

local function updateHousingCosts()
	-- Only run if the Housing tab exists
	local scroll = categoryFrames["Housing"]
	if not scroll then return end

	local btn = scroll:FindFirstChild("HouseBtn")
	if not btn then return end

	local lbl = btn:FindFirstChild("CostLabel")
	if lbl then
		local count = getClientBuildingCount("House")

		-- [[ FORMULA MUST MATCH SERVER ]]
		local newG = 50 + (count * 25)
		local newW = 100 + (count * 25)

		lbl.Text = newG .. " G | " .. newW .. " W"
	end
end

local function openTab(tabName)
	for name, frame in pairs(categoryFrames) do
		frame.Visible = (name == tabName)
	end
	for name, btn in pairs(tabButtons) do
		if name == tabName then
			btn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
			btn.TextColor3 = Color3.new(1, 1, 1)
		else
			btn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
			btn.TextColor3 = Color3.fromRGB(180, 180, 180)
		end
	end

	-- Force refresh whenever we open the Housing tab
	if tabName == "Housing" then
		updateHousingCosts()
	end
end

for _, catName in ipairs(buildCategories) do
	-- 1. Create the TAB BUTTON
	local tabBtn = Instance.new("TextButton")
	tabBtn.Name = catName.."_Btn"
	tabBtn.Parent = tabsContainer
	tabBtn.Text = catName
	tabBtn.Font = Enum.Font.GothamBold
	tabBtn.TextSize = 10
	tabBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	tabBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	tabBtn.AutoButtonColor = false
	tabBtn.AutomaticSize = Enum.AutomaticSize.X
	tabBtn.Size = UDim2.new(0, 0, 1, 0)

	local p = Instance.new("UIPadding", tabBtn)
	p.PaddingLeft = UDim.new(0, 8); p.PaddingRight = UDim.new(0, 8)
	local c = Instance.new("UICorner", tabBtn); c.CornerRadius = UDim.new(0, 4)

	-- 2. Create the SCROLL FRAME
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = catName.."_Scroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.ScrollBarThickness = 4
	scroll.Visible = false
	scroll.Parent = contentArea

	local grid = Instance.new("UIGridLayout", scroll)
	-- [[ UPDATED SIZE: Taller (125px) to fit all text without overlap ]]
	grid.CellSize = UDim2.fromOffset(130, 125) 
	grid.CellPadding = UDim2.fromOffset(8, 8)

	-- Helper function to create standard labels quickly
	local function createInfoLabels(parent, titleText, descText, hpText, costText)
		-- Title (Top)
		local title = Instance.new("TextLabel")
		title.Text = titleText
		title.Size = UDim2.new(1, 0, 0, 18)
		title.Position = UDim2.new(0, 0, 0, 2)
		title.BackgroundTransparency = 1
		title.TextColor3 = Color3.new(1,1,1)
		title.TextSize = 11
		title.Font = Enum.Font.GothamBlack
		title.Parent = parent

		-- Description (Below Title)
		local desc = Instance.new("TextLabel")
		desc.Text = descText
		desc.Size = UDim2.new(1, -8, 0, 28)
		desc.Position = UDim2.new(0, 4, 0, 20)
		desc.BackgroundTransparency = 1
		desc.TextColor3 = Color3.fromRGB(200, 200, 200)
		desc.TextSize = 9
		desc.TextWrapped = true
		desc.TextXAlignment = Enum.TextXAlignment.Left
		desc.TextYAlignment = Enum.TextYAlignment.Top
		desc.Parent = parent

		-- HP (Middle)
		local hpLabel = Instance.new("TextLabel")
		hpLabel.Text = "HP: " .. hpText
		hpLabel.Size = UDim2.new(1, -8, 0, 12)
		hpLabel.Position = UDim2.new(0, 4, 0, 50)
		hpLabel.BackgroundTransparency = 1
		hpLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
		hpLabel.TextSize = 9
		hpLabel.Font = Enum.Font.Gotham
		hpLabel.TextXAlignment = Enum.TextXAlignment.Left
		hpLabel.Parent = parent

		-- Cost (Bottom) -- [[ NAME ADDED HERE ]] --
		local cost = Instance.new("TextLabel")
		cost.Name = "CostLabel" 
		cost.Text = costText
		cost.Size = UDim2.new(1, 0, 0, 18)
		cost.Position = UDim2.new(0, 0, 1, -18)
		cost.BackgroundTransparency = 0.3
		cost.BackgroundColor3 = Color3.new(0,0,0)
		cost.TextColor3 = Color3.fromRGB(255, 200, 80)
		cost.TextSize = 10
		cost.Font = Enum.Font.GothamBold
		cost.Parent = parent

		return hpLabel 
	end

	-- [[ A. MILITARY TAB ]]
	if catName == "Military" then
		local btn = Instance.new("ImageButton")
		btn.Name = "BarracksBtn"
		btn.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn.Parent = scroll
		local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,6)

		local hpLbl = createInfoLabels(btn, "Barracks", "Trains Peasants & Archers.", "800", "150 G | 100 W")

		-- Extra Stats for Barracks
		local statLabel = Instance.new("TextLabel")
		statLabel.Text = "  Unlocks Units"
		statLabel.Size = UDim2.new(1, -8, 0, 12)
		statLabel.Position = UDim2.new(0, 4, 0, 64) -- Below HP
		statLabel.BackgroundTransparency = 1
		statLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
		statLabel.TextSize = 9
		statLabel.Font = Enum.Font.GothamBold
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
		statLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			startPlacement("RTSBarracks")
			buildFrame.Visible = false 
		end)

		local btn2 = Instance.new("ImageButton")
		btn2.Name = "ArcherTowerBtn"
		btn2.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn2.Parent = scroll
		local corner2 = Instance.new("UICorner", btn2); corner2.CornerRadius = UDim.new(0,6)

		-- Update description/cost
		createInfoLabels(btn2, "Archer Tower", "Garrisons Archers for defense.", "1000", "50 G | 150 W")

		-- Extra Stat Info
		local statLabel2 = Instance.new("TextLabel")
		statLabel2.Text = "  Holds 4 Archers"
		statLabel2.Size = UDim2.new(1, -8, 0, 12)
		statLabel2.Position = UDim2.new(0, 4, 0, 64) 
		statLabel2.BackgroundTransparency = 1
		statLabel2.TextColor3 = Color3.fromRGB(200, 200, 255)
		statLabel2.TextSize = 9
		statLabel2.Font = Enum.Font.GothamBold
		statLabel2.TextXAlignment = Enum.TextXAlignment.Left
		statLabel2.Parent = btn2

		btn2.MouseButton1Click:Connect(function()
			startPlacement("ArcherTower") 
			buildFrame.Visible = false
		end)
	end

	-- [[ FORTIFICATIONS TAB ]]
	if catName == "Fortifications" then
		-- 1. PALISADE 1 BUTTON (Fixed)
		local btn = Instance.new("ImageButton")
		btn.Name = "PalisadeBtn"
		btn.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn.Parent = scroll
		local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,6)

		local hpLbl = createInfoLabels(btn, "Palisade", "A sturdy wooden wall.", "1500", "20 G | 40 W")

		local statLabel = Instance.new("TextLabel")
		statLabel.Text = "  Basic Defense"
		statLabel.Size = UDim2.new(1, -8, 0, 12)
		statLabel.Position = UDim2.new(0, 4, 0, 64) 
		statLabel.BackgroundTransparency = 1
		statLabel.TextColor3 = Color3.fromRGB(200, 200, 255)
		statLabel.TextSize = 9
		statLabel.Font = Enum.Font.GothamBold
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
		statLabel.Parent = btn

		-- [[ FIX WAS HERE: Changed "RTSBarracks" to "Palisade" ]]
		btn.MouseButton1Click:Connect(function()
			startPlacement("Palisade") 
			buildFrame.Visible = false 
		end)

		-- 2. PALISADE 2 BUTTON (New)
		local btn2 = Instance.new("ImageButton")
		btn2.Name = "Palisade2Btn"
		btn2.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn2.Parent = scroll
		local corner2 = Instance.new("UICorner", btn2); corner2.CornerRadius = UDim.new(0,6)

		local hpLbl2 = createInfoLabels(btn2, "Palisade II", "Reinforced wall structure.", "2500", "40 G | 80 W")

		local statLabel2 = Instance.new("TextLabel")
		statLabel2.Text = "  Heavy Defense"
		statLabel2.Size = UDim2.new(1, -8, 0, 12)
		statLabel2.Position = UDim2.new(0, 4, 0, 64) 
		statLabel2.BackgroundTransparency = 1
		statLabel2.TextColor3 = Color3.fromRGB(200, 200, 255)
		statLabel2.TextSize = 9
		statLabel2.Font = Enum.Font.GothamBold
		statLabel2.TextXAlignment = Enum.TextXAlignment.Left
		statLabel2.Parent = btn2

		btn2.MouseButton1Click:Connect(function()
			startPlacement("Palisade2") -- Sends "Palisade2" to the placement system
			buildFrame.Visible = false
		end)
	end

	-- [[ B. HOUSING TAB ]]
	if catName == "Housing" then
		local btn = Instance.new("ImageButton")
		btn.Name = "HouseBtn"
		btn.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn.Parent = scroll
		local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,6)

		local hpLbl = createInfoLabels(btn, "House", "Increases your max population.", "400", "50 G | 100 W")

		-- Pop Bonus
		local popLabel = Instance.new("TextLabel")
		popLabel.Text = "+5 MAX POP"
		popLabel.Size = UDim2.new(1, -8, 0, 12)
		popLabel.Position = UDim2.new(0, 4, 0, 64) -- Below HP
		popLabel.BackgroundTransparency = 1
		popLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		popLabel.TextSize = 9
		popLabel.Font = Enum.Font.GothamBlack
		popLabel.TextXAlignment = Enum.TextXAlignment.Left
		popLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			startPlacement("House") 
			buildFrame.Visible = false
		end)
	end

	-- [[ C. PRODUCTION TAB ]]
	if catName == "Production" then
		-- 1. FARM
		local btn = Instance.new("ImageButton")
		btn.Name = "FarmBtn"
		btn.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn.Parent = scroll
		local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0,6)

		local hpLbl = createInfoLabels(btn, "Farm", "Generates passive Gold income.", "500", "100 G | 150 W")

		-- Stats (Stacked cleanly)
		local statLabel = Instance.new("TextLabel")
		statLabel.Text = "+5 GOLD/s"
		statLabel.Size = UDim2.new(1, -8, 0, 12)
		statLabel.Position = UDim2.new(0, 4, 0, 64) -- Row 4
		statLabel.BackgroundTransparency = 1
		statLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
		statLabel.TextSize = 9
		statLabel.Font = Enum.Font.GothamBlack
		statLabel.TextXAlignment = Enum.TextXAlignment.Left
		statLabel.Parent = btn

		local popLabel = Instance.new("TextLabel")
		popLabel.Text = "-5 POP USE"
		popLabel.Size = UDim2.new(1, -8, 0, 12)
		popLabel.Position = UDim2.new(0, 4, 0, 76) -- Row 5
		popLabel.BackgroundTransparency = 1
		popLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		popLabel.TextSize = 9
		popLabel.Font = Enum.Font.GothamBlack
		popLabel.TextXAlignment = Enum.TextXAlignment.Left
		popLabel.Parent = btn

		btn.MouseButton1Click:Connect(function()
			startPlacement("Farm") 
			buildFrame.Visible = false
		end)

		-- 2. SAWMILL
		local btn2 = Instance.new("ImageButton")
		btn2.Name = "SawmillBtn"
		btn2.BackgroundColor3 = Color3.fromRGB(60,60,65)
		btn2.Parent = scroll
		local corner2 = Instance.new("UICorner", btn2); corner2.CornerRadius = UDim.new(0,6)

		local hpLbl2 = createInfoLabels(btn2, "Sawmill", "Generates passive Wood income.", "600", "150 G | 50 W")

		-- Stats (Stacked cleanly)
		local statLabel2 = Instance.new("TextLabel")
		statLabel2.Text = "+2 WOOD/s"
		statLabel2.Size = UDim2.new(1, -8, 0, 12)
		statLabel2.Position = UDim2.new(0, 4, 0, 64) -- Row 4
		statLabel2.BackgroundTransparency = 1
		statLabel2.TextColor3 = Color3.fromRGB(205, 133, 63)
		statLabel2.TextSize = 9
		statLabel2.Font = Enum.Font.GothamBlack
		statLabel2.TextXAlignment = Enum.TextXAlignment.Left
		statLabel2.Parent = btn2

		local popLabel2 = Instance.new("TextLabel")
		popLabel2.Text = "-5 POP USE"
		popLabel2.Size = UDim2.new(1, -8, 0, 12)
		popLabel2.Position = UDim2.new(0, 4, 0, 76) -- Row 5
		popLabel2.BackgroundTransparency = 1
		popLabel2.TextColor3 = Color3.fromRGB(255, 100, 100)
		popLabel2.TextSize = 9
		popLabel2.Font = Enum.Font.GothamBlack
		popLabel2.TextXAlignment = Enum.TextXAlignment.Left
		popLabel2.Parent = btn2

		btn2.MouseButton1Click:Connect(function()
			startPlacement("RTSSawmill") 
			buildFrame.Visible = false
		end)
	end

	categoryFrames[catName] = scroll
	tabButtons[catName] = tabBtn

	tabBtn.MouseButton1Click:Connect(function() openTab(catName) end)
end

-- Force Open Default Tab
openTab("Production")
-- Logic: Open/Close
openBuildBtn.MouseButton1Click:Connect(function() 
	buildFrame.Visible = not buildFrame.Visible

	if buildFrame.Visible then
		-- Refresh costs immediately when opening
		updateHousingCosts()
	end
end)
closeBuildBtn.MouseButton1Click:Connect(function() buildFrame.Visible = false end)


-- Container for health bars
local hpContainer = Instance.new("Folder")
hpContainer.Name = "HealthBars"
hpContainer.Parent = gui

---------------------------------------------------------------------
-- VISUALS: Hover Highlight & Radius
---------------------------------------------------------------------
local hoverHighlight = Instance.new("Highlight")
hoverHighlight.Name = "RTS_HoverHighlight"
hoverHighlight.FillTransparency = 1        
hoverHighlight.OutlineTransparency = 0.2
hoverHighlight.OutlineColor = Color3.new(1, 1, 1) 
hoverHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
hoverHighlight.Parent = gui 

local hoverRadius = Instance.new("CylinderHandleAdornment")
hoverRadius.Name = "RTS_HoverRadius"
hoverRadius.Height = 0.2
hoverRadius.Radius = BUILDER_RANGE
hoverRadius.InnerRadius = BUILDER_RANGE - 0.5
hoverRadius.Angle = 360
hoverRadius.CFrame = CFrame.Angles(math.rad(90), 0, 0)
hoverRadius.Color3 = Color3.new(1, 1, 1)
hoverRadius.Transparency = 0.6
hoverRadius.AlwaysOnTop = true
hoverRadius.Adornee = nil
hoverRadius.Parent = gui

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getUnitId(model)
	return model:GetAttribute("UnitId")
end

-- [RTSController.lua] - ADD TO HELPERS SECTION
local function quadBezier(t, p0, p1, p2)
	local l1 = p0:Lerp(p1, t)
	local l2 = p1:Lerp(p2, t)
	return l1:Lerp(l2, t)
end

-- [RTSController.lua] REPLACE updateBuildingFire
local function updateBuildingFire(model, healthPct)
	local firePart = model:FindFirstChild("FireEffectPart")

	-- Show fire if HP is below 40% and NOT Dead
	if healthPct < 0.4 and healthPct > 0 and not model:GetAttribute("IsDead") then
		if not firePart then
			firePart = Instance.new("Part")
			firePart.Name = "FireEffectPart"
			firePart.Transparency = 1
			firePart.CanCollide = false
			firePart.Anchored = true
			firePart.Size = Vector3.new(1,1,1)

			-- [[ FIX: FORCE UPRIGHT ]]
			-- Using CFrame.new() resets rotation to (0,0,0) so it always points UP
			firePart.CFrame = CFrame.new(model:GetPivot().Position + Vector3.new(0, 5, 0))
			firePart.Parent = model

			local fire = Instance.new("Fire")
			fire.Size = 12
			fire.Heat = 20
			fire.Parent = firePart

			local smoke = Instance.new("Smoke")
			smoke.Opacity = 0.4
			smoke.RiseVelocity = 15
			smoke.Size = 8
			smoke.Parent = firePart
		end
	else
		-- Remove Fire if healed OR DEAD
		if firePart then firePart:Destroy() end
	end
end

local function isOwnedUnit(model)
	return model:GetAttribute("OwnerUserId") == player.UserId
end

local function getUnitType(model)
	return model:GetAttribute("UnitType") or model.Name
end

local function clamp2(a, b)
	return Vector2.new(math.min(a.X, b.X), math.min(a.Y, b.Y)), Vector2.new(math.max(a.X, b.X), math.max(a.Y, b.Y))
end

local function pointInRect(p, a, b)
	local minV, maxV = clamp2(a, b)
	return p.X >= minV.X and p.X <= maxV.X and p.Y >= minV.Y and p.Y <= maxV.Y
end

local function getModelScreenPos(model)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local pp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	if not pp then return nil end
	local v, onScreen = cam:WorldToViewportPoint(pp.Position)
	if not onScreen then return nil end
	return Vector2.new(v.X, v.Y)
end

local function identifyTarget(model)
	if not model then return nil end
	if model.Parent == unitsFolder then return "Unit" end
	if model:GetAttribute("IsRTSTree") == true or CollectionService:HasTag(model, "RTSTree") or model.Name == "Tree" then return "Tree" end

	-- [[ NEW: Detect Buildings ]] --
	if CollectionService:HasTag(model, "RTSBuilding") or model:GetAttribute("IsBuilding") then return "Building" end

	if string.match(model.Name, "^Hex_%-?%d+_%-?%d+$") then return "Tile" end
	return nil
end

local function getHoverTarget()
	local target = mouse.Target
	if not target then return nil, nil end
	local model = target:FindFirstAncestorOfClass("Model")
	if model then
		local typeFound = identifyTarget(model)
		if typeFound then return model, typeFound end
	end
	return nil, nil
end

local function getUnitUnderMouse()
	local model, typeStr = getHoverTarget()
	if model and typeStr == "Unit" and isOwnedUnit(model) then
		return model
	end
	return nil
end

local function getTreeUnderMouse()
	local model, typeStr = getHoverTarget()
	if model and typeStr == "Tree" then return model end
	return nil
end

local function findUnitById(unitId)
	for _, model in ipairs(unitsFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
			return model
		end
	end
	return nil
end

-- Raycast helper that "punches through" decorative clutter (like grass decals/models)
-- until it finds a Hex_ tile (or gives up).
local function getMouseWorldHit()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local ml = UserInputService:GetMouseLocation()
	local viewRay = cam:ViewportPointToRay(ml.X, ml.Y)

	local baseIgnore = getIgnoreList() or {}
	local ignore = {}
	for i = 1, #baseIgnore do ignore[i] = baseIgnore[i] end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	-- Try a few times, excluding whatever we hit if it isn't a Hex_ tile.
	for _ = 1, 12 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(viewRay.Origin, viewRay.Direction * 5000, params)
		if not hit or not hit.Instance then
			return nil
		end

		local inst = hit.Instance
		local model = inst:FindFirstAncestorOfClass("Model")
		if model and string.match(model.Name, "^Hex_%-?%d+_%-?%d+$") then
			return hit.Position
		end

		-- Not a tile: exclude the thing we hit and continue.
		-- If it's a lone BasePart (like decor grass), excluding the part is enough.
		-- If it's inside a model (like a tree/building), exclude the whole model.
		if model then
			table.insert(ignore, model)
		else
			table.insert(ignore, inst)
		end
	end

	return nil
end


---------------------------------------------------------------------
-- Selection state + HIGHLIGHTS
---------------------------------------------------------------------
local selected = {}           -- [unitId] = model
local selectedHL = {}         -- [unitId] = Highlight
local selectedRings = {}      -- [unitId] = CylinderHandleAdornment

-- Tree Selection State
local selectedTrees = {}      -- [treeModel] = true
local selectedTreeHL = {}     -- [treeModel] = Highlight

-- 1. Unit Highlight Helpers
local function makeSelectionHighlight(model)
	local h = Instance.new("Highlight")
	h.Name = "RTS_SelectedHighlight"
	h.Adornee = model
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.FillTransparency = 1
	h.OutlineTransparency = 0
	h.OutlineColor = Color3.fromRGB(70, 255, 120) -- Green
	h.Parent = model
	return h
end

local function createRadiusRing(model, color)
	local pp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not pp then return nil end

	local ring = Instance.new("CylinderHandleAdornment")
	ring.Name = "RTS_RangeRing"
	ring.Adornee = pp
	ring.Height = 0.2
	ring.Radius = BUILDER_RANGE
	ring.InnerRadius = BUILDER_RANGE - 0.4
	ring.Angle = 360
	ring.CFrame = CFrame.Angles(math.rad(90), 0, 0)
	ring.Color3 = color or Color3.fromRGB(70, 255, 120)
	ring.Transparency = 0.4
	ring.AlwaysOnTop = true
	ring.ZIndex = 0 
	ring.Parent = gui 
	return ring
end

local function removeHighlight(unitId)
	if selectedHL[unitId] then
		selectedHL[unitId]:Destroy()
		selectedHL[unitId] = nil
	end
	if selectedRings[unitId] then
		selectedRings[unitId]:Destroy()
		selectedRings[unitId] = nil
	end
end

-- 2. Tree Highlight Helpers
local function removeTreeHighlight(tree)
	if selectedTreeHL[tree] then
		selectedTreeHL[tree]:Destroy()
		selectedTreeHL[tree] = nil
	end
end

local function makeTreeSelectionHighlight(tree)
	local hl = Instance.new("Highlight")
	hl.Name = "TreeSelectHL"
	hl.Adornee = tree
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0
	hl.OutlineColor = Color3.fromRGB(100, 255, 255) -- Cyan/White for selected trees
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = gui
	return hl
end

-- 3. Selection Logic (Units)
local function clearSelection()
	for id, _ in pairs(selected) do
		removeHighlight(id)
	end
	table.clear(selected)
end

local function addToSelection(model)
	local id = getUnitId(model)
	if not id then return end
	if selected[id] == model then return end

	selected[id] = model
	removeHighlight(id) 
	selectedHL[id] = makeSelectionHighlight(model)

	if getUnitType(model) == "Builder" then
		selectedRings[id] = createRadiusRing(model, Color3.fromRGB(70, 255, 120))
	end
end

local function removeFromSelection(model)
	local id = getUnitId(model)
	if not id then return end
	if selected[id] then
		selected[id] = nil
		removeHighlight(id)
	end
end

local function setSingleSelection(model)
	clearSelection()
	addToSelection(model)
end

-- 4. Selection Logic (Trees)
local function clearTreeSelection()
	for tree, _ in pairs(selectedTrees) do
		removeTreeHighlight(tree)
	end
	table.clear(selectedTrees)
end

local function addTreeToSelection(tree)
	if selectedTrees[tree] then return end
	selectedTrees[tree] = true
	removeTreeHighlight(tree)
	selectedTreeHL[tree] = makeTreeSelectionHighlight(tree)
end

local function removeTreeFromSelection(tree)
	if selectedTrees[tree] then
		selectedTrees[tree] = nil
		removeTreeHighlight(tree)
	end
end

local function selectSimilarUnits(refUnit, additive, includeOffscreen)
	local refType = getUnitType(refUnit)
	if not refType then return end
	if not additive then clearSelection() end

	for _, model in ipairs(unitsFolder:GetChildren()) do
		if model:IsA("Model") and isOwnedUnit(model) then
			if getUnitType(model) == refType then
				if includeOffscreen then
					addToSelection(model)
				else
					local sp = getModelScreenPos(model)
					if sp then addToSelection(model) end
				end
			end
		end
	end
end

local function getSelectedIds()
	local ids = {}
	for id, _ in pairs(selected) do
		table.insert(ids, id)
	end
	return ids
end

-- Clean up if object removed
unitsFolder.ChildRemoved:Connect(function(child)
	if not child:IsA("Model") then return end
	local id = child:GetAttribute("UnitId")
	if id and selected[id] then
		selected[id] = nil
		removeHighlight(id)
	end
end)



---------------------------------------------------------------------
-- [[ 1B. UNIT ROSTER GUI (Select All / Select Type / Delete) ]]
---------------------------------------------------------------------
local rosterOpen = false
local rosterFilterType = "ALL"
local rosterSearchText = ""

-- HUD Toggle Button (Next to BUILD)
local openUnitsBtn = Instance.new("TextButton")
openUnitsBtn.Name = "OpenUnitsRosterBtn"
openUnitsBtn.Text = "UNITS"
openUnitsBtn.Font = Enum.Font.GothamBlack
openUnitsBtn.TextSize = 14
openUnitsBtn.TextColor3 = Color3.new(1, 1, 1)
openUnitsBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
openUnitsBtn.AutoButtonColor = true
openUnitsBtn.Position = UDim2.new(1, -165, 1, -25) -- left of BUILD button
openUnitsBtn.Size = UDim2.fromOffset(80, 40)
openUnitsBtn.AnchorPoint = Vector2.new(1, 1)
openUnitsBtn.Parent = gui

local ubCorner = Instance.new("UICorner", openUnitsBtn)
ubCorner.CornerRadius = UDim.new(0, 6)

local ubStroke = Instance.new("UIStroke", openUnitsBtn)
ubStroke.Color = Color3.fromRGB(70, 70, 75)
ubStroke.Thickness = 1

-- Main Roster Frame
local rosterFrame = Instance.new("Frame")
rosterFrame.Name = "UnitRosterFrame"
rosterFrame.Size = UDim2.fromOffset(360, 420)
rosterFrame.AnchorPoint = Vector2.new(0, 1)
rosterFrame.Position = UDim2.new(0, 14, 0.98, 0)
rosterFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
rosterFrame.BorderSizePixel = 0
rosterFrame.Visible = false
rosterFrame.Parent = gui

makeResponsive(rosterFrame)

local rfCorner = Instance.new("UICorner", rosterFrame)
rfCorner.CornerRadius = UDim.new(0, 10)

local rfStroke = Instance.new("UIStroke", rosterFrame)
rfStroke.Color = Color3.fromRGB(60, 60, 65)
rfStroke.Thickness = 1.5

-- Header
local rfHeader = Instance.new("Frame")
rfHeader.Name = "Header"
rfHeader.BackgroundTransparency = 1
rfHeader.Size = UDim2.new(1, -16, 0, 34)
rfHeader.Position = UDim2.new(0, 8, 0, 6)
rfHeader.Parent = rosterFrame

local rfTitle = Instance.new("TextLabel")
rfTitle.BackgroundTransparency = 1
rfTitle.Size = UDim2.new(1, -40, 1, 0)
rfTitle.Position = UDim2.new(0, 0, 0, 0)
rfTitle.Font = Enum.Font.GothamBlack
rfTitle.TextSize = 16
rfTitle.TextXAlignment = Enum.TextXAlignment.Left
rfTitle.TextColor3 = Color3.fromRGB(230, 230, 230)
rfTitle.Text = "YOUR UNITS"
rfTitle.Parent = rfHeader

local rfClose = Instance.new("TextButton")
rfClose.Name = "Close"
rfClose.Text = "X"
rfClose.Font = Enum.Font.GothamBlack
rfClose.TextSize = 14
rfClose.TextColor3 = Color3.fromRGB(220, 220, 220)
rfClose.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
rfClose.Size = UDim2.fromOffset(28, 28)
rfClose.AnchorPoint = Vector2.new(1, 0)
rfClose.Position = UDim2.new(1, 0, 0, 2)
rfClose.AutoButtonColor = true
rfClose.Parent = rfHeader
local xCorner = Instance.new("UICorner", rfClose)
xCorner.CornerRadius = UDim.new(0, 6)

-- Search
local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.PlaceholderText = "Search (type/id) "
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 12
searchBox.TextColor3 = Color3.fromRGB(235, 235, 235)
searchBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
searchBox.Size = UDim2.new(1, -16, 0, 30)
searchBox.Position = UDim2.new(0, 8, 0, 44)
searchBox.TextXAlignment = Enum.TextXAlignment.Left
searchBox.Parent = rosterFrame
local sbPad = Instance.new("UIPadding", searchBox)
sbPad.PaddingLeft = UDim.new(0, 10)
local sbCorner = Instance.new("UICorner", searchBox)
sbCorner.CornerRadius = UDim.new(0, 8)

-- Filter Bar
local filterBar = Instance.new("ScrollingFrame")
filterBar.Name = "FilterBar"
filterBar.BackgroundTransparency = 1
filterBar.Size = UDim2.new(1, -16, 0, 26)
filterBar.Position = UDim2.new(0, 8, 0, 82)
filterBar.ScrollBarThickness = 2
filterBar.ScrollingDirection = Enum.ScrollingDirection.X
filterBar.CanvasSize = UDim2.new(0, 0, 0, 0)
filterBar.Parent = rosterFrame

local fbLayout = Instance.new("UIListLayout", filterBar)
fbLayout.FillDirection = Enum.FillDirection.Horizontal
fbLayout.SortOrder = Enum.SortOrder.LayoutOrder
fbLayout.Padding = UDim.new(0, 6)

-- Action Buttons Row
local actionRow = Instance.new("Frame")
actionRow.Name = "ActionRow"
actionRow.BackgroundTransparency = 1
actionRow.Size = UDim2.new(1, -16, 0, 34)
actionRow.Position = UDim2.new(0, 8, 0, 112)
actionRow.Parent = rosterFrame

local arLayout = Instance.new("UIListLayout", actionRow)
arLayout.FillDirection = Enum.FillDirection.Horizontal
arLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
arLayout.SortOrder = Enum.SortOrder.LayoutOrder
arLayout.Padding = UDim.new(0, 8)

local function makeSmallBtn(text)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.fromRGB(235, 235, 235)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(106, 30)
	local c = Instance.new("UICorner", b)
	c.CornerRadius = UDim.new(0, 8)
	return b
end

local selectAllBtn = makeSmallBtn("Select All")
selectAllBtn.Parent = actionRow

local selectTypeBtn = makeSmallBtn("Select Type")
selectTypeBtn.Parent = actionRow

local clearBtn = makeSmallBtn("Clear")
clearBtn.Size = UDim2.fromOffset(70, 30)
clearBtn.Parent = actionRow

-- List Container
local rosterList = Instance.new("ScrollingFrame")
rosterList.Name = "RosterList"
rosterList.BackgroundTransparency = 1
rosterList.Size = UDim2.new(1, -16, 1, -160)
rosterList.Position = UDim2.new(0, 8, 0, 152)
rosterList.ScrollBarThickness = 4
rosterList.CanvasSize = UDim2.new(0, 0, 0, 0)
rosterList.Parent = rosterFrame

local rlLayout = Instance.new("UIListLayout", rosterList)
rlLayout.SortOrder = Enum.SortOrder.LayoutOrder
rlLayout.Padding = UDim.new(0, 6)

local function safeLower(s)
	if typeof(s) ~= "string" then return "" end
	return string.lower(s)
end

local function getOwnedUnits()
	local out = {}
	for _, model in ipairs(unitsFolder:GetChildren()) do
		if model:IsA("Model") and isOwnedUnit(model) then
			if model:GetAttribute("IsDead") ~= true then
				table.insert(out, model)
			end
		end
	end
	table.sort(out, function(a, b)
		local ta = getUnitType(a) or ""
		local tb = getUnitType(b) or ""
		if ta == tb then
			return (getUnitId(a) or "") < (getUnitId(b) or "")
		end
		return ta < tb
	end)
	return out
end

local filterButtons = {}
local refreshRoster

local function setFilterButtonVisual(btn, isActive)
	if isActive then
		btn.BackgroundColor3 = Color3.fromRGB(80, 80, 95)
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	else
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		btn.TextColor3 = Color3.fromRGB(210, 210, 210)
	end
end

local function clearFilterButtons()
	for _, b in ipairs(filterButtons) do
		b:Destroy()
	end
	table.clear(filterButtons)
end

local function createFilterBtn(label, value)
	local b = Instance.new("TextButton")
	b.Name = "Filter_" .. label
	b.Text = label
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.TextColor3 = Color3.fromRGB(210, 210, 210)
	b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	b.AutoButtonColor = true
	b.Size = UDim2.fromOffset(0, 24)
	b.AutomaticSize = Enum.AutomaticSize.X

	local pad = Instance.new("UIPadding", b)
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)

	local c = Instance.new("UICorner", b)
	c.CornerRadius = UDim.new(0, 8)

	b.MouseButton1Click:Connect(function()
		rosterFilterType = value
		for _, fb in ipairs(filterButtons) do
			setFilterButtonVisual(fb, fb:GetAttribute("FilterValue") == rosterFilterType)
		end
		-- refresh list
		if rosterFrame.Visible then
			-- do it in next step so UI updates are smooth
			task.defer(function()
				if rosterFrame.Visible then
					refreshRoster()
				end
			end)
		end
	end)

	b:SetAttribute("FilterValue", value)
	return b
end

local rosterRows = {} -- [unitModel] = rowFrame

local function clearRosterRows()
	for model, row in pairs(rosterRows) do
		if row and row.Parent then row:Destroy() end
	end
	table.clear(rosterRows)
end

local function getUnitHealthText(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		local hp = math.floor(hum.Health + 0.5)
		local max = math.floor(hum.MaxHealth + 0.5)
		return tostring(hp) .. "/" .. tostring(max)
	end
	-- If no humanoid, just blank
	return ""
end

local function createRosterRow(model)
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 46)
	row.Parent = rosterList

	local rc = Instance.new("UICorner", row)
	rc.CornerRadius = UDim.new(0, 10)

	local rs = Instance.new("UIStroke", row)
	rs.Color = Color3.fromRGB(45, 45, 52)
	rs.Thickness = 1

	local uType = getUnitType(model) or "Unit"
	local uId = getUnitId(model) or "?"
	local data = CLIENT_UNIT_DATA[uType] or { Name = uType, Icon = "" }

	local icon = Instance.new("ImageLabel")
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(32, 32)
	icon.Position = UDim2.new(0, 8, 0.5, 0)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Image = data.Icon or ""
	icon.Parent = row

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, -170, 0, 16)
	name.Position = UDim2.new(0, 48, 0, 7)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = Color3.fromRGB(240, 240, 240)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = (data.Name or uType) .. "  (" .. uType .. ")"
	name.Parent = row

	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Size = UDim2.new(1, -170, 0, 14)
	sub.Position = UDim2.new(0, 48, 0, 26)
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 11
	sub.TextColor3 = Color3.fromRGB(170, 170, 170)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Text = uId .. (getUnitHealthText(model) ~= "" and ("   HP " .. getUnitHealthText(model)) or "")
	sub.Parent = row

	local selectBtn2 = Instance.new("TextButton")
	selectBtn2.Name = "Select"
	selectBtn2.Text = "SELECT"
	selectBtn2.Font = Enum.Font.GothamBlack
	selectBtn2.TextSize = 10
	selectBtn2.TextColor3 = Color3.fromRGB(255, 255, 255)
	selectBtn2.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
	selectBtn2.AutoButtonColor = true
	selectBtn2.Size = UDim2.fromOffset(62, 28)
	selectBtn2.AnchorPoint = Vector2.new(1, 0.5)
	selectBtn2.Position = UDim2.new(1, -74, 0.5, 0)
	selectBtn2.Parent = row
	local sc = Instance.new("UICorner", selectBtn2)
	sc.CornerRadius = UDim.new(0, 8)

	local delBtn2 = Instance.new("TextButton")
	delBtn2.Name = "Delete"
	delBtn2.Text = "DEL"
	delBtn2.Font = Enum.Font.GothamBlack
	delBtn2.TextSize = 10
	delBtn2.TextColor3 = Color3.fromRGB(255, 255, 255)
	delBtn2.BackgroundColor3 = Color3.fromRGB(90, 45, 45)
	delBtn2.AutoButtonColor = true
	delBtn2.Size = UDim2.fromOffset(52, 28)
	delBtn2.AnchorPoint = Vector2.new(1, 0.5)
	delBtn2.Position = UDim2.new(1, -12, 0.5, 0)
	delBtn2.Parent = row
	local dc = Instance.new("UICorner", delBtn2)
	dc.CornerRadius = UDim.new(0, 8)

	selectBtn2.MouseButton1Click:Connect(function()
		if model and model.Parent and isOwnedUnit(model) then
			setSingleSelection(model)
		end
	end)

	delBtn2.MouseButton1Click:Connect(function()
		local id = getUnitId(model)
		if id and model and model.Parent and isOwnedUnit(model) then
			DeleteUnit:FireServer(id)
		end
	end)

	rosterRows[model] = row
	return row
end

refreshRoster = function()
	if not rosterFrame.Visible then return end

	local units = getOwnedUnits()

	-- Rebuild filter buttons (ALL + each type found)
	clearFilterButtons()

	local allBtn = createFilterBtn("ALL", "ALL")
	allBtn.Parent = filterBar
	table.insert(filterButtons, allBtn)

	local typeSet = {}
	for _, u in ipairs(units) do
		local t = getUnitType(u)
		if t then typeSet[t] = true end
	end
	local types = {}
	for t,_ in pairs(typeSet) do table.insert(types, t) end
	table.sort(types)

	for _, t in ipairs(types) do
		local b = createFilterBtn(t, t)
		b.Parent = filterBar
		table.insert(filterButtons, b)
	end

	-- Apply visual state
	for _, fb in ipairs(filterButtons) do
		setFilterButtonVisual(fb, fb:GetAttribute("FilterValue") == rosterFilterType)
	end

	-- Update filterBar canvas width
	task.defer(function()
		filterBar.CanvasSize = UDim2.new(0, fbLayout.AbsoluteContentSize.X + 12, 0, 0)
	end)

	-- Rebuild rows
	clearRosterRows()

	local search = safeLower(rosterSearchText)

	for _, u in ipairs(units) do
		local uType = getUnitType(u) or ""
		local uId = getUnitId(u) or ""
		local passType = (rosterFilterType == "ALL") or (uType == rosterFilterType)
		local passSearch = true

		if search ~= "" then
			local hay = safeLower(uType .. " " .. uId)
			passSearch = string.find(hay, search, 1, true) ~= nil
		end

		if passType and passSearch then
			createRosterRow(u)
		end
	end

	task.defer(function()
		rosterList.CanvasSize = UDim2.new(0, 0, 0, rlLayout.AbsoluteContentSize.Y + 10)
	end)
end

-- Fix: connect filter buttons refresh callback now that refreshRoster exists
for _, fb in ipairs(filterButtons) do
	-- nothing here; created dynamically
end

local function openRoster()
	rosterFrame.Visible = true
	rosterOpen = true
	refreshRoster()
end

local function closeRoster()
	rosterFrame.Visible = false
	rosterOpen = false
end

openUnitsBtn.MouseButton1Click:Connect(function()
	if rosterFrame.Visible then
		closeRoster()
	else
		openRoster()
	end
end)

rfClose.MouseButton1Click:Connect(closeRoster)

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	rosterSearchText = searchBox.Text or ""
	if rosterFrame.Visible then
		refreshRoster()
	end
end)

clearBtn.MouseButton1Click:Connect(function()
	clearSelection()
end)

selectAllBtn.MouseButton1Click:Connect(function()
	clearSelection()
	for _, u in ipairs(getOwnedUnits()) do
		addToSelection(u)
	end
end)

selectTypeBtn.MouseButton1Click:Connect(function()
	clearSelection()
	if rosterFilterType == "ALL" then
		for _, u in ipairs(getOwnedUnits()) do
			addToSelection(u)
		end
		return
	end
	for _, u in ipairs(getOwnedUnits()) do
		if getUnitType(u) == rosterFilterType then
			addToSelection(u)
		end
	end
end)

-- Keep roster in sync
unitsFolder.ChildAdded:Connect(function(child)
	if rosterFrame.Visible then
		task.defer(refreshRoster)
	end
end)

unitsFolder.ChildRemoved:Connect(function(child)
	if rosterFrame.Visible then
		task.defer(refreshRoster)
	end
end)

---------------------------------------------------------------------
-- [[ NEW: HEALTH BAR SYSTEM ]]
---------------------------------------------------------------------
local healthBars = {} -- [unitModel] = { billboard=Instance, fill=Instance, hum=Humanoid }

-- [RTSController.lua] Replace createHealthBar
local function createHealthBar(target)
	if healthBars[target] then return end 

	local hum = target:FindFirstChildOfClass("Humanoid")
	local isBuilding = target:HasTag("RTSBuilding") or target:GetAttribute("IsBuilding")

	if not hum and not isBuilding then return end

	local pp = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
	if not pp then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Adornee = pp
	bb.Size = isBuilding and UDim2.fromScale(6, 0.6) or UDim2.fromScale(2.8, 0.35) -- Bigger bars for buildings
	bb.StudsOffset = Vector3.new(0, isBuilding and 8 or 4.5, 0) -- Higher up for buildings
	bb.AlwaysOnTop = true
	bb.Enabled = false -- Hidden by default (until damaged)
	bb.Parent = hpContainer

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = bb

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(50, 220, 50) 
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1) 
	fill.Parent = bg

	healthBars[target] = { billboard = bb, fill = fill, hum = hum, isBuilding = isBuilding }
end

local function removeHealthBar(unit)
	local data = healthBars[unit]
	if data then
		if data.billboard then data.billboard:Destroy() end
		healthBars[unit] = nil
	end
end

-- [[ UPDATED: Robust Loading Logic ]]
local function setupUnitVisuals(unit)
	task.spawn(function()
		-- 1. Explicitly wait for Humanoid (up to 10 seconds)
		local hum = unit:FindFirstChild("Humanoid")
		if not hum then
			hum = unit:WaitForChild("Humanoid", 10)
		end

		-- 2. Explicitly wait for Root Part
		local root = unit.PrimaryPart or unit:FindFirstChild("HumanoidRootPart")
		if not root then
			root = unit:WaitForChild("HumanoidRootPart", 10)
		end

		-- 3. Create only if we successfully found parts
		if hum and root then
			createHealthBar(unit)
		end
	end)
end

-- Listen for new units
unitsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		setupUnitVisuals(child)
	end
end)

unitsFolder.ChildRemoved:Connect(function(child)
	removeHealthBar(child)
end)

-- Initialize existing units (The ones already there when you join)
for _, u in ipairs(unitsFolder:GetChildren()) do
	if u:IsA("Model") then
		setupUnitVisuals(u)
	end
end

---------------------------------------------------------------------
-- Path visuals (Beam segments) [Resume rest of script...]

---------------------------------------------------------------------
-- Path visuals (Beam segments)
---------------------------------------------------------------------
local PathVis = {} 
local function makeAttachmentPoint(parent, pos)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.new(0.2, 0.2, 0.2); p.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)); p.Parent = parent
	local a = Instance.new("Attachment"); a.Parent = p
	return p, a
end
local NextPathVis = {} 
local function destroyNextPath(unitId)
	local vis = NextPathVis[unitId]; if not vis then return end
	if vis.folder and vis.folder.Parent then vis.folder:Destroy() end; NextPathVis[unitId] = nil
end
local function buildNextPath(unitId, points)
	destroyNextPath(unitId); if not points or #points < 2 then return end
	local folder = Instance.new("Folder"); folder.Name = "NextPath_" .. unitId; folder.Parent = workspace
	local attachments, parts, beams = {}, {}, {}
	for i, pos in ipairs(points) do local part, att = makeAttachmentPoint(folder, pos); parts[i] = part; attachments[i] = att end
	for i = 1, #attachments - 1 do
		local beam = Instance.new("Beam"); beam.Attachment0 = attachments[i]; beam.Attachment1 = attachments[i + 1]; beam.Width0 = 0.16; beam.Width1 = 0.16; beam.FaceCamera = true; beam.Transparency = NumberSequence.new(0.6); beam.Parent = folder; beams[i] = beam
	end
	NextPathVis[unitId] = { folder = folder, parts = parts, attachments = attachments, beams = beams }
end
local function destroyPath(unitId)
	local vis = PathVis[unitId]; if not vis then return end
	if vis.folder and vis.folder.Parent then vis.folder:Destroy() end; PathVis[unitId] = nil
end
local function buildPath(unitId, points)
	destroyPath(unitId); if not points or #points < 2 then return end
	local folder = Instance.new("Folder"); folder.Name = "Path_" .. unitId; folder.Parent = workspace
	local attachments, parts, beams = {}, {}, {}
	for i, pos in ipairs(points) do local part, att = makeAttachmentPoint(folder, pos); parts[i] = part; attachments[i] = att end
	for i = 1, #attachments - 1 do
		local beam = Instance.new("Beam"); beam.Attachment0 = attachments[i]; beam.Attachment1 = attachments[i + 1]; beam.Width0 = 0.22; beam.Width1 = 0.22; beam.FaceCamera = true; beam.Parent = folder; beams[i] = beam
	end
	PathVis[unitId] = { folder = folder, parts = parts, attachments = attachments, beams = beams }
end
local function shrinkPath(unitId, currentIndex)
	local vis = PathVis[unitId]; if not vis then return end
	for i = 1, math.max(0, currentIndex - 1) do
		if vis.parts[i] then vis.parts[i]:Destroy(); vis.parts[i] = nil end
		if vis.beams[i] then vis.beams[i]:Destroy(); vis.beams[i] = nil end
	end
end
PathUpdate.OnClientEvent:Connect(function(mode, unitId, points, index)
	if mode == "NEW" then if typeof(points) == "table" then buildPath(unitId, points) end
	elseif mode == "PROGRESS" then shrinkPath(unitId, index)
	elseif mode == "DONE" then destroyPath(unitId)
	elseif mode == "NEXT" then if typeof(points) == "table" then buildNextPath(unitId, points) else destroyNextPath(unitId) end
	elseif mode == "NEXT_CLEAR" then destroyNextPath(unitId) end
end)

---------------------------------------------------------------------
-- Input Handling
---------------------------------------------------------------------
local dragging = false
local dragStart = Vector2.zero
local dragEnd = Vector2.zero
local lmbDownPos = Vector2.zero

local DOUBLE_CLICK_TIME = 0.32
local DOUBLE_CLICK_DIST = 10
local lastClickT = 0
local lastClickType = nil
local lastClickPos = Vector2.zero

local rmbDown = false
local rmbStartPos = Vector2.zero
local rmbMoved = false
local rmbDownWorld = nil    
local rmbFaceYaw = nil      


---------------------------------------------------------------------
-- PLACEMENT SYSTEM DEFINITIONS
---------------------------------------------------------------------
cancelPlacement = function()
	isPlacing = false
	placementName = nil
	if placementGhost then
		placementGhost:Destroy()
		placementGhost = nil
	end
end

startPlacement = function(buildingName)
	cancelPlacement() 

	local buildingsFolder = ReplicatedStorage:WaitForChild("Buildings", 5)
	if not buildingsFolder then warn("Buildings folder not found") return end

	local template = buildingsFolder:FindFirstChild(buildingName)
	if not template then warn("Building not found:", buildingName) return end

	placementName = buildingName
	isPlacing = true
	placementRotation = 0

	-- Create Ghost
	placementGhost = template:Clone()

	-- [[ NEW: Calculate Offset ]] ------------------------------------
	-- Try to find the Pivot/Tile part, or fall back to PrimaryPart
	local anchor = placementGhost:FindFirstChild("Tile") 
		or placementGhost:FindFirstChild("Pivot") 
		or placementGhost.PrimaryPart

	if anchor then
		local anchorCF = anchor.CFrame
		local modelCF = placementGhost:GetPivot()
		-- Save the difference between the anchor part and the model center
		placementOffset = anchorCF:Inverse() * modelCF 
	else
		placementOffset = CFrame.new() -- No offset
	end
	-- ---------------------------------------------------------------

	for _, part in ipairs(placementGhost:GetDescendants()) do
		-- ... (keep your existing transparency/color code here) ...
	end
	placementGhost.Parent = workspace

	-- ... (rest of function)
end

updateGhost = function(dt)
	if not isPlacing or not placementGhost then return end

	local mousePos = getMouseWorldHit()
	if not mousePos then return end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	-- [[ 3. USE THE HELPER HERE TOO ]] --
	rayParams.FilterDescendantsInstances = getIgnoreList()

	local rayOrigin = mousePos + Vector3.new(0, 50, 0)
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -100, 0), rayParams)

	local snapPos = mousePos
	local isValid = false

	if result and result.Instance then
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		if model and string.match(model.Name, "^Hex_%-?%d+_%-?%d+$") then

			-- [[ FIX: Calculate Geometric Center on Client ]] --
			local minX, minZ = math.huge, math.huge
			local maxX, maxZ = -math.huge, -math.huge
			local found = false

			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "Leaf" and part.Name ~= "Trunk" and part.Size.X > 2 then
					found = true
					local pos = part.Position
					local size = part.Size
					minX = math.min(minX, pos.X - size.X/2)
					maxX = math.max(maxX, pos.X + size.X/2)
					minZ = math.min(minZ, pos.Z - size.Z/2)
					maxZ = math.max(maxZ, pos.Z + size.Z/2)
				end
			end

			if found then
				local cx = (minX + maxX) / 2
				local cz = (minZ + maxZ) / 2
				snapPos = Vector3.new(cx, model:GetPivot().Position.Y, cz)
			else
				snapPos = model:GetPivot().Position
			end

			-- Validation
			local isWater = model:GetAttribute("IsWater")
			local hasTree = model:GetAttribute("HasTree")
			local isBuilding = model:GetAttribute("IsBuilding")
			local hasRock = model:GetAttribute("HasRockNode") -- [[ NEW: Check for Rocks ]]

			-- [[ UPDATED CONDITION ]]
			if not isWater and not hasTree and not isBuilding and not hasRock then
				isValid = true
			end
		end
	end

	local rotAngle = math.rad(placementRotation * 60)
	local finalCF = CFrame.new(snapPos) * CFrame.Angles(0, rotAngle, 0) 

	-- [[ FIXED LINE ]] 
	-- We multiply finalCF by the offset (calculated in startPlacement) to ensure
	-- the model stays upright and aligned relative to its internal Tile/Pivot.
	if placementOffset then
		placementGhost:PivotTo(finalCF * placementOffset)
	else
		placementGhost:PivotTo(finalCF)
	end

	local color = isValid and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
	for _, part in ipairs(placementGhost:GetDescendants()) do
		if part:IsA("BasePart") then part.Color = color end
	end
end

-- [RTSController.lua] REPLACE the existing "createDamageNumber" and "VisualEffect.OnClientEvent" block with this:

-- [[ VISUAL EFFECTS SYSTEM ]] --
local function createDamageNumber(pos, text, color, sizeScale)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(4, 2)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = workspace

	local p = Instance.new("Part")
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.Position = pos + Vector3.new(math.random(-1,1)*0.5, 0, math.random(-1,1)*0.5)
	p.Parent = workspace
	bb.Adornee = p

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(255, 50, 50) 
	lbl.TextStrokeTransparency = 0
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.Parent = bb

	-- Scaling logic (for larger alerts)
	if sizeScale then
		bb.Size = UDim2.fromScale(4 * sizeScale, 2 * sizeScale)
	end

	-- Animate Up and Fade
	local twInfo = TweenInfo.new(0.8, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)
	local ts = game:GetService("TweenService")
	ts:Create(p, twInfo, {Position = pos + Vector3.new(0, 6, 0)}):Play()
	ts:Create(lbl, twInfo, {TextTransparency = 1, TextStrokeTransparency = 1}):Play()

	task.delay(1, function()
		bb:Destroy()
		p:Destroy()
	end)
end

local function playSound(pos, id)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = 0.5
	sound.RollOffMaxDistance = 80
	sound.RollOffMinDistance = 10

	local p = Instance.new("Part")
	p.Transparency = 1
	p.Anchored = true
	p.CanCollide = false
	p.Position = pos
	p.Parent = workspace

	sound.Parent = p
	sound:Play()

	sound.Ended:Connect(function() p:Destroy() end)
end
VisualEffect.OnClientEvent:Connect(function(type, pos, data)
	if type == "DamageNumber" then
		createDamageNumber(pos, data, Color3.fromRGB(255, 80, 80), 1.0)

	elseif type == "CombatAlert" then
		createDamageNumber(pos, data, Color3.fromRGB(255, 0, 0), 1.5)

	elseif type == "Sound" then
		playSound(pos, data)

	elseif type == "Projectile" then
		local startPos = pos
		local endPos = data.Target
		local duration = data.Duration or 1

		-- 1. Get Model
		local arrow
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local template = assets and assets:FindFirstChild("Arrow")

		if template then
			arrow = template:Clone()
		else
			arrow = Instance.new("Part")
			arrow.Size = Vector3.new(0.2, 0.2, 3)
			arrow.Color = Color3.fromRGB(160, 110, 60)
			arrow.Material = Enum.Material.Wood
		end

		arrow.Parent = workspace

		-- 2. Anchor & Physics Cleanup
		local centerPart = arrow.PrimaryPart or arrow:FindFirstChildWhichIsA("BasePart")

		if arrow:IsA("Model") then
			for _, desc in ipairs(arrow:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc.Anchored = true
					desc.CanCollide = false
				end
			end
		elseif arrow:IsA("BasePart") then
			arrow.Anchored = true
			arrow.CanCollide = false
			centerPart = arrow
		end

		-- [[ NEW: TRACER (TRAIL) ]] --
		if centerPart then
			local a0 = Instance.new("Attachment", centerPart)
			a0.Position = Vector3.new(0, 0.2, 0) -- Slight offset Up

			local a1 = Instance.new("Attachment", centerPart)
			a1.Position = Vector3.new(0, -0.2, 0) -- Slight offset Down

			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.25 -- Short tail
			trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 200)) -- Pale Yellow
			trail.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.6), -- Start semi-transparent
				NumberSequenceKeypoint.new(1, 1)    -- Fade to invisible
			})
			trail.WidthScale = NumberSequence.new(1, 0) -- Taper off
			trail.LightEmission = 0.5 -- Slight glow
			trail.Parent = arrow
		end

		-- 3. Calculate Arc Control Point
		local mid = (startPos + endPos) / 2
		local dist = (endPos - startPos).Magnitude
		local arcHeight = math.clamp(dist * 0.35, 2, 15) 
		local controlPoint = mid + Vector3.new(0, arcHeight, 0)

		-- [[ NEW: ROTATION CORRECTION ]] --
		-- If it faces "Left", we rotate -90 degrees (Right) to fix it.
		-- Try changing -90 to 90 or 180 if it's still wrong.
		local rotationOffset = CFrame.Angles(0, math.rad(-90), 0)

		-- 4. Animate
		local startTime = os.clock()
		local conn

		conn = RunService.RenderStepped:Connect(function()
			local now = os.clock()
			local alpha = (now - startTime) / duration

			if alpha >= 1 then
				arrow:Destroy()
				conn:Disconnect()
				return
			end

			local currentPos = quadBezier(alpha, startPos, controlPoint, endPos)
			local nextPos = quadBezier(alpha + 0.02, startPos, controlPoint, endPos)

			-- LookAt logic + The Fix
			local newCF = CFrame.new(currentPos, nextPos) * rotationOffset

			arrow:PivotTo(newCF)
		end)
	end
end)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	-- [[ PLACEMENT INPUTS ]]
	if isPlacing then
		if input.KeyCode == Enum.KeyCode.Q then
			placementRotation = (placementRotation - 1) % 6
		elseif input.KeyCode == Enum.KeyCode.E then
			placementRotation = (placementRotation + 1) % 6
		elseif input.KeyCode == Enum.KeyCode.Escape then
			cancelPlacement()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Confirm Placement
			if placementGhost then
				local pos = placementGhost:GetPivot().Position
				-- Fire Remote
				Remotes:WaitForChild("CommandPlaceBuilding"):FireServer(placementName, pos, placementRotation)
				cancelPlacement()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			cancelPlacement()
		end
		return -- Consume input so we don't select units while placing
	end

	-- Manual Garrison (HotKey: E)
	-- Select archers, hover your ArcherTower, press E to enter.
	if input.KeyCode == Enum.KeyCode.E then
		local model, typeStr = getHoverTarget()
		if model and typeStr == "Building"
			and model:GetAttribute("BuildingType") == "ArcherTower"
			and model:GetAttribute("OwnerUserId") == player.UserId then

			local ids = getSelectedIds()
			if #ids > 0 then
				local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
				CommandGarrisonTower:FireServer(ids, model, shift)
			end
		end
	end

	-- Batch Tree Chop (HotKey: F)
	if input.KeyCode == Enum.KeyCode.F then
		local anySent = false
		for tree, _ in pairs(selectedTrees) do
			if tree and tree.Parent then
				ToggleTreeMark:FireServer(tree)
				anySent = true
			end
		end
		if not anySent then
			local tree = getTreeUnderMouse()
			if tree then ToggleTreeMark:FireServer(tree) end
		end
	end

	-- Cancel Selection/Command (HotKey: C)
	if input.KeyCode == Enum.KeyCode.C then
		local ids = getSelectedIds()
		if #ids > 0 then CommandCancel:FireServer(ids) end
	end

	-- Left Mouse Button (Select / Interact)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		lmbDownPos = UserInputService:GetMouseLocation()
		local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)

		local unit = getUnitUnderMouse()
		local tree = getTreeUnderMouse()

		if unit then
			-- [[ Unit Clicked ]]
			actionFrame.Visible = false -- CLOSE MENU

			local now = os.clock()
			local clickPos = lmbDownPos
			local uType = getUnitType(unit)
			local isDouble = (now - lastClickT <= DOUBLE_CLICK_TIME) and (uType ~= nil and uType == lastClickType) and ((clickPos - lastClickPos).Magnitude <= DOUBLE_CLICK_DIST)

			lastClickT = now
			lastClickType = uType
			lastClickPos = clickPos

			if isDouble then
				local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				clearTreeSelection() 
				selectSimilarUnits(unit, shift, ctrl)
				return
			end

			if shift then
				local id = getUnitId(unit)
				if id and selected[id] then removeFromSelection(unit) else addToSelection(unit) end
			else
				clearTreeSelection() 
				setSingleSelection(unit)
			end

		elseif tree then
			-- [[ Tree Clicked ]]
			actionFrame.Visible = false -- CLOSE MENU
			lastClickT = 0
			lastClickType = nil

			if shift then
				if selectedTrees[tree] then removeTreeFromSelection(tree) else addTreeToSelection(tree) end
			else
				clearSelection() 
				clearTreeSelection() 
				addTreeToSelection(tree)
			end

		else
			-- [[ Ground OR Structure Clicked ]]
			local hoverModel, hoverType = getHoverTarget()
			local myId = player.UserId
			local isMyBase = (hoverModel and hoverModel:GetAttribute("BaseOwnerUserId") == myId)
			local isMyBarracks = (hoverModel and hoverModel:GetAttribute("BuildingType") == "RTSBarracks" and hoverModel:GetAttribute("OwnerUserId") == myId)

			if isMyBase then
				-- [[ VILLAGE CENTER MENU ]]
				clearSelection(); clearTreeSelection()
				actionFrame.Visible = true
				currentSelectedBuilding = nil 
				resetQueueUI()

				-- Populate Menu using new Helper
				refreshActionMenu("Village Center", {"Builder"}, nil)

			elseif isMyBarracks and not hoverModel:GetAttribute("UnderConstruction") then
				-- [[ BARRACKS MENU ]]
				clearSelection(); clearTreeSelection()
				actionFrame.Visible = true
				currentSelectedBuilding = hoverModel
				resetQueueUI()

				-- Populate Menu using new Helper
				refreshActionMenu("Barracks", {"WarPeasant", "Archer"}, hoverModel)

				-- Highlight the Barracks
				local hl = Instance.new("Highlight")
				hl.Adornee = hoverModel
				hl.FillTransparency = 1
				hl.OutlineColor = Color3.new(1, 0, 0)
				hl.Parent = hoverModel
				task.delay(0.2, function() hl:Destroy() end)
			else
				-- [[ GROUND CLICK - DRAG ]]
				actionFrame.Visible = false
				currentSelectedBuilding = nil
				if recruitConnection then recruitConnection:Disconnect(); recruitConnection = nil end
				lastClickT = 0
				lastClickType = nil
				dragging = true
				dragStart = lmbDownPos
				dragEnd = dragStart
				selBox.Visible = true
				if not shift then clearSelection(); clearTreeSelection() end
			end
		end
	end

	-- Right Mouse Button (Move / Action)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbDown = true
		rmbMoved = false
		rmbFaceYaw = nil
		rmbDownWorld = getMouseWorldHit() 
	end
end)

UserInputService.InputChanged:Connect(function(input, gp)
	if gp then return end
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		dragEnd = UserInputService:GetMouseLocation()
	end
	if rmbDown and input.UserInputType == Enum.UserInputType.MouseMovement then
		local nowWorld = getMouseWorldHit()
		if typeof(rmbDownWorld) == "Vector3" and typeof(nowWorld) == "Vector3" then
			local dir = Vector3.new(nowWorld.X - rmbDownWorld.X, 0, nowWorld.Z - rmbDownWorld.Z)
			if dir.Magnitude > 2 then
				rmbMoved = true
				local _, yaw, _ = CFrame.new(Vector3.zero, Vector3.zero + dir):ToOrientation()
				rmbFaceYaw = yaw
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if dragging then
			dragging = false
			selBox.Visible = false


			local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			local ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
			local dragDist = (UserInputService:GetMouseLocation() - lmbDownPos).Magnitude


			if dragDist < 6 then return end


			if ctrl then
				-- Ctrl + Drag: trees only (QOL for batch-chop / marking)
				local trees = CollectionService:GetTagged("RTSTree")
				if #trees == 0 then
					-- Fallback if tags aren't present (older maps): trees are top-level Models with IsRTSTree=true
					for _, obj in ipairs(workspace:GetChildren()) do
						if obj:IsA("Model") and obj:GetAttribute("IsRTSTree") then
							table.insert(trees, obj)
						end
					end
				end


				for _, tree in ipairs(trees) do
					if tree and tree.Parent then
						local sp = getModelScreenPos(tree)
						if sp and pointInRect(sp, dragStart, dragEnd) then
							addTreeToSelection(tree)
						end
					end
				end
			else
				-- Normal Drag: units
				for _, model in ipairs(unitsFolder:GetChildren()) do
					if model:IsA("Model") and isOwnedUnit(model) then
						local sp = getModelScreenPos(model)
						if sp and pointInRect(sp, dragStart, dragEnd) then
							addToSelection(model)
						end
					end
				end
			end
		end
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rmbDown = false
		local ids = getSelectedIds()
		if #ids > 0 and typeof(rmbDownWorld) == "Vector3" then
			local addToQueue = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
			local tree = getTreeUnderMouse()
			if tree then
				local builderIds = {}
				local otherIds = {}
				for _, id in ipairs(ids) do
					local unit = findUnitById(id)
					if unit and (unit:GetAttribute("UnitType") == "Builder") then table.insert(builderIds, id) else table.insert(otherIds, id) end
				end
				if #builderIds > 0 then CommandChopTree:FireServer(builderIds, tree, addToQueue) end
				if #otherIds > 0 then CommandMove:FireServer(otherIds, rmbDownWorld, addToQueue, rmbFaceYaw) end
			else
				CommandMove:FireServer(ids, rmbDownWorld, addToQueue, rmbFaceYaw)
			end
		end
		rmbDownWorld = nil
		rmbFaceYaw = nil
		rmbMoved = false
	end
end)
-- [RTSController.lua] REPLACE UpdateBaseQueue.OnClientEvent

-- [[ UPDATED QUEUE VISUALIZER ]] --
UpdateBaseQueue.OnClientEvent:Connect(function(isActive, timeLeft, totalTime, queuedCount, buildingModel)
	local isRelevant = false

	-- Check relevance
	if buildingModel == nil and (menuTitle.Text == "VILLAGE CENTER") then
		isRelevant = true
	elseif buildingModel and currentSelectedBuilding == buildingModel then
		isRelevant = true
	end

	if isRelevant then
		-- Clear existing visual slots
		for _, c in ipairs(queuePanel:GetChildren()) do
			if c:IsA("Frame") then c:Destroy() end
		end

		if not isActive and queuedCount <= 0 then
			queueLabel.Visible = true
			queueLabel.Text = "QUEUE EMPTY"
		else
			queueLabel.Visible = false

			-- 1. Create Active Slot (With Progress Bar)
			if isActive then
				local slot = Instance.new("Frame")
				slot.Name = "ActiveSlot"
				slot.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
				slot.Size = UDim2.fromOffset(24, 24)
				slot.BorderSizePixel = 0

				local corner = Instance.new("UICorner", slot); corner.CornerRadius = UDim.new(0, 4)

				-- Progress Overlay
				local prog = Instance.new("Frame")
				prog.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
				prog.BackgroundTransparency = 0.6
				prog.BorderSizePixel = 0
				prog.Size = UDim2.fromScale(1 - (timeLeft/totalTime), 1) -- Grows horizontally
				prog.Parent = slot

				local corner2 = Instance.new("UICorner", prog); corner2.CornerRadius = UDim.new(0, 4)

				slot.Parent = queuePanel
			end

			-- 2. Create Pending Slots (Small Boxes)
			for i = 1, queuedCount do
				local slot = Instance.new("Frame")
				slot.Name = "PendingSlot"
				slot.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
				slot.Size = UDim2.fromOffset(20, 20) -- Slightly smaller
				slot.BorderSizePixel = 0

				local corner = Instance.new("UICorner", slot); corner.CornerRadius = UDim.new(0, 4)
				slot.Parent = queuePanel
			end
		end
	end
end)

-- Managed Tree Highlights
local markedHighlights = {} 
local MY_MARK_ATTR = "MarkedForChop_" .. player.UserId 

local function setupTreeObserver(model)
	if model:GetAttribute("IsRTSTree") then
		model:GetAttributeChangedSignal(MY_MARK_ATTR):Connect(function()
			if model:GetAttribute(MY_MARK_ATTR) then
				if not markedHighlights[model] then
					local hl = Instance.new("Highlight")
					hl.Name = "MarkedForChopHL"
					hl.Adornee = model
					hl.FillColor = Color3.fromRGB(255, 80, 80)
					hl.FillTransparency = 0.6
					hl.OutlineColor = Color3.fromRGB(255, 0, 0)
					hl.Parent = gui
					markedHighlights[model] = hl
				end
			else
				if markedHighlights[model] then
					markedHighlights[model]:Destroy()
					markedHighlights[model] = nil
				end
			end
		end)

		if model:GetAttribute(MY_MARK_ATTR) and not markedHighlights[model] then
			local hl = Instance.new("Highlight")
			hl.Name = "MarkedForChopHL"
			hl.Adornee = model
			hl.FillColor = Color3.fromRGB(255, 80, 80)
			hl.FillTransparency = 0.6
			hl.OutlineColor = Color3.fromRGB(255, 0, 0)
			hl.Parent = gui
			markedHighlights[model] = hl
		end
	end
end

workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") then setupTreeObserver(desc) end
end)
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("Model") then setupTreeObserver(obj) end
end

---------------------------------------------------------------------
-- CONSTRUCTION PROGRESS BARS
---------------------------------------------------------------------
local constructionBars = {} -- [buildingModel] = { billboard, bar, bg }

local function updateConstructionVisuals()
	for building, guiData in pairs(constructionBars) do
		if not building.Parent or not building:GetAttribute("UnderConstruction") then
			-- Cleanup
			guiData.billboard:Destroy()
			constructionBars[building] = nil
		else
			-- [[ NEW: Work-Based Calculation ]]
			local cur = building:GetAttribute("ConstructionProgress") or 0
			local max = building:GetAttribute("ConstructionMax") or 1

			local pct = math.clamp(cur / max, 0, 1)

			-- Update Bar Size
			guiData.bar.Size = UDim2.fromScale(pct, 1)

			if pct >= 1 then
				guiData.bar.BackgroundColor3 = Color3.fromRGB(100, 255, 100) 
			end
		end
	end
end

local function setupConstructionBar(model)
	if not model:GetAttribute("UnderConstruction") then return end
	if constructionBars[model] then return end -- Already has one

	local bb = Instance.new("BillboardGui")
	bb.Name = "BuildProgBar"
	bb.Adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	bb.Size = UDim2.fromScale(4, 0.4)
	bb.StudsOffset = Vector3.new(0, 6, 0) -- Higher than unit HP bars
	bb.AlwaysOnTop = true
	bb.Parent = gui -- RTSSelectionGui

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = bb

	-- Border/Stroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.new(0,0,0)
	stroke.Parent = bg

	local bar = Instance.new("Frame")
	bar.Name = "Fill"
	bar.BackgroundColor3 = Color3.fromRGB(255, 200, 50) -- Gold/Yellow for Construction
	bar.BorderSizePixel = 0
	bar.Size = UDim2.fromScale(0, 1)
	bar.Parent = bg

	constructionBars[model] = { billboard = bb, bar = bar }

	-- Listen for finish
	model:GetAttributeChangedSignal("UnderConstruction"):Connect(function()
		if not model:GetAttribute("UnderConstruction") then
			if constructionBars[model] then
				constructionBars[model].billboard:Destroy()
				constructionBars[model] = nil
			end
		end
	end)
end

-- Hook into existing workspace models
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") then
		task.wait() -- Brief wait for attributes
		setupConstructionBar(desc)
	end
end)
---------------------------------------------------------------------
-- RENDER LOOP
---------------------------------------------------------------------
-- [RTSController.lua] REPLACE THE ENTIRE RenderStepped LOOP
RunService.RenderStepped:Connect(function(dt)
	updateGhost(dt)
	updateConstructionVisuals()

	-- 1. Drag Box
	if dragging then
		local minV, maxV = clamp2(dragStart, dragEnd)
		selBox.Position = UDim2.fromOffset(minV.X, minV.Y)
		selBox.Size = UDim2.fromOffset(maxV.X - minV.X, maxV.Y - minV.Y)
	end

	-- 2. Hover Highlight (Keep your existing code here)
	local hoverModel, hoverType = getHoverTarget()
	if hoverModel then
		local id = getUnitId(hoverModel)
		local isUnitSelected = (id and selected[id])
		local isTreeSelected = (hoverType == "Tree" and selectedTrees[hoverModel])

		if isUnitSelected or isTreeSelected then
			hoverHighlight.Adornee = nil
			hoverRadius.Adornee = nil
		else
			hoverHighlight.Adornee = hoverModel

			if hoverType == "Unit" then
				hoverHighlight.OutlineColor = Color3.fromRGB(255, 255, 255)
				-- ... (existing unit logic) ...
			elseif hoverType == "Tree" then
				hoverHighlight.OutlineColor = Color3.fromRGB(255, 200, 50)
				hoverRadius.Adornee = nil

				-- [[ NEW: Building Hover Color ]] --
			elseif hoverType == "Building" then
				hoverHighlight.OutlineColor = Color3.fromRGB(100, 255, 100) -- Green highlight for buildings
				hoverRadius.Adornee = nil

			elseif hoverType == "Tile" then
				hoverHighlight.OutlineColor = Color3.fromRGB(100, 200, 255)
				hoverRadius.Adornee = nil
			else
				hoverHighlight.OutlineColor = Color3.new(1,1,1)
				hoverRadius.Adornee = nil
			end
		end
	else
		hoverHighlight.Adornee = nil
		hoverRadius.Adornee = nil
	end

	-- 3. Update Health Bars & Fire
	local camPos = workspace.CurrentCamera.CFrame.Position

	for target, data in pairs(healthBars) do
		-- [[ CHECK: Parent exists AND NOT DEAD ]]
		if target.Parent and not target:GetAttribute("IsDead") and (data.hum or data.isBuilding) then
			local h, max = 0, 100

			if data.hum then
				h, max = data.hum.Health, data.hum.MaxHealth
			else
				h = target:GetAttribute("Health") or 0
				max = target:GetAttribute("MaxHP") or 100
			end

			if max > 0 then
				local pct = math.clamp(h / max, 0, 1)
				data.fill.Size = UDim2.fromScale(pct, 1)
				data.fill.BackgroundColor3 = Color3.fromHSV(pct * 0.33, 0.9, 0.9)

				-- Show only if damaged
				local isDamaged = (pct < 0.99)
				local dist = (data.billboard.Adornee.Position - camPos).Magnitude

				if isDamaged and dist < HEALTH_BAR_SHOW_DIST then
					data.billboard.Enabled = true
				else
					data.billboard.Enabled = false
				end

				-- Update Fire
				if data.isBuilding then
					updateBuildingFire(target, pct)
				end
			else
				-- HP is 0, hide everything
				data.billboard.Enabled = false
				if data.isBuilding then updateBuildingFire(target, 0) end
			end
		else
			-- [[ CLEANUP ]]
			-- Target is dead or gone. Remove UI AND Fire.
			removeHealthBar(target)
			if data.isBuilding then
				local firePart = target:FindFirstChild("FireEffectPart")
				if firePart then firePart:Destroy() end
			end
		end
	end
end)

---------------------------------------------------------------------
-- LISTENERS
---------------------------------------------------------------------
-- Track new buildings for health bars
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") and CollectionService:HasTag(desc, "RTSBuilding") then
		task.wait() -- wait briefly for attributes to replicate
		createHealthBar(desc)
	end
end)

-- Initialize existing buildings
for _, b in ipairs(CollectionService:GetTagged("RTSBuilding")) do
	createHealthBar(b)
end

-- [[ AUTO-REFRESH PRICES ]] --
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child:GetAttribute("BuildingType") == "House" then
		-- Wait a split second for attributes to replicate
		task.wait(0.1) 
		updateHousingCosts()
	end
end)

workspace.ChildRemoved:Connect(function(child)
	if child:IsA("Model") and child:GetAttribute("BuildingType") == "House" then
		task.wait(0.1)
		updateHousingCosts()
	end
end)