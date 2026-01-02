-- Modules/UNITLOGICEXECUTION.lua
return function(S)
	-- Section: UNIT LOGIC EXECUTION
	-- Aliases from shared state
	local RunService = S.RunService
	local CollectionService = S.CollectionService
	local PathfindingService = S.PathfindingService
	local Players = S.Players

	local STONE_TAG = S.STONE_TAG
	local StoneClaims = S.StoneClaims
	local isValidStoneModel = S.isValidStoneModel
	local executeMineStoneSequence = S.executeMineStoneSequence

	local ATTACK_ANIMS = S.ATTACK_ANIMS
	local BUILDING_TAG = S.BUILDING_TAG
	local COMBAT_TICK_RATE = S.COMBAT_TICK_RATE or 0.2
	local PATH_AGENT = S.PATH_AGENT
	local QUEUE_RUNNING = S.QUEUE_RUNNING

	local TREE_TAG = S.TREE_TAG
	local TreeClaims = S.TreeClaims

	local UNIT_ACTION_TRACKS = S.UNIT_ACTION_TRACKS
	local UNIT_CMD_QUEUE = S.UNIT_CMD_QUEUE
	local UNIT_TYPES = S.UNIT_TYPES
	local VisualEffect = S.VisualEffect

	local WORKER_TICK_RATE = S.WORKER_TICK_RATE or 0.6
	S.COMBAT_TICK_RATE = COMBAT_TICK_RATE
	S.WORKER_TICK_RATE = WORKER_TICK_RATE

	local destroyStructure = S.destroyStructure
	local ensurePrimaryPart = S.ensurePrimaryPart
	local executeBuildSequence = S.executeBuildSequence
	local executeChopSequence = S.executeChopSequence
	local findNearestEnemy = S.findNearestEnemy
	local getCombatAnim = S.getCombatAnim
	local getHexTileFromWorld = S.getHexTileFromWorld
	local getTargetRadius = S.getTargetRadius
	local isValidTreeModel = S.isValidTreeModel
	local setUnitWalking = S.setUnitWalking

	local unitsFolder = S.unitsFolder

	-----------------------------------------------------------------
	-- COMBAT/AI HELPERS (restored from monolithic script)
	-----------------------------------------------------------------
	local UnreachableCache = S.UnreachableCache or {}
	S.UnreachableCache = UnreachableCache

	local CombatAnimCache = S.CombatAnimCache or {}
	S.CombatAnimCache = CombatAnimCache

	local markUnreachable = S.markUnreachable
	if not markUnreachable then
		markUnreachable = function(unit, targetModel)
			if not UnreachableCache[unit] then UnreachableCache[unit] = {} end
			UnreachableCache[unit][targetModel] = os.clock() + 3.0
		end
		S.markUnreachable = markUnreachable
	end

	local isUnreachable = S.isUnreachable
	if not isUnreachable then
		isUnreachable = function(unit, targetModel)
			if not UnreachableCache[unit] then return false end
			local expire = UnreachableCache[unit][targetModel]
			if expire and os.clock() < expire then
				return true
			end
			if expire then UnreachableCache[unit][targetModel] = nil end
			return false
		end
		S.isUnreachable = isUnreachable
	end

	if not getCombatAnim then
		getCombatAnim = function(hum, animId)
			if not CombatAnimCache[hum] then CombatAnimCache[hum] = {} end
			if CombatAnimCache[hum][animId] then return CombatAnimCache[hum][animId] end

			local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
			local anim = Instance.new("Animation")
			anim.AnimationId = animId
			local track = animator:LoadAnimation(anim)
			track.Priority = Enum.AnimationPriority.Action
			CombatAnimCache[hum][animId] = track
			return track
		end
		S.getCombatAnim = getCombatAnim
	end

	if not findNearestEnemy then
		findNearestEnemy = function(unit, range)
			local myOwner = unit:GetAttribute("OwnerUserId")
			local root = ensurePrimaryPart(unit)
			if not root then return nil end

			local bestTarget = nil
			local minDst = range

			local function check(target)
				local tRoot = ensurePrimaryPart(target)
				if tRoot then
					local rawDist = (tRoot.Position - root.Position).Magnitude
					local edgeDist = rawDist - getTargetRadius(target)
					if edgeDist < minDst then
						minDst = edgeDist
						return true
					end
				end
				return false
			end

			for _, other in ipairs(unitsFolder:GetChildren()) do
				if other:IsA("Model") and other ~= unit then
					local otherOwner = other:GetAttribute("OwnerUserId")
					if otherOwner and otherOwner ~= myOwner then
						if isUnreachable(unit, other) then continue end
						local oHum = other:FindFirstChildOfClass("Humanoid")
						if oHum and oHum.Health > 0 then
							if check(other) then bestTarget = other end
						end
					end
				end
			end

			local buildings = CollectionService:GetTagged(BUILDING_TAG)
			for _, b in ipairs(buildings) do
				local bOwner = b:GetAttribute("OwnerUserId")
				if bOwner and bOwner ~= myOwner and not b:GetAttribute("IsDead") and not b:GetAttribute("UnderConstruction") then
					if check(b) then bestTarget = b end
				end
			end

			return bestTarget
		end
		S.findNearestEnemy = findNearestEnemy
	end

	if unitsFolder and not S.__CombatCacheCleanupHooked then
		S.__CombatCacheCleanupHooked = true
		unitsFolder.ChildRemoved:Connect(function(child)
			local hum = child:FindFirstChildOfClass("Humanoid")
			if hum and CombatAnimCache[hum] then CombatAnimCache[hum] = nil end
			if UnreachableCache[child] then UnreachableCache[child] = nil end
		end)
	end

	local sightParams = S.sightParams
	if not sightParams then
		sightParams = RaycastParams.new()
		sightParams.IgnoreWater = true
		sightParams.FilterType = Enum.RaycastFilterType.Exclude
		sightParams.FilterDescendantsInstances = { unitsFolder }
		S.sightParams = sightParams
	else
		sightParams.FilterType = sightParams.FilterType or Enum.RaycastFilterType.Exclude
		sightParams.FilterDescendantsInstances = sightParams.FilterDescendantsInstances or { unitsFolder }
	end

	-----------------------------------------------------------------
	-- MAIN LOOP
	-----------------------------------------------------------------
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()

		for _, unit in ipairs(unitsFolder:GetChildren()) do
			if not unit:IsA("Model") then continue end
			if unit:GetAttribute("IsDead") then continue end

			if not unit:GetAttribute("NextThink") then
				unit:SetAttribute("NextThink", now + math.random() * 0.5)
				continue
			end
			if now < unit:GetAttribute("NextThink") then continue end

			local uType = unit:GetAttribute("UnitType")
			local isBuilder = (uType == "Builder")

			local interval = isBuilder and WORKER_TICK_RATE or COMBAT_TICK_RATE
			unit:SetAttribute("NextThink", now + interval)

			-----------------------------------------------------------------
			-- A) BUILDER AUTO-WORK: BUILD > CHOP > MINE  (tree logic mirrored)
			-----------------------------------------------------------------
			if isBuilder then
				local isBusyAction = (UNIT_ACTION_TRACKS[unit] ~= nil)
				local hasOrders = (UNIT_CMD_QUEUE[unit] and #UNIT_CMD_QUEUE[unit] > 0)
				local isRunning = (QUEUE_RUNNING[unit] == true)

				if not isBusyAction and not hasOrders and not isRunning then
					local root = ensurePrimaryPart(unit)
					if root then
						local myOwnerId = unit:GetAttribute("OwnerUserId")
						local plr = Players:GetPlayerByUserId(myOwnerId)

						if plr then

							-- Builder auto-behavior state (nil defaults to legacy AUTO behavior)
							local autoState = unit:GetAttribute("AutoState")
							if autoState == nil then autoState = "Auto" end

							local maxDist = unit:GetAttribute("AutoMaxDist")
							if typeof(maxDist) ~= "number" then maxDist = 120 end
							maxDist = math.clamp(maxDist, 30, 600)

							local basePos = plr:GetAttribute("RTS_BasePos")
							if typeof(basePos) ~= "Vector3" then
								basePos = root.Position
							end

							local function withinMaxDist(worldPos)
								local p = Vector3.new(worldPos.X, basePos.Y, worldPos.Z)
								return (p - basePos).Magnitude <= maxDist
							end

							-- Idle means: no automatic behavior (manual commands still work)
							if autoState == "Idle" then
								continue
							end


							-------------------------------------------------------
							-- PRIORITY 1: BUILD
							-------------------------------------------------------
							local bestBuild = nil
							local bestBuildDist = 60

							local buildings = CollectionService:GetTagged(BUILDING_TAG)
							for _, b in ipairs(buildings) do
								if b:GetAttribute("OwnerUserId") == myOwnerId and b:GetAttribute("UnderConstruction") then
									local bRoot = b.PrimaryPart or b:FindFirstChildWhichIsA("BasePart")
									if bRoot then
										local dist = (bRoot.Position - root.Position).Magnitude
										if dist < bestBuildDist then
											bestBuildDist = dist
											bestBuild = b
										end
									end
								end
							end

							if bestBuild then
								QUEUE_RUNNING[unit] = true
								task.spawn(function()
									local tile = getHexTileFromWorld(bestBuild:GetPivot().Position)
									executeBuildSequence(plr, unit, bestBuild, tile)
									QUEUE_RUNNING[unit] = false
								end)
								continue
							end


							-------------------------------------------------------
							-- AUTO STATE: WANDER (no harvesting)
							-------------------------------------------------------
							if autoState == "Wander" then
								local hum = unit:FindFirstChildOfClass("Humanoid")
								if hum then
									local nextW = unit:GetAttribute("NextWander") or 0
									if now >= nextW then
										unit:SetAttribute("NextWander", now + 2.5 + math.random() * 2.0)
										local ang = math.random() * math.pi * 2
										local r = math.random(12, math.floor(maxDist))
										local dest = basePos + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)
										hum:MoveTo(Vector3.new(dest.X, root.Position.Y, dest.Z))
										setUnitWalking(unit, true)
									end
								end
								continue
							end

							if autoState == "Auto" or autoState == "Woodchopping" then
								local requireMarked = (autoState == "Auto")
								-------------------------------------------------------
								-- PRIORITY 2: CHOP (Marked Trees)
								-------------------------------------------------------
								local searchRange = math.min(180, maxDist)
								local bestTree = nil
								local bestDist = searchRange

								for _, obj in ipairs(workspace:GetChildren()) do
									if obj:IsA("Model") and not TreeClaims[obj] then
										local markedGlobal = obj:GetAttribute("MarkedForChop")
										local markedPlayer = obj:GetAttribute("MarkedForChop_" .. tostring(myOwnerId))
										if ((not requireMarked) or markedGlobal or markedPlayer) and isValidTreeModel(obj) then
											local tRoot = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
											if tRoot and withinMaxDist(tRoot.Position) then
												local dist = (tRoot.Position - root.Position).Magnitude
												if dist < bestDist then
													bestDist = dist
													bestTree = obj
												end
											end
										end
									end
								end

								for _, obj in ipairs(CollectionService:GetTagged(TREE_TAG)) do
									if obj and obj:IsA("Model") and not TreeClaims[obj] then
										local markedGlobal = obj:GetAttribute("MarkedForChop")
										local markedPlayer = obj:GetAttribute("MarkedForChop_" .. tostring(myOwnerId))
										if ((not requireMarked) or markedGlobal or markedPlayer) and isValidTreeModel(obj) then
											local tRoot = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
											if tRoot and withinMaxDist(tRoot.Position) then
												local dist = (tRoot.Position - root.Position).Magnitude
												if dist < bestDist then
													bestDist = dist
													bestTree = obj
												end
											end
										end
									end
								end

								if bestTree then
									QUEUE_RUNNING[unit] = true
									task.spawn(function()
										executeChopSequence(plr, unit, bestTree)
										QUEUE_RUNNING[unit] = false
									end)
									continue
								end

							end

							if autoState == "Auto" or autoState == "Mining" then
								local requireMarked = (autoState == "Auto")
								-------------------------------------------------------
								-- PRIORITY 3: MINE (Marked Rocks)
								-- Mirrors tree logic, but scans ResourceNodes + tags
								-------------------------------------------------------
								local bestStone = nil
								local bestStoneDist = math.min(180, maxDist)

								local function considerStone(obj)
									if not obj or not obj:IsA("Model") then return end
									if StoneClaims[obj] then return end

									local markedGlobal = obj:GetAttribute("MarkedForMine")
									local markedPlayer = obj:GetAttribute("MarkedForMine_" .. tostring(myOwnerId))

									if ((not requireMarked) or markedGlobal or markedPlayer) and isValidStoneModel(obj) then
										local sRoot = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
										if sRoot and withinMaxDist(sRoot.Position) then
											local dist = (sRoot.Position - root.Position).Magnitude
											if dist < bestStoneDist then
												bestStoneDist = dist
												bestStone = obj
											end
										end
									end
								end

								-- 1) Procedural rock nodes live here
								local resFolder = workspace:FindFirstChild("ResourceNodes")
								if resFolder then
									for _, obj in ipairs(resFolder:GetChildren()) do
										considerStone(obj)
									end
								end

								-- 2) Support manually placed stones at top-level
								for _, obj in ipairs(workspace:GetChildren()) do
									considerStone(obj)
								end

								-- 3) Tagged stones anywhere
								for _, obj in ipairs(CollectionService:GetTagged(STONE_TAG)) do
									considerStone(obj)
								end

								if bestStone then
									QUEUE_RUNNING[unit] = true
									task.spawn(function()
										executeMineStoneSequence(plr, unit, bestStone)
										QUEUE_RUNNING[unit] = false
									end)
								end							end

						end
					end
				end
			end

			-----------------------------------------------------------------
			-- B) COMBAT LOGIC (unchanged)
			-----------------------------------------------------------------
			local stats = UNIT_TYPES[uType]
			if stats and stats.IsCombat and not UNIT_ACTION_TRACKS[unit] then
				-- Respect explicit move commands: if the unit is currently executing a move
				-- order, suppress combat targeting so the unit continues to its destination.
				if QUEUE_RUNNING[unit] then
					unit:SetAttribute("CombatTarget", nil)
					unit:SetAttribute("IsAttacking", false)
					continue
				end

				local hum = unit:FindFirstChildOfClass("Humanoid")
				local root = ensurePrimaryPart(unit)

				if hum and root and hum.Health > 0 then
					local isGarrisoned = unit:GetAttribute("IsGarrisoned")
					local TOWER_RANGED_RANGE_BONUS = 15
					local towerRangeBonus = (isGarrisoned and stats.IsRanged) and TOWER_RANGED_RANGE_BONUS or 0

					local effectiveAggroRange = (stats.AggroRange or 0) + towerRangeBonus
					local effectiveAttackRange = (stats.Range or 0) + towerRangeBonus

					local currentTargetName = unit:GetAttribute("CombatTarget")
					local targetModel = nil
					local isMoving = QUEUE_RUNNING[unit] == true

					if currentTargetName then
						local t = unitsFolder:FindFirstChild(currentTargetName)
						if not t then
							for _, b in ipairs(CollectionService:GetTagged("RTSBuilding")) do
								if b.Name == currentTargetName then t = b; break end
							end
						end

						if t then
							local tHum = t:FindFirstChildOfClass("Humanoid")
							local isDead = (tHum and tHum.Health <= 0) or t:GetAttribute("IsDead")

							if not isDead then
								local tRoot = ensurePrimaryPart(t)
								if tRoot then
									local dist = (tRoot.Position - root.Position).Magnitude
									if dist > effectiveAggroRange * 1.5 then
										unit:SetAttribute("CombatTarget", nil)
									else
										targetModel = t
									end
								end
							else
								unit:SetAttribute("CombatTarget", nil)
							end
						else
							unit:SetAttribute("CombatTarget", nil)
						end
					end

					local scanRange = isMoving and (effectiveAggroRange * 0.8) or effectiveAggroRange

					if stats.IsRanged then
						local nearest = findNearestEnemy(unit, scanRange)

						if nearest then
							if not unit:GetAttribute("IsAttacking") then
								VisualEffect:FireAllClients("CombatAlert", root.Position, "!")
							end

							if isMoving then
								local q = UNIT_CMD_QUEUE[unit]; if q then table.clear(q) end
								QUEUE_RUNNING[unit] = false
								hum:MoveTo(root.Position)
								setUnitWalking(unit, false)
								isMoving = false
							end

							targetModel = nearest
							unit:SetAttribute("CombatTarget", targetModel.Name)
						else
							targetModel = nil
							unit:SetAttribute("CombatTarget", nil)
							if not isMoving then
								setUnitWalking(unit, false)
								unit:SetAttribute("IsAttacking", false)
							end
						end
					else
						if not targetModel then
							targetModel = findNearestEnemy(unit, scanRange)

							if targetModel then
								if not unit:GetAttribute("IsAttacking") then
									VisualEffect:FireAllClients("CombatAlert", root.Position, "!")
								end

								if isMoving then
									local q = UNIT_CMD_QUEUE[unit]; if q then table.clear(q) end
									QUEUE_RUNNING[unit] = false
									hum:MoveTo(root.Position)
									setUnitWalking(unit, false)
								end

								unit:SetAttribute("CombatTarget", targetModel.Name)
							else
								unit:SetAttribute("CombatTarget", nil)
								if not isMoving then
									setUnitWalking(unit, false)
									unit:SetAttribute("IsAttacking", false)
								end
							end
						end
					end

					if targetModel and not QUEUE_RUNNING[unit] then
						local tRoot = ensurePrimaryPart(targetModel)
						if not tRoot then
							unit:SetAttribute("CombatTarget", nil)
							unit:SetAttribute("IsAttacking", false)
						else
							local rawDist = (tRoot.Position - root.Position).Magnitude
							local edgeDist = math.max(0, rawDist - getTargetRadius(targetModel))

							local wasAttacking = unit:GetAttribute("IsAttacking") == true
							local attackRangeBuffer = wasAttacking and (effectiveAttackRange + 1) or effectiveAttackRange

							if isGarrisoned then
								local facePos = Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z)
								local targetCF = CFrame.lookAt(root.Position, facePos)
								root.CFrame = root.CFrame:Lerp(targetCF, 0.2)
							end

							if edgeDist <= attackRangeBuffer then
								unit:SetAttribute("IsAttacking", true)

								if root.AssemblyLinearVelocity.Magnitude > 0.5 then
									hum:MoveTo(root.Position); setUnitWalking(unit, false)
								end

								local lastAtk = unit:GetAttribute("LastAttack") or 0
								if now - lastAtk > stats.AttackSpeed then
									unit:SetAttribute("LastAttack", now)

									if not isGarrisoned then
										local facePos = Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z)
										root.CFrame = CFrame.lookAt(root.Position, facePos)
									end

									if stats.IsRanged then
										local speed = stats.ProjectileSpeed or 60
										local travelTime = rawDist / speed

										VisualEffect:FireAllClients("Projectile", root.Position, {
											Target = tRoot.Position,
											Duration = travelTime,
											Type = "Arrow"
										})
										VisualEffect:FireAllClients("Sound", root.Position, "rbxassetid://609348009")

										task.delay(travelTime, function()
											if unit and targetModel and targetModel.Parent then
												local tHum = targetModel:FindFirstChild("Humanoid")
												if (tHum and tHum.Health > 0) or targetModel:GetAttribute("Health") then
													if tHum then
														tHum:TakeDamage(stats.Damage)
													else
														local hp = targetModel:GetAttribute("Health") or 0
														local newHp = hp - stats.Damage
														targetModel:SetAttribute("Health", newHp)
														if newHp <= 0 then destroyStructure(targetModel) end
													end
													VisualEffect:FireAllClients("DamageNumber", targetModel:GetPivot().Position, "-"..tostring(stats.Damage))
													VisualEffect:FireAllClients("Sound", targetModel:GetPivot().Position, "rbxassetid://609369680")
												end
											end
										end)
									else
										local animId = ATTACK_ANIMS[math.random(1, #ATTACK_ANIMS)]
										local track = getCombatAnim(hum, animId)
										track:Play()
										VisualEffect:FireAllClients("Sound", root.Position, "rbxassetid://6241709963")

										task.delay(0.4, function()
											if unit and hum.Health > 0 and targetModel and targetModel.Parent then
												local tHum = targetModel:FindFirstChildOfClass("Humanoid")
												local tRootNow = targetModel.PrimaryPart
												if not tRootNow then return end

												local currDist = (tRootNow.Position - root.Position).Magnitude
												local currEdge = currDist - getTargetRadius(targetModel)

												if (tHum and tHum.Health > 0) or targetModel:GetAttribute("Health") then
													if currEdge <= (stats.Range or 0) + 3 then
														if tHum then
															tHum:TakeDamage(stats.Damage)
														else
															local hp = targetModel:GetAttribute("Health") or 0
															local newHp = hp - stats.Damage
															targetModel:SetAttribute("Health", newHp)
															if newHp <= 0 then destroyStructure(targetModel) end
														end
														VisualEffect:FireAllClients("DamageNumber", tRootNow.Position, "-"..tostring(stats.Damage))
														VisualEffect:FireAllClients("Sound", tRootNow.Position, "rbxassetid://7171761940")
													end
												end
											end
										end)
									end
								end
							else
								if isGarrisoned then
									unit:SetAttribute("IsAttacking", false)
								else
									unit:SetAttribute("IsAttacking", false)
									setUnitWalking(unit, true)

									local lastPathCalc = unit:GetAttribute("LastPathCalc") or 0
									if now - lastPathCalc > 0.35 then
										unit:SetAttribute("LastPathCalc", now)

										local direction = tRoot.Position - root.Position
										local rayResult = workspace:Raycast(root.Position, direction, sightParams)

										local isBlocked = false
										if rayResult and rayResult.Instance then
											if not rayResult.Instance:IsDescendantOf(targetModel) then
												isBlocked = true
											end
										end

										if not isBlocked then
											hum:MoveTo(tRoot.Position)
											if (tRoot.Position.Y - root.Position.Y) > 2 then hum.Jump = true end
										else
											local path = PathfindingService:CreatePath(PATH_AGENT)
											local success, _ = pcall(function() path:ComputeAsync(root.Position, tRoot.Position) end)

											if success and path.Status == Enum.PathStatus.Success then
												local wps = path:GetWaypoints()
												if #wps >= 2 then
													hum:MoveTo(wps[2].Position)
													if wps[2].Action == Enum.PathWaypointAction.Jump then hum.Jump = true end
												else
													hum:MoveTo(tRoot.Position)
												end
											else
												hum:MoveTo(tRoot.Position)
											end
										end
									end

									local vel = root.AssemblyLinearVelocity * Vector3.new(1,0,1)
									if vel.Magnitude < 0.5 then
										if math.random() < 0.1 then hum.Jump = true end
									end
								end
							end
						end
					end
				end
			end
		end
	end)

	return true
end
