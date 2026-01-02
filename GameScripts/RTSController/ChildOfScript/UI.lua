--// RTSController Modular Split
--// UI (Selection/Action panel + Construction menu + Hover visuals)
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)

local Players = S.Players
local UserInputService = S.UserInputService
local RunService = S.RunService
local ReplicatedStorage = S.ReplicatedStorage
local CollectionService = S.CollectionService

local player = S.player
local mouse = S.mouse

local Remotes = S.Remotes
local RecruitUnit = S.RecruitUnit

local unitsFolder = S.unitsFolder
local makeResponsive = S.makeResponsive

-- Config values (kept identical to original behavior)
local BUILDER_RANGE = S.BUILDER_RANGE

-- Forward-defined (implemented later, but used by UI button callbacks at runtime)
local function startPlacement(...)
	if S.startPlacement then
		return S.startPlacement(...)
	end
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
-- Make housing-cost refresh callable from other modules (Main listens for house add/remove)
S.updateHousingCosts = updateHousingCosts

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



-- Export UI references & helpers for other modules


---------------------------------------------------------------------
-- BUILDER AUTO PANEL (states + max distance)
---------------------------------------------------------------------
local SetBuilderAuto = S.SetBuilderAuto

local builderAutoFrame = Instance.new("Frame")
builderAutoFrame.Name = "BuilderAutoFrame"
builderAutoFrame.Visible = false
builderAutoFrame.AnchorPoint = Vector2.new(0, 1)
builderAutoFrame.Position = UDim2.new(0, 14, 1, -160)
builderAutoFrame.Size = UDim2.new(0, 260, 0, 188)
builderAutoFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 28)
builderAutoFrame.BackgroundTransparency = 0.15
builderAutoFrame.BorderSizePixel = 0
builderAutoFrame.Parent = gui

local baCorner = Instance.new("UICorner")
baCorner.CornerRadius = UDim.new(0, 10)
baCorner.Parent = builderAutoFrame

local baStroke = Instance.new("UIStroke")
baStroke.Thickness = 1
baStroke.Color = Color3.fromRGB(0, 0, 0)
baStroke.Transparency = 0.25
baStroke.Parent = builderAutoFrame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -12, 0, 22)
title.Position = UDim2.new(0, 6, 0, 6)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(240, 240, 240)
title.Text = "Builder Auto"
title.Parent = builderAutoFrame

local stateLabel = Instance.new("TextLabel")
stateLabel.Name = "StateLabel"
stateLabel.BackgroundTransparency = 1
stateLabel.Size = UDim2.new(1, -12, 0, 18)
stateLabel.Position = UDim2.new(0, 6, 0, 28)
stateLabel.Font = Enum.Font.Gotham
stateLabel.TextSize = 12
stateLabel.TextXAlignment = Enum.TextXAlignment.Left
stateLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
stateLabel.Text = "State: —"
stateLabel.Parent = builderAutoFrame

local buttonsFrame = Instance.new("Frame")
buttonsFrame.Name = "Buttons"
buttonsFrame.BackgroundTransparency = 1
buttonsFrame.Size = UDim2.new(1, -12, 0, 104)
buttonsFrame.Position = UDim2.new(0, 6, 0, 48)
buttonsFrame.Parent = builderAutoFrame

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0, 120, 0, 28)
grid.CellPadding = UDim2.new(0, 8, 0, 8)
grid.SortOrder = Enum.SortOrder.LayoutOrder
grid.Parent = buttonsFrame

local distLabel = Instance.new("TextLabel")
distLabel.Name = "DistLabel"
distLabel.BackgroundTransparency = 1
distLabel.Size = UDim2.new(0, 150, 0, 18)
distLabel.Position = UDim2.new(0, 6, 1, -34)
distLabel.Font = Enum.Font.Gotham
distLabel.TextSize = 12
distLabel.TextXAlignment = Enum.TextXAlignment.Left
distLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
distLabel.Text = "Max distance from base:"
distLabel.Parent = builderAutoFrame

local distBox = Instance.new("TextBox")
distBox.Name = "DistBox"
distBox.Size = UDim2.new(0, 64, 0, 22)
distBox.Position = UDim2.new(1, -70, 1, -38)
distBox.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
distBox.BorderSizePixel = 0
distBox.Font = Enum.Font.GothamBold
distBox.TextSize = 12
distBox.TextColor3 = Color3.fromRGB(240, 240, 240)
distBox.ClearTextOnFocus = false
distBox.Text = "120"
distBox.Parent = builderAutoFrame
local dbCorner = Instance.new("UICorner")
dbCorner.CornerRadius = UDim.new(0, 6)
dbCorner.Parent = distBox

local buttons = {}
local MODES = {"Auto", "Idle", "Mining", "Woodchopping", "Wander"}

local function styleButton(btn, isActive)
	btn.BackgroundColor3 = isActive and Color3.fromRGB(70, 120, 255) or Color3.fromRGB(40, 40, 45)
	btn.TextColor3 = Color3.fromRGB(245, 245, 245)
	btn.AutoButtonColor = true
end

local function getSelectedBuilderInfo()
	local getSelectedIds = S.getSelectedIds
	if not getSelectedIds then return {}, nil, nil end

	local ids = getSelectedIds()
	local builderIds = {}

	-- Selection.lua exports a map: S.selected[unitId] = model
	local selectedMap = S.selected

	local state = nil
	local mixed = false
	local maxDist = nil

	for _, id in ipairs(ids) do
		local unit = selectedMap and selectedMap[id] or nil
		if unit and unit:GetAttribute("UnitType") == "Builder" and unit:GetAttribute("OwnerUserId") == player.UserId then
			table.insert(builderIds, id)

			local st = unit:GetAttribute("AutoState")
			if st == nil then st = "Auto" end

			if state == nil then
				state = st
			elseif state ~= st then
				mixed = true
			end

			local md = unit:GetAttribute("AutoMaxDist")
			if typeof(md) == "number" then
				maxDist = md
			end
		end
	end

	if #builderIds == 0 then
		return {}, nil, nil
	end

	if mixed then
		state = "Mixed"
	end

	return builderIds, state, maxDist
end

local function clampMaxDist(n)
	n = tonumber(n) or 120
	n = math.clamp(n, 30, 600)
	return math.floor(n + 0.5)
end

local function updateBuilderAutoPanel()
	local builderIds, state, maxDist = getSelectedBuilderInfo()

	if #builderIds == 0 then
		builderAutoFrame.Visible = false
		return
	end

	builderAutoFrame.Visible = true

	if typeof(maxDist) == "number" then
		distBox.Text = tostring(clampMaxDist(maxDist))
	else
		distBox.Text = tostring(clampMaxDist(distBox.Text))
	end

	if state == "Auto" then
		stateLabel.Text = "State: AUTO (marked)"
	elseif state == "Mixed" then
		stateLabel.Text = "State: MIXED"
	else
		stateLabel.Text = "State: " .. tostring(state)
	end

	for _, mode in ipairs(MODES) do
		local btn = buttons[mode]
		if btn then
			styleButton(btn, state == mode)
		end
	end
end

local function sendAutoState(mode)
	if not SetBuilderAuto then return end

	local builderIds = select(1, getSelectedBuilderInfo())
	if #builderIds == 0 then return end

	local md = clampMaxDist(distBox.Text)
	SetBuilderAuto:FireServer(builderIds, mode, md)

	-- Refresh button highlight immediately (attribute replication can lag)
	updateBuilderAutoPanel()
end

for _, mode in ipairs(MODES) do
	local btn = Instance.new("TextButton")
	btn.Name = mode .. "Button"
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(245, 245, 245)
	btn.Text = mode
	btn.Parent = buttonsFrame

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	btn.MouseButton1Click:Connect(function()
		sendAutoState(mode)
	end)

	buttons[mode] = btn
end

-- Apply distance immediately when leaving the box
distBox.FocusLost:Connect(function()
	distBox.Text = tostring(clampMaxDist(distBox.Text))
	local builderIds = select(1, getSelectedBuilderInfo())
	if #builderIds > 0 and SetBuilderAuto then
		SetBuilderAuto:FireServer(builderIds, nil, clampMaxDist(distBox.Text))
	end
end)

-- Expose + hook selection change callback
S.builderAutoFrame = builderAutoFrame
S.updateBuilderAutoPanel = updateBuilderAutoPanel
S.onSelectionChanged = nil -- set below

-- Keep the panel in-sync when server replicates AutoState/AutoMaxDist back to the client.
local _autoAttrConns = {}

local function _clearAutoAttrConns()
	for unit, conns in pairs(_autoAttrConns) do
		for _, c in ipairs(conns) do
			if c.Connected then c:Disconnect() end
		end
		_autoAttrConns[unit] = nil
	end
end

local function _refreshAutoAttrConns()
	_clearAutoAttrConns()

	local selectedMap = S.selected
	if not selectedMap then return end

	for _, unit in pairs(selectedMap) do
		if unit and unit:GetAttribute("UnitType") == "Builder" and unit:GetAttribute("OwnerUserId") == player.UserId then
			_autoAttrConns[unit] = {
				unit:GetAttributeChangedSignal("AutoState"):Connect(function()
					task.defer(updateBuilderAutoPanel)
				end),
				unit:GetAttributeChangedSignal("AutoMaxDist"):Connect(function()
					task.defer(updateBuilderAutoPanel)
				end),
			}
		end
	end
end

-- Selection.lua calls S.onSelectionChanged() whenever selection changes.
S.onSelectionChanged = function()
	_refreshAutoAttrConns()
	updateBuilderAutoPanel()
end

task.defer(updateBuilderAutoPanel)

S.gui = gui
S.selBox = selBox
S.actionFrame = actionFrame
S.unitsContainer = unitsContainer
S.menuTitle = menuTitle
S.queuePanel = queuePanel
S.resetQueueUI = resetQueueUI
S.refreshActionMenu = refreshActionMenu
S.CLIENT_UNIT_DATA = CLIENT_UNIT_DATA

S.openBuildBtn = openBuildBtn
S.buildFrame = buildFrame
S.updateHousingCosts = updateHousingCosts

S.hpContainer = hpContainer

S.hoverHighlight = hoverHighlight
S.hoverRadius = hoverRadius

return true