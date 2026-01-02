--// RTSController Modular Split
--// Unit roster GUI (Select All / Select Type / Delete)
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)


-- Units folder (shared across modules)
local unitsFolder = S.unitsFolder

-- Fallbacks (in case shared folder name differs in your place)
if not unitsFolder then
	unitsFolder = workspace:FindFirstChild("RTSUnits") or workspace:FindFirstChild("RTS_Units") or workspace:WaitForChild("RTSUnits")
end

local player = S.player
local gui = S.gui
local makeResponsive = S.makeResponsive

local DeleteUnit = S.DeleteUnit

-- Selection state & functions from Selection.lua
local selected = S.selected
local clearSelection = S.clearSelection
local addToSelection = S.addToSelection
local setSingleSelection = S.setSingleSelection
local selectSimilarUnits = S.selectSimilarUnits
local getSelectedIds = S.getSelectedIds

-- Helpers
local getUnitId = S.getUnitId
local getUnitType = S.getUnitType
local isOwnedUnit = S.isOwnedUnit

-- UI data
local CLIENT_UNIT_DATA = S.CLIENT_UNIT_DATA

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
assert(unitsFolder, "RTSController Roster: unitsFolder is nil")
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



S.rosterFrame = rosterFrame
S.toggleRosterOpen = function()
	rosterOpen = not rosterOpen
	rosterFrame.Visible = rosterOpen
end

return true