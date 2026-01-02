--// RTSController Modular Split
--// Selection system (unit selection + tree selection + highlights)
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)

local player = S.player
local unitsFolder = S.unitsFolder
local gui = S.gui
local function fireSelectionChanged()
	local cb = S.onSelectionChanged
	if cb then
		-- Defer to avoid re-entrancy during selection edits
		task.defer(cb)
	end
end


-- NOTE: UI module is expected to create S.gui before this loads.
-- Fallback keeps highlights working if load order changes or GUI is recreated.
if not gui then
	local pg = player:WaitForChild("PlayerGui")
	gui = pg:FindFirstChild("RTSSelectionGui") or pg:WaitForChild("RTSSelectionGui")
end
local getModelScreenPos = S.getModelScreenPos

local BUILDER_RANGE = S.BUILDER_RANGE

-- Helpers from Helpers.lua
local getUnitId = S.getUnitId
local getUnitType = S.getUnitType
local isOwnedUnit = S.isOwnedUnit

---------------------------------------------------------------------
-- Selection state + HIGHLIGHTS
---------------------------------------------------------------------
local selected = {}           -- [unitId] = model
local selectedHL = {}         -- [unitId] = Highlight
local selectedRings = {}      -- [unitId] = CylinderHandleAdornment

-- Tree Selection State
local selectedTrees = {}      -- [treeModel] = true
local selectedTreeHL = {}     -- [treeModel] = Highlight

-- Stone Selection State
local selectedStones = {}     -- [stoneModel] = true
local selectedStoneHL = {}    -- [stoneModel] = Highlight

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

local function removeStoneHighlight(stone)
	if selectedStoneHL[stone] then
		selectedStoneHL[stone]:Destroy()
		selectedStoneHL[stone] = nil
	end
end

local function makeStoneSelectionHighlight(stone)
	local hl = Instance.new("Highlight")
	hl.Name = "StoneSelectHL"
	hl.Adornee = stone
	hl.FillTransparency = 1
	hl.OutlineTransparency = 0
	hl.OutlineColor = Color3.fromRGB(200, 200, 200) -- light gray
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	hl.Parent = gui
	return hl
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
	fireSelectionChanged()

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
	fireSelectionChanged()

end

local function removeFromSelection(model)
	local id = getUnitId(model)
	if not id then return end
	if selected[id] then
		selected[id] = nil
		removeHighlight(id)
	end
	fireSelectionChanged()

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
	fireSelectionChanged()

end

local function addTreeToSelection(tree)
	if selectedTrees[tree] then return end
	selectedTrees[tree] = true
	removeTreeHighlight(tree)
	selectedTreeHL[tree] = makeTreeSelectionHighlight(tree)
	fireSelectionChanged()

end

local function removeTreeFromSelection(tree)
	if selectedTrees[tree] then
		selectedTrees[tree] = nil
		removeTreeHighlight(tree)
	end
	fireSelectionChanged()

end

local function clearStoneSelection()
	for stone, _ in pairs(selectedStones) do
		removeStoneHighlight(stone)
	end
	table.clear(selectedStones)
	fireSelectionChanged()

end

local function addStoneToSelection(stone)
	if selectedStones[stone] then return end
	selectedStones[stone] = true
	removeStoneHighlight(stone)
	selectedStoneHL[stone] = makeStoneSelectionHighlight(stone)
	fireSelectionChanged()

end

local function removeStoneFromSelection(stone)
	if selectedStones[stone] then
		selectedStones[stone] = nil
		removeStoneHighlight(stone)
	end
	fireSelectionChanged()

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





-- Export selection state + functions
S.selected = selected
S.selectedTrees = selectedTrees

S.clearSelection = clearSelection
S.addToSelection = addToSelection
S.removeFromSelection = removeFromSelection
S.setSingleSelection = setSingleSelection
S.clearTreeSelection = clearTreeSelection
S.addTreeToSelection = addTreeToSelection
S.removeTreeFromSelection = removeTreeFromSelection
S.selectSimilarUnits = selectSimilarUnits
S.getSelectedIds = getSelectedIds
S.selectedStones = selectedStones
S.clearStoneSelection = clearStoneSelection
S.addStoneToSelection = addStoneToSelection
S.removeStoneFromSelection = removeStoneFromSelection

return true