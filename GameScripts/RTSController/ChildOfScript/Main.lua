--// RTSController Modular Split
--// Main logic (input, placement, build/queue updates, render loop, listeners)
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)


-- Expose UI housing cost refresh across modules (was local in monolith)
local function updateHousingCosts(...)
	local f = S.updateHousingCosts
	if f then
		return f(...)
	end
end

-- Services / core refs
local Players = S.Players
local UserInputService = S.UserInputService
local RunService = S.RunService
local ReplicatedStorage = S.ReplicatedStorage
local CollectionService = S.CollectionService

local player = S.player
local mouse = S.mouse
local unitsFolder = S.unitsFolder

-- Remotes
local CommandMineStone = S.CommandMineStone
local ToggleStoneMark = S.ToggleStoneMark
local Remotes = S.Remotes
local CommandMove = S.CommandMove
local CommandGarrisonTower = S.CommandGarrisonTower
local CommandChopTree = S.CommandChopTree
local CommandCancel = S.CommandCancel
local ToggleTreeMark = S.ToggleTreeMark
local RecruitUnit = S.RecruitUnit
local UpdateBaseQueue = S.UpdateBaseQueue
local CommandPlaceBuilding = S.CommandPlaceBuilding
local VisualEffect = S.VisualEffect
local DeleteUnit = S.DeleteUnit

-- UI refs
local gui = S.gui
local selBox = S.selBox
local actionFrame = S.actionFrame
local unitsContainer = S.unitsContainer
local menuTitle = S.menuTitle
local queuePanel = S.queuePanel
local queueLabel = S.queueLabel or (queuePanel and queuePanel:FindFirstChild("QueueLabel"))
if queuePanel and not queueLabel then
	queueLabel = queuePanel:FindFirstChildWhichIsA("TextLabel")
end
if queuePanel and not queueLabel then
	-- Fallback: preserve behavior if QueueLabel got renamed/removed
	queueLabel = Instance.new("TextLabel")
	queueLabel.Name = "QueueLabel"
	queueLabel.Text = "QUEUE EMPTY"
	queueLabel.Font = Enum.Font.GothamBold
	queueLabel.TextSize = 10
	queueLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
	queueLabel.Size = UDim2.new(0, 100, 1, 0)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Parent = queuePanel
end
S.queueLabel = queueLabel
local resetQueueUI = S.resetQueueUI
local refreshActionMenu = S.refreshActionMenu
local CLIENT_UNIT_DATA = S.CLIENT_UNIT_DATA

-- Config values (kept identical to original behavior)
local HEALTH_BAR_SHOW_DIST = S.HEALTH_BAR_SHOW_DIST

local hoverHighlight = S.hoverHighlight
local hoverRadius = S.hoverRadius

-- Helpers
local getUnitId = S.getUnitId
local quadBezier = S.quadBezier
local updateBuildingFire = S.updateBuildingFire
local isOwnedUnit = S.isOwnedUnit
local getUnitType = S.getUnitType
local clamp2 = S.clamp2
local pointInRect = S.pointInRect
local getModelScreenPos = S.getModelScreenPos
local identifyTarget = S.identifyTarget
local getHoverTarget = S.getHoverTarget
local getUnitUnderMouse = S.getUnitUnderMouse
local getTreeUnderMouse = S.getTreeUnderMouse
local getIgnoreList = S.getIgnoreList
local findUnitById = S.findUnitById
local getMouseWorldHit = S.getMouseWorldHit
local getStoneUnderMouse = S.getStoneUnderMouse


-- Selection
local selected = S.selected
local selectedTrees = S.selectedTrees
local clearSelection = S.clearSelection
local addToSelection = S.addToSelection
local removeFromSelection = S.removeFromSelection
local setSingleSelection = S.setSingleSelection
local clearTreeSelection = S.clearTreeSelection
local addTreeToSelection = S.addTreeToSelection
local removeTreeFromSelection = S.removeTreeFromSelection
local selectSimilarUnits = S.selectSimilarUnits
local getSelectedIds = S.getSelectedIds
local selectedStones = S.selectedStones
local clearStoneSelection = S.clearStoneSelection
local addStoneToSelection = S.addStoneToSelection
local removeStoneFromSelection = S.removeStoneFromSelection


-- Health bars
local healthBars = S.healthBars
local createHealthBar = S.createHealthBar
local removeHealthBar = S.removeHealthBar
local setupUnitVisuals = S.setupUnitVisuals

-- Path visuals
local PathVis = S.PathVis
local NextPathVis = S.NextPathVis
local destroyPath = S.destroyPath
local buildPath = S.buildPath
local destroyNextPath = S.destroyNextPath
local buildNextPath = S.buildNextPath

-- Forward-declared placement functions (defined in this module, called by UI at runtime)
local startPlacement, cancelPlacement, updateGhost

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
	S.isPlacing = false
	S.placementName = nil
	if S.placementGhost then
		S.placementGhost:Destroy()
		S.placementGhost = nil
	end
end

startPlacement = function(buildingName)
	cancelPlacement()

	local buildingsFolder = ReplicatedStorage:WaitForChild("Buildings", 5)
	if not buildingsFolder then warn("Buildings folder not found") return end

	local template = buildingsFolder:FindFirstChild(buildingName)
	if not template then warn("Building not found:", buildingName) return end

	S.placementName = buildingName
	S.isPlacing = true
	S.placementRotation = 0

	-- Create Ghost
	S.placementGhost = template:Clone()

	-- [[ NEW: Calculate Offset ]] ------------------------------------
	-- Try to find the Pivot/Tile part, or fall back to PrimaryPart
	local anchor = S.placementGhost:FindFirstChild("Tile")
		or S.placementGhost:FindFirstChild("Pivot")
		or S.placementGhost.PrimaryPart

	if anchor then
		local anchorCF = anchor.CFrame
		local modelCF = S.placementGhost:GetPivot()
		-- Save the difference between the anchor part and the model center
		S.placementOffset = anchorCF:Inverse() * modelCF
	else
		S.placementOffset = CFrame.new() -- No offset
	end
	-- ---------------------------------------------------------------

	for _, part in ipairs(S.placementGhost:GetDescendants()) do
		-- ... (keep your existing transparency/color code here) ...
	end
	S.placementGhost.Parent = workspace

	-- ... (rest of function)
end

updateGhost = function(dt)
	if not S.isPlacing or not S.placementGhost then return end

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

	local rotAngle = math.rad(S.placementRotation * 60)
	local finalCF = CFrame.new(snapPos) * CFrame.Angles(0, rotAngle, 0)

	-- [[ FIXED LINE ]]
	-- We multiply finalCF by the offset (calculated in startPlacement) to ensure
	-- the model stays upright and aligned relative to its internal Tile/Pivot.
	if S.placementOffset then
		S.placementGhost:PivotTo(finalCF * S.placementOffset)
	else
		S.placementGhost:PivotTo(finalCF)
	end

	local color = isValid and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
	for _, part in ipairs(S.placementGhost:GetDescendants()) do
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

			local newCF = CFrame.new(currentPos, nextPos) * rotationOffset
			arrow:PivotTo(newCF)
		end)
	end
end)

UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	-- [[ PLACEMENT INPUTS ]]
	if S.isPlacing then
		if input.KeyCode == Enum.KeyCode.Q then
			S.placementRotation = (S.placementRotation - 1) % 6
		elseif input.KeyCode == Enum.KeyCode.E then
			S.placementRotation = (S.placementRotation + 1) % 6
		elseif input.KeyCode == Enum.KeyCode.Escape then
			cancelPlacement()
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Confirm Placement
			if S.placementGhost then
				local pos = S.placementGhost:GetPivot().Position
				-- Fire Remote
				Remotes:WaitForChild("CommandPlaceBuilding"):FireServer(S.placementName, pos, S.placementRotation)
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

	-- Batch Stone Mine Mark (HotKey: G)
	if input.KeyCode == Enum.KeyCode.G then
		local anySent = false

		for stone, _ in pairs(selectedStones) do
			if stone and stone.Parent then
				ToggleStoneMark:FireServer(stone)
				anySent = true
			end
		end

		if not anySent then
			local stone = getStoneUnderMouse()
			if stone then
				ToggleStoneMark:FireServer(stone)
			end
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
		local stone = getStoneUnderMouse()

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
				clearStoneSelection()
				selectSimilarUnits(unit, shift, ctrl)
				return
			end

			if shift then
				local id = getUnitId(unit)
				if id and selected[id] then removeFromSelection(unit) else addToSelection(unit) end
			else
				clearTreeSelection()
				clearStoneSelection()
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
				clearStoneSelection()
				addTreeToSelection(tree)
			end

		elseif stone then
			-- [[ Stone Clicked ]]
			actionFrame.Visible = false
			lastClickT = 0
			lastClickType = nil

			if shift then
				if selectedStones[stone] then removeStoneFromSelection(stone) else addStoneToSelection(stone) end
			else
				clearSelection()
				clearTreeSelection()
				clearStoneSelection()
				addStoneToSelection(stone)
			end
		else
			-- [[ Ground OR Structure Clicked ]]
			local hoverModel, hoverType = getHoverTarget()
			local myId = player.UserId
			local isMyBase = (hoverModel and hoverModel:GetAttribute("BaseOwnerUserId") == myId)
			local isMyBarracks = (hoverModel and hoverModel:GetAttribute("BuildingType") == "RTSBarracks" and hoverModel:GetAttribute("OwnerUserId") == myId)

			if isMyBase then
				-- [[ VILLAGE CENTER MENU ]]
				clearSelection(); clearTreeSelection(); clearStoneSelection()
				actionFrame.Visible = true
				S.currentSelectedBuilding = nil
				resetQueueUI()

				refreshActionMenu("Village Center", {"Builder"}, nil)

			elseif isMyBarracks and not hoverModel:GetAttribute("UnderConstruction") then
				-- [[ BARRACKS MENU ]]
				clearSelection(); clearTreeSelection(); clearStoneSelection()

				actionFrame.Visible = true
				S.currentSelectedBuilding = hoverModel
				resetQueueUI()

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
				S.currentSelectedBuilding = nil
				if S.recruitConnection then S.recruitConnection:Disconnect(); S.recruitConnection = nil end
				lastClickT = 0
				lastClickType = nil
				dragging = true
				dragStart = lmbDownPos
				dragEnd = dragStart
				selBox.Visible = true
				if not shift then clearSelection(); clearTreeSelection(); clearStoneSelection() end
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
			local stone = getStoneUnderMouse()

			if tree or stone then
				local builderIds = {}
				local otherIds = {}
				for _, id in ipairs(ids) do
					local unit = findUnitById(id)
					if unit and (unit:GetAttribute("UnitType") == "Builder") then
						table.insert(builderIds, id)
					else
						table.insert(otherIds, id)
					end
				end

				if tree and #builderIds > 0 then
					CommandChopTree:FireServer(builderIds, tree, addToQueue)
				elseif stone and #builderIds > 0 then
					CommandMineStone:FireServer(builderIds, stone, addToQueue)
				end

				if #otherIds > 0 then
					CommandMove:FireServer(otherIds, rmbDownWorld, addToQueue, rmbFaceYaw)
				end
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
	-- Ensure queue UI exists (module load order / UI rebuild safety)
	if not queuePanel then return end
	if not queueLabel then
		queueLabel = queuePanel:FindFirstChild("QueueLabel") or queuePanel:FindFirstChildWhichIsA("TextLabel")
		S.queueLabel = queueLabel
		if not queueLabel then return end
	end
	local isRelevant = false

	-- Check relevance
	if buildingModel == nil and (menuTitle.Text == "VILLAGE CENTER") then
		isRelevant = true
	elseif buildingModel and S.currentSelectedBuilding == buildingModel then
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

-- Managed Stone Highlights
local markedStoneHighlights = {}
local MY_STONE_MARK_ATTR = "MarkedForMine_" .. player.UserId

local function setupStoneObserver(model)
	local resFolder = workspace:FindFirstChild("ResourceNodes")
	if model:GetAttribute("IsRTSStone") == true
		or CollectionService:HasTag(model, "RTSStone")
		or (resFolder and model:IsDescendantOf(resFolder) and string.match(model.Name, "^Rock_")) then

		model:GetAttributeChangedSignal(MY_STONE_MARK_ATTR):Connect(function()
			if model:GetAttribute(MY_STONE_MARK_ATTR) then
				if not markedStoneHighlights[model] then
					local hl = Instance.new("Highlight")
					hl.Name = "MarkedForMineHL"
					hl.Adornee = model
					hl.FillColor = Color3.fromRGB(255, 80, 80) -- RED (marked for mining)
					hl.FillTransparency = 0.6
					hl.OutlineColor = Color3.fromRGB(255, 0, 0)
					hl.Parent = gui
					markedStoneHighlights[model] = hl
				end
			else
				if markedStoneHighlights[model] then
					markedStoneHighlights[model]:Destroy()
					markedStoneHighlights[model] = nil
				end
			end
		end)

		if model:GetAttribute(MY_STONE_MARK_ATTR) and not markedStoneHighlights[model] then
			local hl = Instance.new("Highlight")
			hl.Name = "MarkedForMineHL"
			hl.Adornee = model
			hl.FillColor = Color3.fromRGB(255, 80, 80) -- RED (marked for mining)
			hl.FillTransparency = 0.6
			hl.OutlineColor = Color3.fromRGB(255, 0, 0)
			hl.Parent = gui
			markedStoneHighlights[model] = hl
		end
	end
end

workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") then setupStoneObserver(desc) end
end)
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("Model") then setupStoneObserver(obj) end
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
RunService.RenderStepped:Connect(function(dt)
	updateGhost(dt)
	updateConstructionVisuals()

	-- 1. Drag Box
	if dragging then
		local minV, maxV = clamp2(dragStart, dragEnd)
		selBox.Position = UDim2.fromOffset(minV.X, minV.Y)
		selBox.Size = UDim2.fromOffset(maxV.X - minV.X, maxV.Y - minV.Y)
	end

	-- 2. Hover Highlight
	local hoverModel, hoverType = getHoverTarget()
	if hoverModel then
		local id = getUnitId(hoverModel)
		local isUnitSelected = (id and selected[id])
		local isTreeSelected = (hoverType == "Tree" and selectedTrees[hoverModel])
		local isStoneSelected = (hoverType == "Stone" and selectedStones[hoverModel])

		if isUnitSelected or isTreeSelected or isStoneSelected then
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

			elseif hoverType == "Building" then
				hoverHighlight.OutlineColor = Color3.fromRGB(100, 255, 100)
				hoverRadius.Adornee = nil

			elseif hoverType == "Tile" then
				hoverHighlight.OutlineColor = Color3.fromRGB(100, 200, 255)
				hoverRadius.Adornee = nil

			elseif hoverType == "Stone" then
				hoverHighlight.OutlineColor = Color3.fromRGB(180, 180, 180)
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

				local isDamaged = (pct < 0.99)
				local dist = (data.billboard.Adornee.Position - camPos).Magnitude

				if isDamaged and dist < HEALTH_BAR_SHOW_DIST then
					data.billboard.Enabled = true
				else
					data.billboard.Enabled = false
				end

				if data.isBuilding then
					updateBuildingFire(target, pct)
				end
			else
				data.billboard.Enabled = false
				if data.isBuilding then updateBuildingFire(target, 0) end
			end
		else
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
workspace.DescendantAdded:Connect(function(desc)
	if desc:IsA("Model") and CollectionService:HasTag(desc, "RTSBuilding") then
		task.wait()
		createHealthBar(desc)
	end
end)

for _, b in ipairs(CollectionService:GetTagged("RTSBuilding")) do
	createHealthBar(b)
end

workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child:GetAttribute("BuildingType") == "House" then
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

-- Export placement API so UI callbacks keep working
S.startPlacement = startPlacement
S.cancelPlacement = cancelPlacement
S.updateGhost = updateGhost

return true
