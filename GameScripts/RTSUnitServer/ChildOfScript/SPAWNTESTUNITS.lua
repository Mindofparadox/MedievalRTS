-- Modules/SPAWNTESTUNITS.lua
return function(S)
	-- Section: SPAWN TEST UNITS
	-- Aliases from shared state
	local ARRIVE_RADIUS = S.ARRIVE_RADIUS
	local CollectionService = S.CollectionService
	local EDGE_JUMP_RADIUS = S.EDGE_JUMP_RADIUS
	local MAX_STEP_UP = S.MAX_STEP_UP
	local PATH_AGENT = S.PATH_AGENT
	local PathUpdate = S.PathUpdate
	local PathfindingService = S.PathfindingService
	local PlayerBaseModel = S.PlayerBaseModel
	local Players = S.Players
	local RunService = S.RunService
	local TILE_STEP = S.TILE_STEP
	local UNIT_TAG = S.UNIT_TAG
	local UnitAnim = S.UnitAnim
	local ensurePrimaryPart = S.ensurePrimaryPart
	local getHexTileFromWorld = S.getHexTileFromWorld
	local getUnitTemplate = S.getUnitTemplate
	local isForbiddenDestinationTile = S.isForbiddenDestinationTile
	local linksFolder = S.linksFolder
	local prepUnitForWorld = S.prepUnitForWorld
	local randomizeSkin = S.randomizeSkin
	local rayToGround = S.rayToGround
	local refreshTileIncludeList = S.refreshTileIncludeList
	local setUnitNameplate = S.setUnitNameplate
	local setUnitWalking = S.setUnitWalking
	local setupUnitDeath = S.setupUnitDeath
	local snapCommandToTileCenter = S.snapCommandToTileCenter
	local spawnPlayerBase = S.spawnPlayerBase
	local unitsFolder = S.unitsFolder

	---------------------------------------------------------------------
	-- SPAWN TEST UNITS
	---------------------------------------------------------------------
	local STARTING_BUILDERS = 2
	local BUILDER_SPAWN_RADIUS = 8

	---------------------------------------------------------------------
	-- SPAWN INITIAL (1 BASE + 1 BUILDER)
	---------------------------------------------------------------------
	local spawnInitialForPlayer
	spawnInitialForPlayer = function(plr)
		refreshTileIncludeList()

		local basePos = plr:GetAttribute("RTS_BasePos")
		if typeof(basePos) ~= "Vector3" then
			basePos = spawnPlayerBase(plr)
		end
		if typeof(basePos) ~= "Vector3" then
			return
		end

		local baseTile = getHexTileFromWorld(basePos)

		local template = getUnitTemplate()
		if not template then
			warn("RTSUnitServer: Missing template ReplicatedStorage/Units/Builder")
			return
		end

		local SPAWN_RADIUS = 10
		local ATTEMPTS_PER_UNIT = 8

		for n = 1, STARTING_BUILDERS do
			local unit = template:Clone()
			unit.Name = ("Builder_%d_%d"):format(plr.UserId, n)
			unit.Parent = unitsFolder

			randomizeSkin(unit)
			prepUnitForWorld(unit)

			local hum = unit:FindFirstChildOfClass("Humanoid")
			local root = ensurePrimaryPart(unit)

			if not hum or not root then
				unit:Destroy()
			else
				unit:SetAttribute("OwnerUserId", plr.UserId)
				unit:SetAttribute("UnitId", ("%d_%d"):format(plr.UserId, n))
				CollectionService:AddTag(unit, UNIT_TAG)
				unit:SetAttribute("UnitType", "Builder")
				setUnitNameplate(unit, plr.Name, "Builder")

				local root = ensurePrimaryPart(unit)
				if root then root:SetNetworkOwner(nil) end

				-- [[ NEW: Connect Death Logic ]]
				setupUnitDeath(unit, plr)

				-- [[ FIXED: Removed extra 'end' here ]] 

				local spawned = false

				for i = 0, ATTEMPTS_PER_UNIT - 1 do
					local baseAngle = (math.pi * 2) * ((n - 1) / math.max(STARTING_BUILDERS, 1))
					local attemptOffsetAngle = (math.pi * 2) * (i / ATTEMPTS_PER_UNIT)
					local finalAngle = baseAngle + (i > 0 and attemptOffsetAngle or 0)

					local offset = Vector3.new(math.cos(finalAngle), 0, math.sin(finalAngle)) * SPAWN_RADIUS
					local testPos = basePos + offset
					local groundPos = rayToGround(testPos)
					local tileUnder = getHexTileFromWorld(groundPos)

					local isSafeTile = tileUnder 
						and (tileUnder ~= baseTile) 
						and (not isForbiddenDestinationTile(tileUnder))

					local heightDiff = math.abs(groundPos.Y - basePos.Y)

					if isSafeTile and heightDiff < 8 then
						unit:PivotTo(CFrame.new(groundPos + Vector3.new(0, 3.0, 0)))
						spawned = true
						break
					end
				end

				if not spawned then
					local fallbackPos = rayToGround(basePos + Vector3.new(SPAWN_RADIUS, 0, 0))
					unit:PivotTo(CFrame.new(fallbackPos + Vector3.new(0, 3.0, 0)))
				end
			end
		end
	end
	S.spawnInitialForPlayer = spawnInitialForPlayer


	local STARTING_GOLD = 200
	local GOLD_TICK_SECONDS = 1
	local GOLD_TICK_AMOUNT  = 1

	local initGold
	initGold = function(plr)
		if plr:GetAttribute("Gold") == nil then
			plr:SetAttribute("Gold", STARTING_GOLD)
		end
	end
	S.initGold = initGold


	local addGold
	addGold = function(plr, amount)
		local cur = plr:GetAttribute("Gold") or 0
		plr:SetAttribute("Gold", math.max(0, cur + amount))
	end
	S.addGold = addGold


	---------------------------------------------------------------------
	-- PLAYER SPAWN (BASE + 1 BUILDER)
	---------------------------------------------------------------------
	Players.PlayerAdded:Connect(function(plr)
		initGold(plr) 

		if plr:GetAttribute("Wood") == nil then
			plr:SetAttribute("Wood", 100)
		end

		if plr:GetAttribute("Stone") == nil then
			plr:SetAttribute("Stone", 0)
		end

		-- [[ Set Base Max Population ]] --
		plr:SetAttribute("MaxPopulation", 10)

		if not plr:FindFirstChild("RTS_GoldTick") then
			local tickMarker = Instance.new("BoolValue")
			tickMarker.Name = "RTS_GoldTick"
			tickMarker.Value = true
			tickMarker.Parent = plr

			-- [[ UPDATED GOLD LOOP: INCLUDES FARM INCOME ]] --
			task.spawn(function()
				while plr.Parent do
					task.wait(1) 

					local goldIncome = 1 -- Base passive income
					local woodIncome = 0 -- Base wood income (usually 0)

					-- Scan for buildings
					for _, b in ipairs(workspace:GetChildren()) do
						if b:IsA("Model") and b:GetAttribute("OwnerUserId") == plr.UserId then
							local bType = b:GetAttribute("BuildingType")
							local isComplete = not b:GetAttribute("UnderConstruction")

							if isComplete then
								if bType == "Farm" then
									goldIncome = goldIncome + 5
								elseif bType == "RTSSawmill" then
									woodIncome = woodIncome + 2 -- [[ NEW: +2 Wood per Sawmill ]]
								end
							end
						end
					end

					plr:SetAttribute("Gold", (plr:GetAttribute("Gold") or 0) + goldIncome)
					plr:SetAttribute("Wood", (plr:GetAttribute("Wood") or 0) + woodIncome)
				end
			end)
		end

		task.spawn(function()
			local started = os.clock()
			while os.clock() - started < 15 do
				for _, inst in ipairs(workspace:GetChildren()) do
					if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
						spawnInitialForPlayer(plr)
						return
					end
				end
				task.wait(0.25)
			end
			warn("RTSUnitServer: Timed out waiting for hex tiles; can't spawn base.")
		end)
	end)



	Players.PlayerRemoving:Connect(function(plr)
		local m = PlayerBaseModel[plr.UserId]
		if m and m.Parent then
			m:Destroy()
		end
		PlayerBaseModel[plr.UserId] = nil
	end)


	---------------------------------------------------------------------
	-- STEP LINKS (neighbor tiles differ by exactly 1 level)
	---------------------------------------------------------------------
	local neighborDirs = {
		{ 1,  0},
		{ 1, -1},
		{ 0, -1},
		{-1,  0},
		{-1,  1},
		{ 0,  1},
	}

	local parseHexName
	parseHexName = function(name)
		local q, r = string.match(name, "^Hex_(-?%d+)_(-?%d+)$")
		if not q then return nil end
		return tonumber(q), tonumber(r)
	end
	S.parseHexName = parseHexName


	local hexKey
	hexKey = function(q, r)
		return tostring(q) .. "_" .. tostring(r)
	end
	S.hexKey = hexKey


	local getTileLevel
	getTileLevel = function(tileModel)
		local y = tileModel:GetPivot().Position.Y
		return math.floor((y / TILE_STEP) + 0.5)
	end
	S.getTileLevel = getTileLevel


	local clearLinks
	clearLinks = function()
		linksFolder:ClearAllChildren()
	end
	S.clearLinks = clearLinks


	local buildStepLinks
	buildStepLinks = function()
		clearLinks()
		refreshTileIncludeList()

		local tiles = {}
		for _, inst in ipairs(workspace:GetChildren()) do
			if inst:IsA("Model") then
				local q, r = parseHexName(inst.Name)
				if q and r then
					local pos = inst:GetPivot().Position
					tiles[hexKey(q, r)] = {
						model = inst,
						q = q, r = r,
						pos = pos,
						level = getTileLevel(inst),
					}
				end
			end
		end

		local made = {}
		for _, t in pairs(tiles) do
			for _, d in ipairs(neighborDirs) do
				local nq, nr = t.q + d[1], t.r + d[2]
				local nk = hexKey(nq, nr)
				local n = tiles[nk]
				if n then
					local aKey = hexKey(t.q, t.r)
					local bKey = nk
					local pairKey = (aKey < bKey) and (aKey .. "|" .. bKey) or (bKey .. "|" .. aKey)
					if not made[pairKey] then
						made[pairKey] = true

						local diff = math.abs(t.level - n.level)
						if diff == 1 then
							local mid = (t.pos + n.pos) * 0.5
							local lowY = math.min(t.pos.Y, n.pos.Y)

							local part = Instance.new("Part")
							part.Name = "StepLink_" .. pairKey
							part.Anchored = true
							part.CanCollide = false
							part.CanQuery = false
							part.CanTouch = false
							part.Transparency = 1
							part.Size = Vector3.new(0.5, 0.5, 0.5)
							part.Position = Vector3.new(mid.X, lowY, mid.Z)
							part.Parent = linksFolder

							local a0 = Instance.new("Attachment")
							a0.Name = "A0"
							a0.Position = Vector3.new(0, (t.pos.Y - part.Position.Y) + 0.25, 0)
							a0.Parent = part

							local a1 = Instance.new("Attachment")
							a1.Name = "A1"
							a1.Position = Vector3.new(0, (n.pos.Y - part.Position.Y) + 0.25, 0)
							a1.Parent = part

							local link = Instance.new("PathfindingLink")
							link.Name = "Link"
							link.Attachment0 = a0
							link.Attachment1 = a1
							link.IsBidirectional = true
							link.Parent = part
						end
					end
				end
			end
		end
	end
	S.buildStepLinks = buildStepLinks


	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < 12 do
			for _, inst in ipairs(workspace:GetChildren()) do
				if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
					buildStepLinks()
					return
				end
			end
			task.wait(0.25)
		end
		warn("RTSUnitServer: No Hex_ tiles found to build step links.")
	end)

	---------------------------------------------------------------------
	-- PATHFIND + MOVE
	---------------------------------------------------------------------
	local ACTIVE_MOVE_ID = {} 
	local moveUnit 
	local sendNextPreview 


	local UNIT_CMD_QUEUE = {}  
	local QUEUE_RUNNING  = {}  
	local UNIT_ACTION_TRACKS = {} 

	local processUnitQueue
	processUnitQueue = function(plr, unit)
		if QUEUE_RUNNING[unit] then return end
		QUEUE_RUNNING[unit] = true

		while unit and unit.Parent and UNIT_CMD_QUEUE[unit] and #UNIT_CMD_QUEUE[unit] > 0 do
			if unit:GetAttribute("OwnerUserId") ~= plr.UserId then
				break
			end
			local cmd = table.remove(UNIT_CMD_QUEUE[unit], 1)
			if not cmd then break end

			sendNextPreview(plr, unit)

			moveUnit(plr, unit, cmd.pos, cmd.slotIndex, cmd.totalUnits, cmd.faceYaw)

			sendNextPreview(plr, unit)

			task.wait(0.05)
		end

		QUEUE_RUNNING[unit] = false
	end
	S.processUnitQueue = processUnitQueue


	local enqueueMove
	enqueueMove = function(plr, unit, targetPos, slotIndex, totalUnits, addToQueue, faceYaw)
		local snapped = snapCommandToTileCenter(targetPos)
		if typeof(snapped) ~= "Vector3" then
			return
		end

		local q = UNIT_CMD_QUEUE[unit]
		if not q then
			q = {}
			UNIT_CMD_QUEUE[unit] = q
		end

		if not addToQueue then
			ACTIVE_MOVE_ID[unit] = (ACTIVE_MOVE_ID[unit] or 0) + 1
			table.clear(q)
		end

		table.insert(q, {
			pos = snapped,
			slotIndex = slotIndex,
			totalUnits = totalUnits,
			faceYaw = faceYaw,
		})

		if not QUEUE_RUNNING[unit] then
			task.spawn(processUnitQueue, plr, unit)
		end

		sendNextPreview(plr, unit)
	end
	S.enqueueMove = enqueueMove


	unitsFolder.ChildRemoved:Connect(function(child)
		UNIT_CMD_QUEUE[child] = nil
		QUEUE_RUNNING[child] = nil

		local pack = UnitAnim[child]
		if pack then
			if pack.conns then
				for _, c in pairs(pack.conns) do
					if c and c.Disconnect then
						c:Disconnect()
					end
				end
			end
			if pack.idle then pcall(function() pack.idle:Stop(0) end) end
			if pack.walk then pcall(function() pack.walk:Stop(0) end) end
			UnitAnim[child] = nil
		end
	end)


	local formationOffset
	formationOffset = function(index, total)
		if total <= 1 then
			return Vector3.zero
		end
		local spacing = 3.0
		local cols = math.ceil(math.sqrt(total))
		local row = math.floor((index - 1) / cols)
		local col = (index - 1) % cols

		local cx = (cols - 1) * 0.5
		local cz = (cols - 1) * 0.5
		return Vector3.new((col - cx) * spacing, 0, (row - cz) * spacing)
	end
	S.formationOffset = formationOffset


	local isWaypointPathValid
	isWaypointPathValid = function(fromPos, waypoints)
		local prev = rayToGround(fromPos)
		for _, wp in ipairs(waypoints) do
			local p = rayToGround(wp.Position)
			if math.abs(p.Y - prev.Y) > (MAX_STEP_UP + 0.05) then
				return false
			end
			prev = p
		end
		return true
	end
	S.isWaypointPathValid = isWaypointPathValid


	local computeWaypoints
	computeWaypoints = function(fromPos, toPos)
		local function tryWithAgent(agent)
			local path = PathfindingService:CreatePath(agent)
			path:ComputeAsync(fromPos, toPos)
			if path.Status ~= Enum.PathStatus.Success then
				return nil
			end

			local waypoints = path:GetWaypoints()
			if not waypoints or #waypoints == 0 then
				return nil
			end

			if not isWaypointPathValid(fromPos, waypoints) then
				return nil
			end

			return waypoints
		end

		local wps = tryWithAgent(PATH_AGENT)
		if wps then
			return wps
		end

		local noJumpAgent = table.clone(PATH_AGENT)
		noJumpAgent.AgentCanJump = false
		noJumpAgent.AgentJumpHeight = 0

		return tryWithAgent(noJumpAgent)
	end
	S.computeWaypoints = computeWaypoints




	sendNextPreview = function(plr, unit)
		local unitId = unit:GetAttribute("UnitId")
		if not unitId then return end

		local q = UNIT_CMD_QUEUE[unit]
		if not q or #q == 0 then
			PathUpdate:FireClient(plr, "NEXT_CLEAR", unitId, nil, nil)
			return
		end

		local root = ensurePrimaryPart(unit)
		if not root then
			PathUpdate:FireClient(plr, "NEXT_CLEAR", unitId, nil, nil)
			return
		end

		local fromPos = unit:GetAttribute("RTS_CurrentFinal")
		if typeof(fromPos) ~= "Vector3" then
			fromPos = rayToGround(root.Position)
		end

		local nextCmd = q[1]

		local tileCenter = nextCmd.pos 
		local pathTarget  = rayToGround(tileCenter)
		local finalTarget = rayToGround(tileCenter + formationOffset(nextCmd.slotIndex, nextCmd.totalUnits))

		local startFrom = rayToGround(fromPos)
		local waypoints = computeWaypoints(startFrom, pathTarget)

		if not waypoints or #waypoints == 0 then
			PathUpdate:FireClient(plr, "NEXT", unitId, { startFrom, pathTarget, finalTarget }, nil)
			return
		end

		local goals = {}
		table.insert(goals, startFrom)
		for _, wp in ipairs(waypoints) do
			table.insert(goals, rayToGround(wp.Position))
		end
		if (goals[#goals] - finalTarget).Magnitude > 0.25 then
			table.insert(goals, finalTarget)
		end

		PathUpdate:FireClient(plr, "NEXT", unitId, goals, nil)
	end



	local waitArrive
	waitArrive = function(hum, root, goalPos, timeout, arriveRadius)
		arriveRadius = arriveRadius or ARRIVE_RADIUS 

		local arrived = false
		local conn
		conn = hum.MoveToFinished:Connect(function(ok)
			arrived = ok
		end)

		local start = os.clock()

		local lastDist = math.huge
		local lastProgressT = os.clock()
		local lastJumpT = 0

		while os.clock() - start < timeout do
			local dist = (root.Position - goalPos).Magnitude

			if dist <= arriveRadius then
				conn:Disconnect()
				return true
			end

			if arrived then
				conn:Disconnect()
				return true
			end

			if dist < lastDist - 0.15 then
				lastDist = dist
				lastProgressT = os.clock()
			end

			if (os.clock() - lastProgressT) > 0.65 then
				if (os.clock() - lastJumpT) > 0.60 then
					hum.Jump = true
					hum:MoveTo(goalPos)
					lastJumpT = os.clock()
				end
				lastProgressT = os.clock()
				lastDist = dist
			end

			task.wait(0.05)
		end

		conn:Disconnect()
		return false
	end
	S.waitArrive = waitArrive



	local watchEdgeJump
	watchEdgeJump = function(unit, hum, root, edgeMidXZ, moveId)
		local conn
		conn = RunService.Heartbeat:Connect(function()
			if ACTIVE_MOVE_ID[unit] ~= moveId then
				conn:Disconnect()
				return
			end

			local p = root.Position
			local pXZ = Vector3.new(p.X, 0, p.Z)
			local d = (pXZ - edgeMidXZ).Magnitude
			if d <= EDGE_JUMP_RADIUS then
				hum.Jump = true
				conn:Disconnect()
			end
		end)
	end
	S.watchEdgeJump = watchEdgeJump


	local TWO_PI = math.pi * 2

	local lerpAngle
	lerpAngle = function(a, b, t)
		local diff = (b - a) % TWO_PI
		if diff > math.pi then
			diff -= TWO_PI
		end
		return a + diff * t
	end
	S.lerpAngle = lerpAngle


	local smoothFaceYaw
	smoothFaceYaw = function(unit, hum, root, targetYaw, duration, moveId)
		if typeof(targetYaw) ~= "number" then return end
		duration = duration or 0.22

		hum.AutoRotate = false

		local _, startYaw, _ = root.CFrame:ToOrientation()
		local startT = os.clock()

		while true do
			if not unit.Parent or ACTIVE_MOVE_ID[unit] ~= moveId then
				return
			end

			local t = (os.clock() - startT) / duration
			if t >= 1 then break end

			local y = lerpAngle(startYaw, targetYaw, t)
			local pos = root.Position
			root.CFrame = CFrame.new(pos) * CFrame.Angles(0, y, 0)

			RunService.Heartbeat:Wait()
		end

		local pos = root.Position
		root.CFrame = CFrame.new(pos) * CFrame.Angles(0, targetYaw, 0)
	end
	S.smoothFaceYaw = smoothFaceYaw


	moveUnit = function(plr, unit, targetPos, slotIndex, totalUnits, faceYaw)
		local hum = unit:FindFirstChildOfClass("Humanoid")
		local root = ensurePrimaryPart(unit)
		if not hum or not root then return end
		hum.AutoRotate = true

		ACTIVE_MOVE_ID[unit] = (ACTIVE_MOVE_ID[unit] or 0) + 1
		local myId = ACTIVE_MOVE_ID[unit]

		local tileCenter = snapCommandToTileCenter(targetPos)

		local pathTarget  = rayToGround(tileCenter)
		local finalTarget = rayToGround(tileCenter + formationOffset(slotIndex, totalUnits))

		unit:SetAttribute("RTS_CurrentFinal", finalTarget)


		local startGround = rayToGround(root.Position)
		local waypoints = computeWaypoints(startGround, pathTarget)
		if not waypoints or #waypoints == 0 then
			setUnitWalking(unit, false)

			local unitId = unit:GetAttribute("UnitId")
			PathUpdate:FireClient(plr, "DONE", unitId, nil, nil)
			unit:SetAttribute("RTS_CurrentFinal", nil)
			sendNextPreview(plr, unit)
			return
		end


		local goals = {}
		local startPt = startGround
		table.insert(goals, startPt)
		for _, wp in ipairs(waypoints) do
			table.insert(goals, rayToGround(wp.Position))
		end

		if (goals[#goals] - finalTarget).Magnitude > 0.25 then
			table.insert(goals, finalTarget)
		end


		local unitId = unit:GetAttribute("UnitId")
		PathUpdate:FireClient(plr, "NEW", unitId, goals, nil)
		sendNextPreview(plr, unit)
		setUnitWalking(unit, true, 1)


		local repathAttempts = 0

		local i = 2
		while i <= #goals do
			if ACTIVE_MOVE_ID[unit] ~= myId then
				return
			end

			local prevGoal = goals[i - 1]
			local goal = goals[i]
			if not prevGoal or not goal then
				break 
			end

			local dy = goal.Y - prevGoal.Y

			if dy > 0.5 and dy <= MAX_STEP_UP then
				local mid = (prevGoal + goal) * 0.5
				local edgeMidXZ = Vector3.new(mid.X, 0, mid.Z)
				watchEdgeJump(unit, hum, root, edgeMidXZ, myId)
			end

			setUnitWalking(unit, true, 1)
			hum:MoveTo(goal)
			local ok = waitArrive(hum, root, goal, 6)

			if ACTIVE_MOVE_ID[unit] ~= myId then
				return
			end

			PathUpdate:FireClient(plr, "PROGRESS", unitId, nil, i)

			if not ok then
				local retryDy = goal.Y - root.Position.Y
				if retryDy > 0.5 and retryDy <= MAX_STEP_UP then
					hum.Jump = true
					setUnitWalking(unit, true, 1)
					hum:MoveTo(goal)
					ok = waitArrive(hum, root, goal, 3)
				end

				if not ok then
					repathAttempts += 1
					if repathAttempts > 2 then
						break
					end

					startGround = rayToGround(root.Position)
					waypoints = computeWaypoints(startGround, pathTarget)
					if not waypoints or #waypoints == 0 then
						break
					end

					goals = {}
					startPt = startGround
					table.insert(goals, startPt)
					for _, wp in ipairs(waypoints) do
						table.insert(goals, rayToGround(wp.Position))
					end

					if (goals[#goals] - finalTarget).Magnitude > 0.25 then
						table.insert(goals, finalTarget)
					end

					PathUpdate:FireClient(plr, "NEW", unitId, goals, nil)

					i = 2
					continue
				end
			end

			i += 1
		end

		local reachedFinal = (i > #goals)

		setUnitWalking(unit, false)

		if reachedFinal and typeof(faceYaw) == "number" then
			local settleStart = os.clock()
			while os.clock() - settleStart < 0.25 do
				if root.AssemblyLinearVelocity.Magnitude < 0.15 then
					break
				end
				task.wait(0.03)
			end

			smoothFaceYaw(unit, hum, root, faceYaw, 0.22, myId)
		else
			hum.AutoRotate = true
		end

		PathUpdate:FireClient(plr, "DONE", unitId, nil, nil)
		unit:SetAttribute("RTS_CurrentFinal", nil)
		sendNextPreview(plr, unit)


	end

	-- Export locals (final values)
	S.ACTIVE_MOVE_ID = ACTIVE_MOVE_ID
	S.BUILDER_SPAWN_RADIUS = BUILDER_SPAWN_RADIUS
	S.GOLD_TICK_AMOUNT = GOLD_TICK_AMOUNT
	S.GOLD_TICK_SECONDS = GOLD_TICK_SECONDS
	S.QUEUE_RUNNING = QUEUE_RUNNING
	S.STARTING_BUILDERS = STARTING_BUILDERS
	S.STARTING_GOLD = STARTING_GOLD
	S.TWO_PI = TWO_PI
	S.UNIT_ACTION_TRACKS = UNIT_ACTION_TRACKS
	S.UNIT_CMD_QUEUE = UNIT_CMD_QUEUE
	S.moveUnit = moveUnit
	S.neighborDirs = neighborDirs
	S.sendNextPreview = sendNextPreview
	return true
end