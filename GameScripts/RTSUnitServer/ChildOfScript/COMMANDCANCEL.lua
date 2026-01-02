-- Modules/COMMANDCANCEL.lua
return function(S)
	-- Section: COMMAND CANCEL
	-- Aliases from shared state
	local ACTIVE_MOVE_ID = S.ACTIVE_MOVE_ID
	local BUILDING_TAG = S.BUILDING_TAG
	local CollectionService = S.CollectionService
	local CommandCancel = S.CommandCancel
	local DeleteUnit = S.DeleteUnit
	local PathUpdate = S.PathUpdate
	local PlayerBaseModel = S.PlayerBaseModel
	local Players = S.Players
	local ProductionQueues = S.ProductionQueues
	local QUEUE_RUNNING = S.QUEUE_RUNNING
	local QueueRunning = S.QueueRunning
	local RecruitUnit = S.RecruitUnit
	local ClientNotify = S.ClientNotify
	local ReplicatedStorage = S.ReplicatedStorage
	local RunService = S.RunService
	local ToggleTreeMark = S.ToggleTreeMark
	local TreeClaims = S.TreeClaims
	local UNIT_ACTION_TRACKS = S.UNIT_ACTION_TRACKS
	local UNIT_CMD_QUEUE = S.UNIT_CMD_QUEUE
	local UNIT_TAG = S.UNIT_TAG
	local UNIT_TYPES = S.UNIT_TYPES
	local UpdateBaseQueue = S.UpdateBaseQueue
	local buildIdMapForPlayer = S.buildIdMapForPlayer
	local ensurePrimaryPart = S.ensurePrimaryPart
	local getHexTileFromWorld = S.getHexTileFromWorld
	local getPlayerPopulation = S.getPlayerPopulation
	local getTargetRadius = S.getTargetRadius
	local getUnitTemplate = S.getUnitTemplate
	local isForbiddenDestinationTile = S.isForbiddenDestinationTile
	local isValidTreeModel = S.isValidTreeModel
	local prepUnitForWorld = S.prepUnitForWorld
	local randomizeSkin = S.randomizeSkin
	local rayToGround = S.rayToGround
	local releaseTree = S.releaseTree
	local setUnitNameplate = S.setUnitNameplate
	local setUnitWalking = S.setUnitWalking
	local setupUnitDeath = S.setupUnitDeath
	local unitsFolder = S.unitsFolder
	local ToggleStoneMark = S.ToggleStoneMark
	local StoneClaims = S.StoneClaims
	local releaseStone = S.releaseStone
	local isValidStoneModel = S.isValidStoneModel


	local normalizeStoneModel = S.normalizeStoneModel
	---------------------------------------------------------------------
	-- COMMAND CANCEL
	---------------------------------------------------------------------
	CommandCancel.OnServerEvent:Connect(function(plr, unitIds)
		if typeof(unitIds) ~= "table" then return end

		local idMap = buildIdMapForPlayer(plr)

		local validUnits = {}
		for _, id in ipairs(unitIds) do
			if typeof(id) == "string" and idMap[id] then
				table.insert(validUnits, idMap[id])
			end
		end

		for _, unit in ipairs(validUnits) do
			ACTIVE_MOVE_ID[unit] = (ACTIVE_MOVE_ID[unit] or 0) + 1

			local q = UNIT_CMD_QUEUE[unit]
			if q then
				table.clear(q)
			end
			QUEUE_RUNNING[unit] = false

			if UNIT_ACTION_TRACKS[unit] then
				UNIT_ACTION_TRACKS[unit]:Stop(0.1) 
				UNIT_ACTION_TRACKS[unit]:Destroy()
				UNIT_ACTION_TRACKS[unit] = nil
			end

			setUnitWalking(unit, false)

			local unitId = unit:GetAttribute("UnitId")
			PathUpdate:FireClient(plr, "DONE", unitId, nil, nil)
			PathUpdate:FireClient(plr, "NEXT_CLEAR", unitId, nil, nil)

			local hum = unit:FindFirstChildOfClass("Humanoid")
			local root = ensurePrimaryPart(unit)
			if hum and root then
				hum:MoveTo(root.Position)
			end

			for tree, owner in pairs(TreeClaims) do
				if owner == unit then
					releaseTree(tree, unit)
				end
			end
			for stone, owner in pairs(StoneClaims) do
				if owner == unit then
					releaseStone(stone, unit)
				end
			end
		end
	end)

	-- [[ NEW: DELETE OWNED UNIT (Roster GUI) ]]
	local findUnitById
	findUnitById = function(unitId)
		if typeof(unitId) ~= "string" then return nil end
		for _, u in ipairs(unitsFolder:GetChildren()) do
			if u:IsA("Model") and u:GetAttribute("UnitId") == unitId then
				return u
			end
		end
		return nil
	end
	S.findUnitById = findUnitById


	DeleteUnit.OnServerEvent:Connect(function(plr, unitId)
		if typeof(unitId) ~= "string" then return end

		local unit = findUnitById(unitId)
		if not unit then return end

		-- Security: only allow deleting your own units
		if unit:GetAttribute("OwnerUserId") ~= plr.UserId then return end

		-- If garrisoned, clear the state so nothing stays stuck
		if unit:GetAttribute("IsGarrisoned") then
			unit:SetAttribute("IsGarrisoned", false)
			unit:SetAttribute("GarrisonedIn", nil)
		end

		-- Prefer killing via Humanoid so existing cleanup logic runs
		local hum = unit:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = 0
		else
			unit:Destroy()
		end
	end)

	ToggleTreeMark.OnServerEvent:Connect(function(plr, treeModel)
		if isValidTreeModel(treeModel) then
			local attrName = "MarkedForChop_" .. tostring(plr.UserId)
			local current = treeModel:GetAttribute(attrName)
			treeModel:SetAttribute(attrName, not current)
		end
	end)

	ToggleStoneMark.OnServerEvent:Connect(function(plr, stoneModel)
		stoneModel = (normalizeStoneModel and normalizeStoneModel(stoneModel)) or stoneModel
		if isValidStoneModel(stoneModel) then
			local attrName = "MarkedForMine_" .. tostring(plr.UserId)
			local current = stoneModel:GetAttribute(attrName)
			stoneModel:SetAttribute(attrName, not current)
		end
	end)

	-- [[ NEW: RECRUITMENT SYSTEM (Safe Spawn) ]]

	local UNIT_COST_GOLD = 100
	local UNIT_COST_WOOD = 50
	local RECRUIT_TIME = 5


	local processQueue
	processQueue = function(plr)
		if QueueRunning[plr.UserId] then return end
		QueueRunning[plr.UserId] = true

		local queue = ProductionQueues[plr.UserId]

		while queue and #queue > 0 do
			local currentItem = queue[1]
			local totalTime = 5 
			local elapsed = 0

			while elapsed < totalTime do
				if not plr.Parent then break end

				local remaining = totalTime - elapsed
				UpdateBaseQueue:FireClient(plr, true, remaining, totalTime, #queue - 1)

				task.wait(0.5)
				elapsed += 0.5
			end

			if plr.Parent then
				local template = getUnitTemplate()
				local basePos = plr:GetAttribute("RTS_BasePos")

				if template and basePos then
					local spawnPos = nil
					for i = 1, 12 do
						local angle = math.random() * math.pi * 2
						local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 12
						local tPos = rayToGround(basePos + offset)
						local tile = getHexTileFromWorld(tPos)
						if tile and not isForbiddenDestinationTile(tile) then spawnPos = tPos; break end
					end

					if spawnPos then
						local n = math.random(1000,9999)
						local unit = template:Clone()
						unit.Name = ("Builder_%d_%d"):format(plr.UserId, n)
						unit.Parent = unitsFolder
						randomizeSkin(unit)
						prepUnitForWorld(unit)
						unit:SetAttribute("OwnerUserId", plr.UserId)
						unit:SetAttribute("UnitId", ("%d_%d"):format(plr.UserId, n))
						CollectionService:AddTag(unit, UNIT_TAG)
						unit:SetAttribute("UnitType", "Builder")
						setUnitNameplate(unit, plr.Name, "Builder")
						unit:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))
					end
				end
			end

			table.remove(queue, 1) 
		end

		QueueRunning[plr.UserId] = false
		if plr.Parent then
			UpdateBaseQueue:FireClient(plr, false, 0, 1, 0) 
		end
	end
	S.processQueue = processQueue


	-- [RTSUnitServer.lua] REPLACE RecruitUnit.OnServerEvent

	RecruitUnit.OnServerEvent:Connect(function(plr, unitType, buildingModel)
		local stats = UNIT_TYPES[unitType]
		if not stats then return end

		-- Determine Queue Key (Unique per building or player base)
		local queueKey = nil
		if unitType == "Builder" then
			-- Builder Queue (Tied to Player)
			queueKey = plr.UserId
		else
			-- Combat Unit Queue (Tied to Specific Building)
			-- Security: Building must exist and belong to player
			if not buildingModel or buildingModel:GetAttribute("OwnerUserId") ~= plr.UserId then return end
			queueKey = buildingModel
		end

		-- Initialize Queue
		if not ProductionQueues[queueKey] then ProductionQueues[queueKey] = {} end
		local queue = ProductionQueues[queueKey]

		-- Check Population Limit
		local currentPop = getPlayerPopulation(plr)
		local maxPop = plr:GetAttribute("MaxPopulation") or 10
		if (currentPop + #queue) >= maxPop then
			ClientNotify:FireClient(plr, {
				Kind = "PopFull",
				Title = "Population full",
				Text = ("Not enough population room to queue %s. You have %d/%d. Build more Houses.")
					:format(tostring(unitType), tonumber(currentPop) or 0, tonumber(maxPop) or 0),
				FlashPop = true,
			})
			return
		end 

		-- Check Resources
		local gold = plr:GetAttribute("Gold") or 0
		local wood = plr:GetAttribute("Wood") or 0

		if gold >= stats.Cost.Gold and wood >= stats.Cost.Wood then
			-- Deduct Cost Immediately
			plr:SetAttribute("Gold", gold - stats.Cost.Gold)
			plr:SetAttribute("Wood", wood - stats.Cost.Wood)

			table.insert(queue, { Type = unitType })

			-- Start Queue Processing Loop (if not already running for this key)
			if not QueueRunning[queueKey] then
				task.spawn(function()
					QueueRunning[queueKey] = true

					while queue and #queue > 0 do
						local item = queue[1]
						local uStats = UNIT_TYPES[item.Type]
						local timeReq = uStats.BuildTime

						local elapsed = 0
						while elapsed < timeReq do
							if not plr.Parent then break end
							-- Send Update to Client
							UpdateBaseQueue:FireClient(plr, true, timeReq - elapsed, timeReq, #queue - 1, buildingModel)
							task.wait(0.5)
							elapsed += 0.5
						end

						-- Spawn Unit
						if plr.Parent then
							local template = ReplicatedStorage:WaitForChild("Units"):FindFirstChild(item.Type)
							if template then
								-- Calculate Spawn Position
								local origin = nil
								local avoidModel = buildingModel -- The model to NOT spawn inside

								if unitType == "Builder" then
									origin = plr:GetAttribute("RTS_BasePos")
									avoidModel = PlayerBaseModel[plr.UserId] -- Avoid base
								elseif buildingModel then
									origin = buildingModel:GetPivot().Position
								end

								if origin then
									local spawnPos = origin + Vector3.new(8, 0, 0) -- fallback
									local radius = 15 -- Push units out 15 studs to clear building

									-- Find valid tile nearby
									for i=1, 12 do
										local angle = math.random() * math.pi * 2
										local off = Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
										local t = getHexTileFromWorld(origin + off)

										-- Ensure valid, walkable, and NOT the building itself
										if t and not isForbiddenDestinationTile(t) and t ~= avoidModel then
											spawnPos = t:GetPivot().Position
											break
										end
									end

									local n = math.random(1000,99999)
									local unit = template:Clone()
									unit.Name = (item.Type .. "_%d_%d"):format(plr.UserId, n)
									unit.Parent = unitsFolder

									local hum = unit:FindFirstChildOfClass("Humanoid")
									if hum then 
										hum.MaxHealth = uStats.MaxHP
										hum.Health = uStats.MaxHP
										hum.Died:Connect(function()
											unit:SetAttribute("IsDead", true)
											CollectionService:RemoveTag(unit, UNIT_TAG) 
											local np = unit:FindFirstChild("RTS_Nameplate")
											if np then np:Destroy() end
											task.delay(3, function()
												if unit then unit:Destroy() end
											end)
										end)
									end

									randomizeSkin(unit)
									prepUnitForWorld(unit)

									unit:SetAttribute("OwnerUserId", plr.UserId)
									unit:SetAttribute("UnitId", ("%d_%d"):format(plr.UserId, n))
									CollectionService:AddTag(unit, UNIT_TAG)
									-- [RTSUnitServer.lua] Inside RecruitUnit.OnServerEvent, where unit is created
									-- ...
									unit:SetAttribute("UnitType", item.Type)
									setUnitNameplate(unit, plr.Name, item.Type)

									local root = ensurePrimaryPart(unit)
									if root then root:SetNetworkOwner(nil) end

									-- [[ NEW: Connect Death Logic ]]
									setupUnitDeath(unit, plr)

									unit:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 3, 0)))
								end
							end
						end
						table.remove(queue, 1)
					end

					QueueRunning[queueKey] = false
					-- Clear Queue UI on Client
					UpdateBaseQueue:FireClient(plr, false, 0, 1, 0, buildingModel)
				end)
			else
				-- If queue is already running, just update the client immediately so they see the count increase
				UpdateBaseQueue:FireClient(plr, true, stats.BuildTime, stats.BuildTime, #queue - 1, buildingModel)
			end
		end
	end)

	---------------------------------------------------------------------

	return true
end
