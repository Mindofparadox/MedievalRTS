-- Modules/BUILDINGCONSTRUCTIONSYSTEM.lua
return function(S)
	-- Section: BUILDING CONSTRUCTION SYSTEM
	-- Aliases from shared state
	local ACTIVE_MOVE_ID = S.ACTIVE_MOVE_ID
	local BUILDING_STATS = S.BUILDING_STATS
	local BUILDING_TAG = S.BUILDING_TAG
	local CollectionService = S.CollectionService
	local CommandChopTree = S.CommandChopTree
	local CommandGarrisonTower = S.CommandGarrisonTower
	local CommandMove = S.CommandMove
	local CommandPlaceBuilding = S.CommandPlaceBuilding
	local HttpService = S.HttpService
	local ReplicatedStorage = S.ReplicatedStorage
	local ClientNotify = S.ClientNotify
	local TweenService = S.TweenService
	local UNIT_ACTION_TRACKS = S.UNIT_ACTION_TRACKS
	local UNIT_CMD_QUEUE = S.UNIT_CMD_QUEUE
	local addWood = S.addWood
	local buildIdMapForPlayer = S.buildIdMapForPlayer
	local claimTree = S.claimTree
	local clearTreeClaim = S.clearTreeClaim
	local enqueueMove = S.enqueueMove
	local ensurePrimaryPart = S.ensurePrimaryPart
	local finalizeConstruction = S.finalizeConstruction
	local getHexTileFromWorld = S.getHexTileFromWorld
	local getPlayerPopulation = S.getPlayerPopulation
	local getTileTruePosition = S.getTileTruePosition
	local isForbiddenDestinationTile = S.isForbiddenDestinationTile
	local isValidTreeModel = S.isValidTreeModel
	local moveUnit = S.moveUnit
	local playChopAnimation = S.playChopAnimation
	local rayToGround = S.rayToGround
	local refreshTileIncludeList = S.refreshTileIncludeList
	local releaseTree = S.releaseTree
	local setUnitWalking = S.setUnitWalking
	local smoothFaceYaw = S.smoothFaceYaw
	local unitsFolder = S.unitsFolder
	local waitArrive = S.waitArrive
	local CommandMineStone = S.CommandMineStone
	local addStone = S.addStone
	local isValidStoneModel = S.isValidStoneModel
	local claimStone = S.claimStone
	local releaseStone = S.releaseStone
	local clearStoneClaim = S.clearStoneClaim


	local normalizeStoneModel = S.normalizeStoneModel
	---------------------------------------------------------------------
	-- BUILDING CONSTRUCTION SYSTEM
	---------------------------------------------------------------------
	local executeBuildSequence
	executeBuildSequence = function(plr, unit, buildingModel)
		if not unit or not unit.Parent then return end
		if not buildingModel or not buildingModel.Parent then return end

		local buildingPos = buildingModel:GetPivot().Position
		local unitPos = unit:GetPivot().Position
		local approachPos = unitPos 
		local bestDist = math.huge

		for i = 0, 5 do
			local a = math.rad(i * 60)
			local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * 12
			local testPos = buildingPos + offset
			local tile = getHexTileFromWorld(testPos)
			if tile and not isForbiddenDestinationTile(tile) and tile ~= buildingModel then
				local d = (testPos - unitPos).Magnitude
				if d < bestDist then
					bestDist = d
					approachPos = testPos
				end
			end
		end

		ACTIVE_MOVE_ID[unit] = (ACTIVE_MOVE_ID[unit] or 0) + 1
		local myActionId = ACTIVE_MOVE_ID[unit]
		local q = UNIT_CMD_QUEUE[unit]; if q then table.clear(q) end

		ACTIVE_MOVE_ID[unit] = ACTIVE_MOVE_ID[unit] - 1

		moveUnit(plr, unit, approachPos, 1, 1)

		if ACTIVE_MOVE_ID[unit] ~= myActionId then return end

		local workTrack = playChopAnimation(unit) 
		UNIT_ACTION_TRACKS[unit] = workTrack

		local root = ensurePrimaryPart(unit)
		if root then
			local dir = (buildingPos - root.Position) * Vector3.new(1,0,1)
			local yaw = math.atan2(dir.X, dir.Z) + math.pi
			smoothFaceYaw(unit, unit:FindFirstChild("Humanoid"), root, yaw, 0.2, myActionId)
		end

		while buildingModel.Parent and buildingModel:GetAttribute("UnderConstruction") do
			if ACTIVE_MOVE_ID[unit] ~= myActionId then break end 

			local workStep = 0.5 

			local cur = buildingModel:GetAttribute("ConstructionProgress") or 0
			local max = buildingModel:GetAttribute("ConstructionMax") or 10

			local newProg = cur + workStep
			buildingModel:SetAttribute("ConstructionProgress", newProg)

			if newProg >= max then
				finalizeConstruction(buildingModel)
				break
			end

			task.wait(workStep)
		end

		if workTrack then workTrack:Stop(0.2); workTrack:Destroy() end
		UNIT_ACTION_TRACKS[unit] = nil
	end
	S.executeBuildSequence = executeBuildSequence


	-- Helper to count how many of a specific building a player owns
	local getBuildingCount
	getBuildingCount = function(plr, bType)
		local count = 0
		for _, b in ipairs(workspace:GetChildren()) do
			if b:IsA("Model") and b:GetAttribute("OwnerUserId") == plr.UserId then
				if b:GetAttribute("BuildingType") == bType then
					count = count + 1
				end
			end
		end
		return count
	end
	S.getBuildingCount = getBuildingCount


	CommandPlaceBuilding.OnServerEvent:Connect(function(plr, buildingName, targetPos, rotationIndex)
		local stats = BUILDING_STATS[buildingName]
		if not stats then return end

		local pGold = plr:GetAttribute("Gold") or 0
		local pWood = plr:GetAttribute("Wood") or 0

		-- [[ DYNAMIC COST CALCULATION ]] --
		local costGold = stats.Cost.Gold
		local costWood = stats.Cost.Wood

		if buildingName == "House" then
			local houseCount = getBuildingCount(plr, "House")
			local increase = houseCount * 25 -- Increase cost by 25 per existing house

			costGold = costGold + increase
			costWood = costWood + increase
		end

		if pGold < costGold or pWood < costWood then return end

		-- [[ POPULATION LIMIT CHECK ]] --
		if stats.PopCost then
			local currentPop = getPlayerPopulation(plr)
			local maxPop = plr:GetAttribute("MaxPopulation") or 10
			if (currentPop + stats.PopCost) > maxPop then
				ClientNotify:FireClient(plr, {
					Kind = "PopFull",
					Title = "Population full",
					Text = ("Not enough population room to place %s (needs %d). You have %d/%d. Build more Houses.")
						:format(tostring(buildingName), tonumber(stats.PopCost) or 0, tonumber(currentPop) or 0, tonumber(maxPop) or 0),
					FlashPop = true,
				})
				return -- Cancel build if it exceeds cap
			end
		end

		local tile = getHexTileFromWorld(targetPos)
		if not tile then return end
		if isForbiddenDestinationTile(tile) then return end

		-- [[ UPDATED: Strict Blockers ]]
		if tile:GetAttribute("HasTree") == true then return end
		if tile:GetAttribute("IsBuilding") == true then return end 
		if tile:GetAttribute("HasRockNode") == true then return end -- Check Rocks

		-- [[ NEW: Check for Units Blocking Tile ]]
		local tileCenter = tile:GetPivot().Position
		for _, u in ipairs(unitsFolder:GetChildren()) do
			if u:IsA("Model") then
				local uPos = u:GetPivot().Position
				-- Check horizontal distance only (ignore height)
				if (Vector3.new(uPos.X, 0, uPos.Z) - Vector3.new(tileCenter.X, 0, tileCenter.Z)).Magnitude < 6 then 
					return -- Blocked by a unit
				end
			end
		end
		-- Deduct dynamic cost
		plr:SetAttribute("Gold", pGold - costGold)
		plr:SetAttribute("Wood", pWood - costWood)

		local templateFolder = ReplicatedStorage
		for _, folderName in ipairs(stats.TemplatePath) do
			templateFolder = templateFolder:FindFirstChild(folderName)
			if not templateFolder then return end
		end
		local template = templateFolder 

		local tileName = tile.Name
		local tileAttrs = tile:GetAttributes()

		local p = getTileTruePosition(tile) 

		local building = template:Clone()
		building.Name = tileName
		building:SetAttribute("BuildingType", buildingName)
		building.Parent = workspace

		CollectionService:AddTag(building, BUILDING_TAG)

		local rotAngle = math.rad((rotationIndex or 0) * 60)
		local targetCF = CFrame.new(p) * CFrame.Angles(0, rotAngle, 0)

		local buildingBase = building:FindFirstChild("Tile") or building.PrimaryPart

		if buildingBase then
			local baseCF = buildingBase:IsA("BasePart") and buildingBase.CFrame or buildingBase:GetPivot()
			local modelCF = building:GetPivot()
			local offset = baseCF:Inverse() * modelCF 

			building:PivotTo(targetCF * offset)
		else
			building:PivotTo(targetCF)
		end

		for k, v in pairs(tileAttrs) do building:SetAttribute(k, v) end
		building:SetAttribute("IsBuilding", true)
		building:SetAttribute("OwnerUserId", plr.UserId)
		building:SetAttribute("UnderConstruction", true)
		building:SetAttribute("ConstructionProgress", 0)
		building:SetAttribute("ConstructionMax", stats.BuildTime)
		building:SetAttribute("MaxHP", stats.MaxHP)
		building:SetAttribute("Health", stats.MaxHP)
		for k, v in pairs(tileAttrs) do building:SetAttribute(k, v) end

		-- [[ NEW: PALISADE PATHFINDING BLOCKER ]] --
		if buildingName == "Palisade" then
			-- 1. Prevent clicking to walk ONTO it
			building:SetAttribute("IsWalkable", false)

			-- 2. Force Pathfinding Service to go AROUND it
			local obstaclePart = building:FindFirstChild("Tile") or building.PrimaryPart
			if obstaclePart then
				local mod = Instance.new("PathfindingModifier")
				mod.Label = "Wall"
				mod.PassThrough = false -- Block pathing
				mod.Parent = obstaclePart
			end
		end

		-- [[ NEW: PALISADE 2 SEPARATE LOGIC ]] --
		if buildingName == "Palisade2" then
			-- 1. Prevent units from walking ON TOP of the wall
			building:SetAttribute("IsWalkable", false)

			-- 2. Handle Pathfinding Obstacle
			-- Based on your image, the hierarchy is Model -> Tile. 
			-- We prioritize finding "Tile" to attach the modifier to.
			local obstaclePart = building:FindFirstChild("Tile") or building:FindFirstChild("Palisade2") or building.PrimaryPart

			if obstaclePart then
				local mod = Instance.new("PathfindingModifier")
				mod.Name = "WallModifier"
				mod.Label = "Wall" -- Ensure your Navigation Mesh is set to respect "Wall" or use default blockage
				mod.PassThrough = false -- Strictly block pathfinding
				mod.Parent = obstaclePart
			end
		end
		local hl = Instance.new("Highlight")
		hl.Name = "ConstructionHighlight"
		hl.FillColor = Color3.fromRGB(0, 255, 100)
		hl.OutlineColor = Color3.fromRGB(0, 255, 0)
		hl.FillTransparency = 0.5
		hl.Parent = building

		for _, part in ipairs(building:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.Transparency = 0.25
				part.CastShadow = false
			end
		end

		refreshTileIncludeList() 

		local builders = {}
		local range = 40 
		for _, unit in ipairs(unitsFolder:GetChildren()) do
			if unit:IsA("Model") and unit:GetAttribute("OwnerUserId") == plr.UserId and unit:GetAttribute("UnitType") == "Builder" then
				local dist = (unit:GetPivot().Position - p).Magnitude
				if dist < range and not UNIT_ACTION_TRACKS[unit] then
					table.insert(builders, unit)
				end
			end
		end

		for _, b in ipairs(builders) do
			task.spawn(function()
				executeBuildSequence(plr, b, building, tile) 
			end)
		end
	end)

	-- [[ ARCHER TOWER LOGIC ]] --

	local getFreeStandPoint
	getFreeStandPoint = function(towerModel)
		-- Hierarchy: ArcherTower (Model) -> ArcherStandPoint1..4
		for i = 1, 4 do
			local pointName = "ArcherStandPoint" .. i
			local point = towerModel:FindFirstChild(pointName, true) -- true = search descendants

			-- We use attributes on the TOWER to track slots
			local slotKey = "Slot_" .. i .. "_Occupied"
			if point and not towerModel:GetAttribute(slotKey) then
				return point, i
			end
		end

		return nil, nil
	end
	S.getFreeStandPoint = getFreeStandPoint


	local ungarrisonUnit
	ungarrisonUnit = function(unit)
		local tower = unit:GetAttribute("GarrisonedIn") -- The tower model passed as ObjectValue or reference? attributes cant store instances.
		-- We will use a String (Tower Name) or just rely on finding the tower via ID if needed. 
		-- Simpler: We just store the Tower's GUID or ensure we reference it carefully. 
		-- actually, we can just teleport them to ground and clear state.

		if not unit:GetAttribute("IsGarrisoned") then return end

		-- 1. Reset Unit State
		unit:SetAttribute("IsGarrisoned", false)
		unit:SetAttribute("GarrisonedIn", nil) -- We can store a string ID if really needed

		local root = unit.PrimaryPart
		local hum = unit:FindFirstChild("Humanoid")
		if root and hum then
			root.Anchored = false
			hum.PlatformStand = false
			-- Teleport to ground (Raycast down from current pos to find floor)
			local ground = rayToGround(root.Position + Vector3.new(5, 0, 5)) -- Offset slightly so they don't spawn inside tower base
			unit:PivotTo(CFrame.new(ground + Vector3.new(0, 3, 0)))
		end

		-- 2. Clear Slot on Tower (Optional optimization: find which tower it was. 
		-- For now, we rely on the loop in CommandMove to clear the specific slot if we tracked it, 
		-- or we just let the slot clear itself if we check for valid occupants later. 
		-- To keep it simple: We just free the unit. The tower slot logic can be purely "check if unit is near/on point" or reset manually.)

		-- Robust Method: The unit should store the Tower Reference via an ObjectValue if possible, or we search.
		-- For this script, we will just make the stand point available again by checking distance in `getFreeStandPoint`? 
		-- No, let's use attributes correctly.

		local slotIndex = unit:GetAttribute("GarrisonSlot")
		local towerId = unit:GetAttribute("GarrisonTowerId")

		if towerId and slotIndex then
			-- Find tower
			for _, b in ipairs(workspace:GetChildren()) do
				if b:GetAttribute("BuildingId") == towerId then
					b:SetAttribute("Slot_"..slotIndex.."_Occupied", nil)
					break
				end
			end
		end
	end
	S.ungarrisonUnit = ungarrisonUnit


	-- If an ArcherTower is destroyed while it has garrisoned archers, kill the archers inside.
	local TOWER_DEATH_BINDS = {} -- local cache for tower death connections
	local bindTowerDeathKillsGarrison
	bindTowerDeathKillsGarrison = function(towerModel)
		if not towerModel or not towerModel:IsA("Model") then return end
		if TOWER_DEATH_BINDS[towerModel] then return end

		-- Ensure it has a stable id for matching garrisoned units
		if not towerModel:GetAttribute("BuildingId") then
			towerModel:SetAttribute("BuildingId", HttpService:GenerateGUID(false))
		end
		local towerId = towerModel:GetAttribute("BuildingId")

		local conn
		conn = towerModel.AncestryChanged:Connect(function(_, parent)
			if parent ~= nil then return end

			-- Disconnect once the tower is gone
			if conn then conn:Disconnect() end
			TOWER_DEATH_BINDS[towerModel] = nil

			-- Kill any garrisoned units that were inside this tower
			for _, unit in ipairs(unitsFolder:GetChildren()) do
				if unit:IsA("Model")
					and unit:GetAttribute("IsGarrisoned") == true
					and unit:GetAttribute("GarrisonTowerId") == towerId then

					local root = unit.PrimaryPart
					if root then root.Anchored = false end

					local hum = unit:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.Health = 0
					else
						unit:Destroy()
					end
				end
			end
		end)

		TOWER_DEATH_BINDS[towerModel] = conn
	end
	S.bindTowerDeathKillsGarrison = bindTowerDeathKillsGarrison


	local garrisonUnitInTower
	garrisonUnitInTower = function(unit, towerModel)
		bindTowerDeathKillsGarrison(towerModel)
		if unit:GetAttribute("UnitType") ~= "Archer" then return end

		local standPoint, slotIndex = getFreeStandPoint(towerModel)
		if not standPoint then return end -- Full

		-- 1. Mark Slot as Occupied
		towerModel:SetAttribute("Slot_"..slotIndex.."_Occupied", true)

		-- 2. Update Unit State
		unit:SetAttribute("IsGarrisoned", true)
		unit:SetAttribute("GarrisonSlot", slotIndex)

		unit:SetAttribute("GarrisonTowerId", towerModel:GetAttribute("BuildingId"))
		-- 3. Teleport & Anchor
		local root = unit.PrimaryPart
		local hum = unit:FindFirstChild("Humanoid")

		if root and hum then
			unit:PivotTo(standPoint.CFrame + Vector3.new(0, 2, 0)) -- Stand on top of the block
			root.Anchored = true
			hum.PlatformStand = false -- We want them to play animations, just not move
			-- Stop any existing move tracks
			setUnitWalking(unit, false)
		end
	end
	S.garrisonUnitInTower = garrisonUnitInTower

	-- [RTSUnitServer.lua] ADD THIS HELPER FUNCTION
	local getTargetRadius
	getTargetRadius = function(model)
		if not model then return 0 end

		-- 1. Check Cache
		local r = model:GetAttribute("HitboxRadius")
		if r then return r end

		-- 2. Calculate if missing (Buildings only)
		if model:GetAttribute("IsBuilding") or CollectionService:HasTag(model, "RTSBuilding") then
			local cf, size = model:GetBoundingBox()
			-- We use the smallest dimension to be safe, or average
			r = math.min(size.X, size.Z) * 0.45 
		else
			r = 0 -- Units are treated as points (or give them 1.0 radius if you prefer)
		end

		model:SetAttribute("HitboxRadius", r)
		return r
	end
	S.getTargetRadius = getTargetRadius


	local getApproachPosNearBuilding
	getApproachPosNearBuilding = function(buildingModel, fromPos)
		local buildingPos = buildingModel:GetPivot().Position
		local unitPos = fromPos
		local bRadius = getTargetRadius(buildingModel)

		-- Stand a bit outside the tower hitbox
		local sampleDist = math.max(12, bRadius + 6)

		local bestPos = buildingPos
		local bestDist = math.huge
		local found = false

		for i = 0, 5 do
			local a = math.rad(i * 60)
			local offset = Vector3.new(math.cos(a), 0, math.sin(a)) * sampleDist
			local testPos = buildingPos + offset

			local tile = getHexTileFromWorld(testPos)
			if tile and not isForbiddenDestinationTile(tile)
				and tile:GetAttribute("HasTree") ~= true
				and tile:GetAttribute("IsBuilding") ~= true then

				local d = (testPos - unitPos).Magnitude
				if d < bestDist then
					bestDist = d
					bestPos = testPos
					found = true
				end
			end
		end

		if not found then
			bestPos = buildingPos + Vector3.new(sampleDist, 0, 0)
		end

		return rayToGround(bestPos)
	end
	S.getApproachPosNearBuilding = getApproachPosNearBuilding


	CommandMove.OnServerEvent:Connect(function(plr, unitIds, targetPos, addToQueue, faceYaw)
		if typeof(targetPos) ~= "Vector3" then return end
		if typeof(unitIds) ~= "table" then return end
		addToQueue = (addToQueue == true)
		if typeof(faceYaw) ~= "number" then
			faceYaw = nil
		end

		local idMap = buildIdMapForPlayer(plr)

		local valid = {}
		for _, id in ipairs(unitIds) do
			if typeof(id) == "string" and idMap[id] then
				table.insert(valid, idMap[id])
			end
		end
		if #valid == 0 then return end

		-- [[ MANUAL GARRISON CHANGE ]]
		-- Movement never auto-enters towers. If a unit is currently garrisoned, a move command will pull it out first.
		for i, unit in ipairs(valid) do
			if unit:GetAttribute("IsGarrisoned") then
				ungarrisonUnit(unit)
			end

			enqueueMove(plr, unit, targetPos, i, #valid, addToQueue, faceYaw)
		end
	end)


	-- Manual garrison (Press E on an ArcherTower)
	CommandGarrisonTower.OnServerEvent:Connect(function(plr, unitIds, towerModel, addToQueue)
		if typeof(unitIds) ~= "table" then return end
		addToQueue = (addToQueue == true)

		if typeof(towerModel) ~= "Instance" or not towerModel or not towerModel:IsA("Model") then return end
		if not towerModel.Parent then return end
		if towerModel:GetAttribute("BuildingType") ~= "ArcherTower" then return end
		if towerModel:GetAttribute("OwnerUserId") ~= plr.UserId then return end

		local idMap = buildIdMapForPlayer(plr)

		local valid = {}
		for _, id in ipairs(unitIds) do
			if typeof(id) == "string" and idMap[id] then
				table.insert(valid, idMap[id])
			end
		end
		if #valid == 0 then return end

		for i, unit in ipairs(valid) do
			if not unit or not unit.Parent then continue end
			if unit:GetAttribute("UnitType") ~= "Archer" then continue end
			if unit:GetAttribute("IsDead") then continue end

			-- Pull out first if already in a tower
			if unit:GetAttribute("IsGarrisoned") then
				ungarrisonUnit(unit)
			end

			local unitPos = unit:GetPivot().Position
			local approachPos = getApproachPosNearBuilding(towerModel, unitPos)

			enqueueMove(plr, unit, approachPos, i, #valid, addToQueue, nil)

			-- Watch for reaching the approach point, then garrison
			task.spawn(function()
				local timeoutAt = os.clock() + 6.0
				while os.clock() < timeoutAt
					and unit.Parent
					and not unit:GetAttribute("IsDead")
					and towerModel.Parent do

					if unit:GetAttribute("IsGarrisoned") then
						return
					end

					local root = unit.PrimaryPart
					if not root then return end

					local distXZ = (Vector3.new(root.Position.X, 0, root.Position.Z)
						- Vector3.new(approachPos.X, 0, approachPos.Z)).Magnitude

					if distXZ <= 2.5 then
						garrisonUnitInTower(unit, towerModel)
						return
					end

					task.wait(0.2)
				end
			end)
		end
	end)



	local tweenModelPivot
	tweenModelPivot = function(model, goalCFrame, duration)
		if not model or not model.Parent then return end

		local cf = Instance.new("CFrameValue")
		cf.Value = model:GetPivot()

		local conn
		conn = cf.Changed:Connect(function(v)
			if model and model.Parent then
				model:PivotTo(v)
			end
		end)

		local tween = TweenService:Create(
			cf,
			TweenInfo.new(duration or 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = goalCFrame }
		)

		tween.Completed:Connect(function()
			if conn then conn:Disconnect() end
			cf:Destroy()
		end)

		tween:Play()
	end
	S.tweenModelPivot = tweenModelPivot


	local getBestTreeRootPart
	getBestTreeRootPart = function(treeModel)
		local best, bestY = nil, -math.huge
		for _, d in ipairs(treeModel:GetDescendants()) do
			if d:IsA("BasePart") then
				if d.Size.Y > bestY then
					bestY = d.Size.Y
					best = d
				end
			end
		end
		return best
	end
	S.getBestTreeRootPart = getBestTreeRootPart


	local fallTree
	fallTree = function(treeModel, chopperModel)
		if not treeModel or not treeModel.Parent then return end
		if treeModel:GetAttribute("Falling") then return end
		treeModel:SetAttribute("Falling", true)

		local trunk = treeModel:FindFirstChild("Cylinder", true) or treeModel.PrimaryPart
		if not trunk or not trunk:IsA("BasePart") then return end
		treeModel.PrimaryPart = trunk

		for _, p in ipairs(treeModel:GetDescendants()) do
			if p:IsA("BasePart") and p ~= trunk then
				local already = false
				for _, c in ipairs(trunk:GetChildren()) do
					if c:IsA("WeldConstraint") and c.Part1 == p then
						already = true
						break
					end
				end
				if not already then
					local w = Instance.new("WeldConstraint")
					w.Part0 = trunk
					w.Part1 = p
					w.Parent = trunk
				end

				p.CanCollide = false
				p.Massless = true
			end
		end

		trunk.CanCollide = true
		trunk.Massless = false

		for _, p in ipairs(treeModel:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
			end
		end

		pcall(function() trunk:SetNetworkOwner(nil) end)
		trunk.AssemblyLinearVelocity = Vector3.zero
		trunk.AssemblyAngularVelocity = Vector3.zero

		local fallDir = Vector3.new(1, 0, 0)
		if chopperModel and chopperModel.PrimaryPart then
			local d = (trunk.Position - chopperModel.PrimaryPart.Position)
			d = Vector3.new(d.X, 0, d.Z)
			if d.Magnitude > 0.1 then
				fallDir = d.Unit
			end
		end

		local mass = math.max(trunk.AssemblyMass, 1)
		local topPos = trunk.Position + trunk.CFrame.UpVector * (trunk.Size.Y * 0.5)

		local NUDGE_LINEAR  = 2.0   
		local NUDGE_ANGULAR = 5.0    

		trunk:ApplyImpulseAtPosition(fallDir * (mass * NUDGE_LINEAR), topPos)

		local axisWorld = Vector3.new(0, 1, 0):Cross(fallDir)
		if axisWorld.Magnitude < 0.05 then
			axisWorld = Vector3.new(1, 0, 0)
		else
			axisWorld = axisWorld.Unit
		end
		trunk:ApplyAngularImpulse(axisWorld * (mass * NUDGE_ANGULAR))
	end
	S.fallTree = fallTree


	local executeChopSequence
	executeChopSequence = function(plr, unit, treeModel)
		if not unit or not unit.Parent then return end
		if not treeModel or not treeModel.Parent then return end

		ACTIVE_MOVE_ID[unit] = (ACTIVE_MOVE_ID[unit] or 0) + 1
		local myActionId = ACTIVE_MOVE_ID[unit]
		local q = UNIT_CMD_QUEUE[unit]
		if q then table.clear(q) end

		if not claimTree(treeModel, unit) then return end

		local treePos = treeModel:GetPivot().Position

		local root = ensurePrimaryPart(unit)
		if root then
			local dir = Vector3.new(treePos.X, root.Position.Y, treePos.Z) - root.Position
			if dir.Magnitude > 0.1 then
				local faceYaw = math.atan2(dir.X, dir.Z)
				ACTIVE_MOVE_ID[unit] = ACTIVE_MOVE_ID[unit] - 1 
				moveUnit(plr, unit, treePos, 1, 1, faceYaw)
			end
		end

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseTree(treeModel, unit); return end

		local root2 = ensurePrimaryPart(unit)
		local hum = unit:FindFirstChildOfClass("Humanoid")

		if root2 and hum then
			local currentPos = root2.Position
			local vecToTree = (treePos - currentPos)
			local flatVec = Vector3.new(vecToTree.X, 0, vecToTree.Z)
			local dist = flatVec.Magnitude

			if dist > 1.2 then
				local targetPos = currentPos + (flatVec.Unit * (dist - 1.2))
				setUnitWalking(unit, true)
				hum:MoveTo(targetPos)
				waitArrive(hum, root2, targetPos, 2.5, 0.1)
				setUnitWalking(unit, false)
			end
		end

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseTree(treeModel, unit); return end

		if root2 then
			local dir = (treePos - root2.Position) * Vector3.new(1, 0, 1) 
			if dir.Magnitude > 0.1 then
				local targetYaw = math.atan2(dir.X, dir.Z) + math.pi
				smoothFaceYaw(unit, hum, root2, targetYaw, 0.2, myActionId)
			end
		end

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseTree(treeModel, unit); return end

		local chopTrack = playChopAnimation(unit)
		UNIT_ACTION_TRACKS[unit] = chopTrack

		local chopTime = treeModel:GetAttribute("ChopTime") or 2.5
		task.wait(math.clamp(chopTime, 0.3, 10))

		if chopTrack then chopTrack:Stop(0.2); chopTrack:Destroy() end
		UNIT_ACTION_TRACKS[unit] = nil

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseTree(treeModel, unit); return end

		local yield = treeModel:GetAttribute("WoodYield") or 12
		if plr then addWood(plr, yield) end

		if plr then
			treeModel:SetAttribute("MarkedForChop_" .. tostring(plr.UserId), nil) 
		end 

		local tile = getHexTileFromWorld(treePos)
		if tile then tile:SetAttribute("HasTree", false) end

		fallTree(treeModel, unit)

		task.delay(3, function()
			if treeModel then treeModel:Destroy() end
			clearTreeClaim(treeModel)
		end)
	end
	S.executeChopSequence = executeChopSequence

	local executeMineStoneSequence
	executeMineStoneSequence = function(plr, unit, stoneModel)
		stoneModel = (normalizeStoneModel and normalizeStoneModel(stoneModel)) or stoneModel
		if not unit or not unit.Parent then return end
		if not stoneModel or not stoneModel.Parent then return end

		ACTIVE_MOVE_ID[unit] = (ACTIVE_MOVE_ID[unit] or 0) + 1
		local myActionId = ACTIVE_MOVE_ID[unit]
		local q = UNIT_CMD_QUEUE[unit]
		if q then table.clear(q) end

		if not claimStone(stoneModel, unit) then return end

		local stonePos = stoneModel:GetPivot().Position

		local root = ensurePrimaryPart(unit)
		if root then
			local dir = Vector3.new(stonePos.X, root.Position.Y, stonePos.Z) - root.Position
			if dir.Magnitude > 0.1 then
				local faceYaw = math.atan2(dir.X, dir.Z)
				ACTIVE_MOVE_ID[unit] = ACTIVE_MOVE_ID[unit] - 1
				moveUnit(plr, unit, stonePos, 1, 1, faceYaw)
			end
		end

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseStone(stoneModel, unit); return end

		local root2 = ensurePrimaryPart(unit)
		local hum = unit:FindFirstChildOfClass("Humanoid")

		if root2 and hum then
			local currentPos = root2.Position
			local vecToStone = (stonePos - currentPos)
			local flatVec = Vector3.new(vecToStone.X, 0, vecToStone.Z)
			local dist = flatVec.Magnitude

			if dist > 1.4 then
				local targetPos = currentPos + (flatVec.Unit * (dist - 1.4))
				setUnitWalking(unit, true)
				hum:MoveTo(targetPos)
				waitArrive(hum, root2, targetPos, 2.5, 0.1)
				setUnitWalking(unit, false)
			end
		end

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseStone(stoneModel, unit); return end

		-- Reuse chop animation for mining (fastest like wood parity)
		local chopTrack = playChopAnimation(unit)
		UNIT_ACTION_TRACKS[unit] = chopTrack

		local mineTime = stoneModel:GetAttribute("MineTime") or 2.5
		task.wait(math.clamp(mineTime, 0.3, 10))

		if chopTrack then chopTrack:Stop(0.2); chopTrack:Destroy() end
		UNIT_ACTION_TRACKS[unit] = nil

		if ACTIVE_MOVE_ID[unit] ~= myActionId then releaseStone(stoneModel, unit); return end

		local yield = stoneModel:GetAttribute("StoneYield") or 5
		if plr then addStone(plr, yield) end

		if plr then
			stoneModel:SetAttribute("MarkedForMine_" .. tostring(plr.UserId), nil)
		end

		task.delay(0.2, function()
			if stoneModel then stoneModel:Destroy() end
			clearStoneClaim(stoneModel)
		end)
	end
	S.executeMineStoneSequence = executeMineStoneSequence

	CommandChopTree.OnServerEvent:Connect(function(plr, unitIds, treeModel, addToQueue)
		if typeof(unitIds) ~= "table" then return end
		if not isValidTreeModel(treeModel) then return end

		treeModel:SetAttribute("MarkedForChop", true)

		local idMap = buildIdMapForPlayer(plr)
		for _, id in ipairs(unitIds) do
			local unit = idMap[id]
			if unit and unit:GetAttribute("UnitType") == "Builder" then
				task.spawn(function()
					executeChopSequence(plr, unit, treeModel)
				end)
			end
		end
	end)

	CommandMineStone.OnServerEvent:Connect(function(plr, unitIds, stoneModel, addToQueue)
		stoneModel = (normalizeStoneModel and normalizeStoneModel(stoneModel)) or stoneModel
		if typeof(unitIds) ~= "table" then return end
		if not isValidStoneModel(stoneModel) then return end

		stoneModel:SetAttribute("MarkedForMine", true)

		local idMap = buildIdMapForPlayer(plr)
		for _, id in ipairs(unitIds) do
			local unit = idMap[id]
			if unit and unit:GetAttribute("UnitType") == "Builder" then
				task.spawn(function()
					executeMineStoneSequence(plr, unit, stoneModel)
				end)
			end
		end
	end)


	-- Export locals (final values)
	S.TOWER_DEATH_BINDS = TOWER_DEATH_BINDS
	return true
end