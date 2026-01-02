-- ServerScriptService / RTSUnitServer.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

---------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------
local Remotes = ReplicatedStorage:FindFirstChild("RTSRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "RTSRemotes"
	Remotes.Parent = ReplicatedStorage
end
-- [[ INSERT AT THE VERY TOP OF RTSUnitServer.lua ]]
local PhysicsService = game:GetService("PhysicsService")

local RTS_UNIT_GROUP = "RTSUnitGroup"
local function setupCollisionGroups()
	local success, err = pcall(function()
		-- Create the group
		PhysicsService:RegisterCollisionGroup(RTS_UNIT_GROUP)
		-- Tell the group NOT to collide with itself
		PhysicsService:CollisionGroupSetCollidable(RTS_UNIT_GROUP, RTS_UNIT_GROUP, false)
	end)
end
setupCollisionGroups()

local function getOrCreateRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end

local CommandMove = getOrCreateRemote("CommandMove")
local CommandGarrisonTower = getOrCreateRemote("CommandGarrisonTower")
local CommandChopTree = getOrCreateRemote("CommandChopTree")
local ToggleTreeMark = getOrCreateRemote("ToggleTreeMark")
local PathUpdate  = getOrCreateRemote("PathUpdate")
local SetCameraFocus = getOrCreateRemote("SetCameraFocus")
local CommandCancel = getOrCreateRemote("CommandCancel")
local DeleteUnit = getOrCreateRemote("DeleteUnit")
local UpdateBaseQueue = getOrCreateRemote("UpdateBaseQueue")
local CommandPlaceBuilding = getOrCreateRemote("CommandPlaceBuilding")
local RecruitUnit = getOrCreateRemote("RecruitUnit")
local VisualEffect = getOrCreateRemote("VisualEffect") -- New remote for damage numbers/sounds
local HttpService = game:GetService("HttpService") -- [[ ADDED THIS ]]

---------------------------------------------------------------------
-- [[ NEW: SKIN COLOR PALETTE ]]
---------------------------------------------------------------------
local SKIN_TONES = {
	Color3.fromRGB(255, 224, 189), -- Light
	Color3.fromRGB(255, 205, 148),
	Color3.fromRGB(234, 192, 134),
	Color3.fromRGB(255, 173, 96),
	Color3.fromRGB(224, 172, 105),
	Color3.fromRGB(198, 134, 66),
	Color3.fromRGB(141, 85, 36),   -- Medium Dark
	Color3.fromRGB(117, 65, 33),
	Color3.fromRGB(92, 58, 33),
	Color3.fromRGB(60, 34, 20),    -- Dark
}

local function randomizeSkin(unitModel)
	local skinColor = SKIN_TONES[math.random(1, #SKIN_TONES)]

	local bc = unitModel:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = skinColor
		bc.LeftArmColor3 = skinColor
		bc.RightArmColor3 = skinColor
		bc.LeftLegColor3 = skinColor
		bc.RightLegColor3 = skinColor
		bc.TorsoColor3 = skinColor
	end

	for _, part in ipairs(unitModel:GetChildren()) do
		if part:IsA("BasePart") then
			if part.Name == "Head" or part.Name == "Torso" 
				or string.match(part.Name, "Arm") 
				or string.match(part.Name, "Leg") then
				part.Color = skinColor
			end
		end
	end
end
local CameraReturn = Remotes:FindFirstChild("CameraReturn")
if not CameraReturn then
	CameraReturn = Instance.new("BindableEvent")
	CameraReturn.Name = "CameraReturn"
	CameraReturn.Parent = Remotes
end

---------------------------------------------------------------------
-- RESOURCES
---------------------------------------------------------------------
local function addWood(plr, amount)
	plr:SetAttribute("Wood", (plr:GetAttribute("Wood") or 0) + (amount or 0))
end


local function addStone(plr, amount)
	plr:SetAttribute("Stone", (plr:GetAttribute("Stone") or 0) + (amount or 0))
end

---------------------------------------------------------------------
-- TREE HARVESTING (builders)
---------------------------------------------------------------------
local TREE_TAG = "RTSTree"
local TreeClaims = {} 

local ProductionQueues = {} 
local QueueRunning = {}     

local function isValidTreeModel(treeModel)
	if typeof(treeModel) ~= "Instance" then return false end
	if not treeModel:IsA("Model") then return false end
	if not treeModel:IsDescendantOf(workspace) then return false end
	if treeModel:GetAttribute("IsRTSTree") == true then
		return true
	end
	if CollectionService:HasTag(treeModel, TREE_TAG) then
		return true
	end
	return false
end

local function claimTree(treeModel, unit)
	local current = TreeClaims[treeModel]
	if current and current ~= unit then
		return false
	end
	TreeClaims[treeModel] = unit
	return true
end

local function releaseTree(treeModel, unit)
	if TreeClaims[treeModel] == unit then
		TreeClaims[treeModel] = nil
	end
end

local function clearTreeClaim(treeModel)
	TreeClaims[treeModel] = nil
end


---------------------------------------------------------------------
-- FOLDERS
---------------------------------------------------------------------
local unitsFolder = workspace:FindFirstChild("RTSUnits")
if not unitsFolder then
	unitsFolder = Instance.new("Folder")
	unitsFolder.Name = "RTSUnits"
	unitsFolder.Parent = workspace
end

local linksFolder = workspace:FindFirstChild("RTS_PathLinks")
if not linksFolder then
	linksFolder = Instance.new("Folder")
	linksFolder.Name = "RTS_PathLinks"
	linksFolder.Parent = workspace
end

local basesFolder = workspace:FindFirstChild("RTSBases")
if not basesFolder then
	basesFolder = Instance.new("Folder")
	basesFolder.Name = "RTSBases"
	basesFolder.Parent = workspace
end

---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local UNIT_TAG = "RTSUnit"
local BUILDING_TAG = "RTSBuilding"

-- Tower bonus for ranged units (archers)
local TOWER_RANGED_RANGE_BONUS = 15


local WALK_SPEED = 9
local ARRIVE_RADIUS = 2.0

local TILE_STEP = 1.243
local MAX_STEP_UP = TILE_STEP * 1.15

local PATH_AGENT = {
	AgentRadius = 2.2,
	AgentHeight = 5,
	AgentCanJump = true,
	AgentJumpHeight = MAX_STEP_UP + 0.2, 
	AgentMaxSlope = 35,
	-- [[ UPDATED: Added Wall Cost ]] --
	Costs = { 
		Water = math.huge,
		Wall = math.huge 
	},
}

-- [RTSUnitServer.lua] Update BUILDING_STATS
local BUILDING_STATS = {
	RTSBarracks = {
		Cost = { Gold = 150, Wood = 100 },
		BuildTime = 5,
		MaxHP = 800, -- NEW
		TemplatePath = {"Buildings", "RTSBarracks"}
	},
	House = {
		Cost = { Gold = 50, Wood = 100 },
		BuildTime = 8,
		MaxHP = 400, -- NEW
		TemplatePath = {"Buildings", "House"} 
	},
	Farm = {
		Cost = { Gold = 100, Wood = 150 },
		BuildTime = 10,
		MaxHP = 500, -- NEW
		PopCost = 5,
		TemplatePath = {"Buildings", "Farm"}
	},
	-- [[ NEW: SAWMILL STATS ]] --
	RTSSawmill = {
		Cost = { Gold = 150, Wood = 50 }, -- Costs mostly Gold since it produces Wood
		BuildTime = 10,
		MaxHP = 600,
		PopCost = 5, -- Consumes 5 Pop
		TemplatePath = {"Buildings", "RTSSawmill"}
	},
	Palisade = {
		Cost = { Gold = 20, Wood = 80 }, -- Low cost for spamming
		BuildTime = 5,                   -- Fast build time
		MaxHP = 1500,                    -- High HP for defense
		TemplatePath = {"Buildings", "Palisade"}
	},
	Palisade2 = {
		Cost = { Gold = 40, Wood = 80 }, -- Distinct Cost
		BuildTime = 8,                   -- Takes longer to build
		MaxHP = 2500,                    -- Distinct HP
		TemplatePath = {"Buildings", "Palisade2"} -- Matches your hierarchy
	},
	ArcherTower = {
		Cost = { Gold = 50, Wood = 150 },
		BuildTime = 10,
		MaxHP = 1000,
		TemplatePath = {"Buildings", "ArcherTower"} -- Matches your hierarchy
	}
}

-- [ADD UNDER BUILDING_STATS]
local UNIT_TYPES = {
	Builder = {
		Cost = { Gold = 100, Wood = 50 },
		BuildTime = 5,
		MaxHP = 50,
		IsCombat = false
	},
	WarPeasant = {
		Cost = { Gold = 75, Wood = 25 }, -- Fair early game price
		BuildTime = 4,
		MaxHP = 90,
		Damage = 8,
		AttackSpeed = 1.0,
		Range = 6, 
		AggroRange = 35,
		IsCombat = true
	},
	Archer = {
		Cost = { Gold = 100, Wood = 80 },
		BuildTime = 6,
		MaxHP = 60,        -- Squishier than War Peasant
		Damage = 12,       -- Good damage
		AttackSpeed = 1.8, -- Slower fire rate
		Range = 35,        -- Ranged!
		AggroRange = 45,
		IsCombat = true,
		IsRanged = true,   -- NEW FLAG
		ProjectileSpeed = 70
	}
}
-- [RTSUnitServer.lua] PASTE THIS FUNCTION NEAR THE TOP (After UNIT_TYPES, Before CommandPlaceBuilding)

local function getPlayerPopulation(plr)
	local count = 0
	-- Ensure we have reference to the folder
	local uFolder = workspace:FindFirstChild("RTSUnits") 

	-- 1. Count Units
	if uFolder then
		for _, u in ipairs(uFolder:GetChildren()) do
			if u:IsA("Model") and u:GetAttribute("OwnerUserId") == plr.UserId then
				count = count + 1
			end
		end
	end

	-- 2. Count Active Farms & Sawmills (Each takes 5 Pop)
	for _, b in ipairs(workspace:GetChildren()) do
		if b:IsA("Model") and b:GetAttribute("OwnerUserId") == plr.UserId then
			local bType = b:GetAttribute("BuildingType")
			local isComplete = not b:GetAttribute("UnderConstruction")

			-- Check Farms
			if bType == "Farm" and isComplete then
				count = count + 5
			end
			-- [[ NEW: Check Sawmills ]] --
			if bType == "RTSSawmill" and isComplete then
				count = count + 5
			end
		end
	end

	return count
end

-- Default Attack Animation (R6 Slash)
-- [REPLACE DEFAULT_ATTACK_ANIM WITH THIS TABLE]
local ATTACK_ANIMS = {
	"rbxassetid://99522595035363",
	"rbxassetid://134315501581444",
	"rbxassetid://138535139242491",
	"rbxassetid://100832261779703"
}

local EDGE_JUMP_RADIUS = 2.8   

---------------------------------------------------------------------
-- UNIT TEMPLATE
---------------------------------------------------------------------
local function getUnitTemplate()
	local units = ReplicatedStorage:FindFirstChild("Units")
	if not units then return nil end
	local builder = units:FindFirstChild("Builder")
	if builder and builder:IsA("Model") then
		return builder
	end
	return nil
end

-- [RTSUnitServer.lua] New Helper to handle unit death consistently
local function setupUnitDeath(unit, ownerPlayer)
	local hum = unit:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	hum.Died:Connect(function()
		if unit:GetAttribute("IsDead") then return end
		unit:SetAttribute("IsDead", true)

		-- 1. Remove from Population immediately
		-- We do this by parenting it out of the RTSUnits folder
		unit.Parent = workspace 

		-- 2. Disable Logic
		unit:SetAttribute("OwnerUserId", nil)
		CollectionService:RemoveTag(unit, UNIT_TAG)

		-- 3. Visual Cleanup
		local np = unit:FindFirstChild("RTS_Nameplate")
		if np then np:Destroy() end

		-- 4. Physics Cleanup (Freeze bodies so they don't lag)
		for _, p in ipairs(unit:GetDescendants()) do
			if p:IsA("BasePart") then
				p.CanCollide = false
				p.Anchored = true 
			end
		end

		-- 5. Delete after short delay
		task.delay(1.5, function()
			if unit then unit:Destroy() end
		end)
	end)
end

local function ensurePrimaryPart(model)
	if model.PrimaryPart then return model.PrimaryPart end
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		model.PrimaryPart = hrp
		return hrp
	end
	local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
	if anyPart then
		model.PrimaryPart = anyPart
		return anyPart
	end
	return nil
end



---------------------------------------------------------------------
-- DEFAULT R6 ANIMS (server-side fallback)
---------------------------------------------------------------------
local DEFAULT_R6_IDLE_ANIM_ID = "rbxassetid://180435571"
local DEFAULT_R6_WALK_ANIM_ID = "rbxassetid://180426354"
local DEFAULT_R6_CHOP_ANIM_ID = "rbxassetid://114317758495104"

local UnitAnim = {} 
local UnreachableCache = {}

local function ensureDefaultR6Anims(unitModel)
	local animInst = unitModel:FindFirstChild("Animate")
	if animInst and (animInst:IsA("Script") or animInst:IsA("LocalScript")) then
		animInst.Disabled = true
	end

	local hum = unitModel:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	if UnitAnim[unitModel] then return end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	local idleAnim = Instance.new("Animation")
	idleAnim.AnimationId = DEFAULT_R6_IDLE_ANIM_ID

	local walkAnim = Instance.new("Animation")
	walkAnim.AnimationId = DEFAULT_R6_WALK_ANIM_ID

	local idleTrack = animator:LoadAnimation(idleAnim)
	idleTrack.Priority = Enum.AnimationPriority.Idle
	idleTrack.Looped = true

	local walkTrack = animator:LoadAnimation(walkAnim)
	walkTrack.Priority = Enum.AnimationPriority.Movement
	walkTrack.Looped = true

	idleTrack:Play(0.1)

	local conns = {}

	conns.running = hum.Running:Connect(function(speed)
		if speed > 0.1 then
			if idleTrack.IsPlaying then idleTrack:Stop(0.15) end
			if not walkTrack.IsPlaying then walkTrack:Play(0.1) end
			walkTrack:AdjustSpeed(math.clamp(speed / WALK_SPEED, 0.8, 1.6))
		else
			if walkTrack.IsPlaying then walkTrack:Stop(0.15) end
			if not idleTrack.IsPlaying then idleTrack:Play(0.1) end
		end
	end)

	conns.state = hum.StateChanged:Connect(function(_, newState)
		if newState == Enum.HumanoidStateType.Jumping
			or newState == Enum.HumanoidStateType.Freefall
			or newState == Enum.HumanoidStateType.FallingDown
			or newState == Enum.HumanoidStateType.Climbing
		then
			if walkTrack.IsPlaying then walkTrack:Stop(0.1) end
		end
	end)

	UnitAnim[unitModel] = { idle = idleTrack, walk = walkTrack, conns = conns }
end


local function setUnitWalking(unitModel, walking, speedMul)
	ensureDefaultR6Anims(unitModel)

	local pack = UnitAnim[unitModel]
	if not pack then return end

	speedMul = speedMul or 1

	if walking then
		if pack.idle and pack.idle.IsPlaying then
			pack.idle:Stop(0.12)
		end
		if pack.walk and (not pack.walk.IsPlaying) then
			pack.walk:Play(0.08)
		end
		if pack.walk then
			pack.walk:AdjustSpeed(speedMul)
		end
	else
		if pack.walk and pack.walk.IsPlaying then
			pack.walk:Stop(0.12)
		end
		if pack.idle and (not pack.idle.IsPlaying) then
			pack.idle:Play(0.08)
		end
	end
end

local function playChopAnimation(unitModel)
	local hum = unitModel:FindFirstChildOfClass("Humanoid")
	if not hum then return nil end

	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = hum
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = DEFAULT_R6_CHOP_ANIM_ID

	local track = animator:LoadAnimation(anim)
	track.Priority = Enum.AnimationPriority.Action 
	track.Looped = true
	track:Play()

	return track
end

-- [[ REPLACE YOUR EXISTING prepUnitForWorld FUNCTION WITH THIS ]]
local function prepUnitForWorld(unitModel)
	for _, d in ipairs(unitModel:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			-- [[ FIX 1: Apply Collision Group ]]
			d.CollisionGroup = RTS_UNIT_GROUP
		end
	end

	local root = ensurePrimaryPart(unitModel)
	local hum = unitModel:FindFirstChildOfClass("Humanoid")

	if hum then
		hum.BreakJointsOnDeath = false -- keep body from scattering into parts
		hum.WalkSpeed = 12 -- Slightly faster for responsiveness
		hum.AutoRotate = true

		-- [[ FIX 2: Optimize Physics ]]
		-- Disable expensive states
		hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
		hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

		-- Make unit lighter (mass 1) to prevent physics heavy interactions
		if root then 
			root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.5, 1, 1) 
		end
	end

	ensureDefaultR6Anims(unitModel)
end

local function possessiveName(name)
	local last = string.sub(name, -1)
	if string.lower(last) == "s" then
		return name .. "'"
	end
	return name .. "'s"
end

local function setUnitNameplate(unitModel, ownerName, unitType)
	local old = unitModel:FindFirstChild("RTS_Nameplate")
	if old then old:Destroy() end

	local head = unitModel:FindFirstChild("Head", true)
	local adornee = (head and head:IsA("BasePart")) and head or ensurePrimaryPart(unitModel)
	if not adornee then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RTS_Nameplate"
	bb.Adornee = adornee
	bb.AlwaysOnTop = true

	bb.Size = UDim2.fromOffset(120, 18)    
	bb.StudsOffset = Vector3.new(0, 3.2, 0) 
	bb.MaxDistance = 55 

	bb.Parent = unitModel

	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)

	tl.TextScaled = false
	tl.TextSize = 10 
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.35
	tl.Text = ("%s %s"):format(possessiveName(ownerName), unitType)
	tl.Parent = bb
end


---------------------------------------------------------------------
-- TILE COLLECTION 
---------------------------------------------------------------------
local TileIncludeList = { workspace.Terrain } 
local TileSetReady = false

local function refreshTileIncludeList()
	TileIncludeList = { workspace.Terrain }
	for _, inst in ipairs(workspace:GetChildren()) do
		if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
			table.insert(TileIncludeList, inst)
		end
	end
	TileSetReady = (#TileIncludeList > 1)
end

local function rayToGround(pos)
	if not TileSetReady then
		refreshTileIncludeList()
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = TileIncludeList
	params.IgnoreWater = true

	local origin = pos + Vector3.new(0, 250, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), params)
	if result then
		return result.Position
	end
	return pos
end

local function getHexTileFromWorld(pos)
	if not TileSetReady then
		refreshTileIncludeList()
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = TileIncludeList
	params.IgnoreWater = true

	local origin = pos + Vector3.new(0, 250, 0)
	local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), params)
	if not result then return nil end

	local inst = result.Instance
	while inst do
		if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
			return inst
		end
		inst = inst.Parent
	end
	return nil
end

local function getTileTruePosition(tileModel)
	if not tileModel then return Vector3.zero end

	local bestPart = nil
	local maxArea = 0

	for _, part in ipairs(tileModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local area = part.Size.X * part.Size.Z
			if area > maxArea then
				maxArea = area
				bestPart = part
			end
		end
	end

	if bestPart then
		return Vector3.new(bestPart.Position.X, tileModel:GetPivot().Position.Y, bestPart.Position.Z)
	end

	return tileModel:GetPivot().Position
end

local function isForbiddenDestinationTile(tile)
	if not tile then return false end
	if tile:GetAttribute("IsWater") == true then
		return true
	end
	if tile:GetAttribute("IsWalkable") ~= true then
		return true
	end
	return false
end

local function snapCommandToTileCenter(worldPos)
	local tile = getHexTileFromWorld(worldPos)
	if tile then
		if isForbiddenDestinationTile(tile) then
			return nil
		end
		return tile:GetPivot().Position
	end
	return worldPos
end

---------------------------------------------------------------------
-- BASE SYSTEM
---------------------------------------------------------------------
local BASE_TEMPLATE_PATH = {"RTSBases", "HexTilePlayerBase"}

local BASE_MIN_DISTANCE = 140        
local WATER_AVOID_RADIUS = 110       

local PlayerBaseModel = {}           
local TakenBasePositions = {}        

local function getBaseTemplate()
	local folder = ReplicatedStorage:FindFirstChild(BASE_TEMPLATE_PATH[1])
	if not folder then return nil end
	local m = folder:FindFirstChild(BASE_TEMPLATE_PATH[2])
	if m and m:IsA("Model") then
		return m
	end
	return nil
end

local function setFlagToPlayerAvatar(baseModel, userId)
	local ok, thumb = pcall(function()
		return Players:GetUserThumbnailAsync(
			userId,
			Enum.ThumbnailType.HeadShot,
			Enum.ThumbnailSize.Size420x420
		)
	end)
	if not ok or not thumb then return end

	for _, d in ipairs(baseModel:GetDescendants()) do
		if d:IsA("Decal") then
			d.Texture = thumb
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			d.Image = thumb
		end
	end
end

local function getAllHexTiles()
	local tiles = {}
	for _, inst in ipairs(workspace:GetChildren()) do
		if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
			table.insert(tiles, inst)
		end
	end
	return tiles
end

local function isWaterTile(tileModel)
	return tileModel:GetAttribute("IsWater") == true
end

local function isWalkableTile(tileModel)
	return tileModel:GetAttribute("IsWalkable") == true
end

local function tooClose(posA, posB, dist)
	local a = Vector3.new(posA.X, 0, posA.Z)
	local b = Vector3.new(posB.X, 0, posB.Z)
	return (a - b).Magnitude < dist
end

local function pickValidBaseTile()
	local tiles = getAllHexTiles()

	local candidates = {}
	local waterPositions = {}

	for _, t in ipairs(tiles) do
		local p = t:GetPivot().Position

		if isWaterTile(t) then
			table.insert(waterPositions, p)
		elseif isWalkableTile(t) then
			if t:GetAttribute("HasTree") ~= true then
				table.insert(candidates, t)
			end
		end
	end

	if #candidates == 0 then return nil end

	for _ = 1, 200 do
		local t = candidates[math.random(1, #candidates)]
		local p = t:GetPivot().Position

		local bad = false
		for _, used in ipairs(TakenBasePositions) do
			if tooClose(p, used, BASE_MIN_DISTANCE) then
				bad = true
				break
			end
		end
		if bad then
			continue
		end

		for _, wpos in ipairs(waterPositions) do
			if tooClose(p, wpos, WATER_AVOID_RADIUS) then
				bad = true
				break
			end
		end
		if bad then
			continue
		end

		return t
	end

	return candidates[1]
end

local function getModelBottomY(model)
	local minY = math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local y = d.Position.Y - (d.Size.Y * 0.5)
			if y < minY then
				minY = y
			end
		end
	end
	return minY
end

local BASE_NAMEPLATE_MAX_DISTANCE = 65
local BASE_NAMEPLATE_OFFSET_Y = 10

local function setBaseOwnerNameplate(baseModel, ownerPlayer)
	local old = baseModel:FindFirstChild("RTS_BaseNameplate")
	if old then old:Destroy() end

	local adornee = baseModel:FindFirstChild("HexTileBase", true)
	if not (adornee and adornee:IsA("BasePart")) then
		adornee = baseModel:FindFirstChildWhichIsA("BasePart", true)
	end
	if not adornee then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RTS_BaseNameplate"
	bb.Adornee = adornee
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(260, 50)
	bb.StudsOffset = Vector3.new(0, BASE_NAMEPLATE_OFFSET_Y, 0)
	bb.MaxDistance = BASE_NAMEPLATE_MAX_DISTANCE 
	bb.Parent = baseModel

	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.35
	tl.Text = ownerPlayer.Name .. "'s Village"
	tl.Parent = bb
end

local function spawnPlayerBase(plr)
	local template = getBaseTemplate()
	if not template then
		warn("RTSUnitServer: Missing base template ReplicatedStorage/RTSBases/HexTilePlayerBase")
		return nil
	end

	local baseTile = pickValidBaseTile()
	if not baseTile then
		warn("RTSUnitServer: Could not find a valid base tile.")
		return nil
	end

	local tileBasePart = baseTile:FindFirstChild("HexTileBase", true)
	local tileCF = tileBasePart and tileBasePart.CFrame or baseTile:GetPivot()
	local tileName = baseTile.Name
	local tileAttrs = baseTile:GetAttributes()

	local p = tileCF.Position
	local _, yaw, _ = tileCF:ToOrientation()

	local basePos = p
	table.insert(TakenBasePositions, basePos)

	baseTile:Destroy()

	local base = template:Clone()
	base.Name = tileName
	base.Parent = workspace

	for _, obj in ipairs(base:GetDescendants()) do
		if obj:IsA("BasePart") then
			obj.Anchored = true
		end
	end

	local desiredTileCF = CFrame.new(p) * CFrame.Angles(0, yaw, 0)

	do
		local hexPart = base:FindFirstChild("HexTileBase", true)
		if hexPart and hexPart:IsA("BasePart") then
			local pivotCF = base:GetPivot()
			local partRel = pivotCF:ToObjectSpace(hexPart.CFrame)
			local desiredPivot = desiredTileCF * partRel:Inverse()
			base:PivotTo(desiredPivot)
		else
			base:PivotTo(desiredTileCF)
		end
	end

	for k, v in pairs(tileAttrs) do
		base:SetAttribute(k, v)
	end

	base:SetAttribute("BaseOwnerUserId", plr.UserId)

	setFlagToPlayerAvatar(base, plr.UserId)
	setBaseOwnerNameplate(base, plr)

	plr:SetAttribute("RTS_BasePos", basePos)
	PlayerBaseModel[plr.UserId] = base

	SetCameraFocus:FireClient(plr, basePos)

	refreshTileIncludeList()

	return basePos
end


---------------------------------------------------------------------
-- SPAWN TEST UNITS
---------------------------------------------------------------------
local STARTING_BUILDERS = 2
local BUILDER_SPAWN_RADIUS = 8

---------------------------------------------------------------------
-- SPAWN INITIAL (1 BASE + 1 BUILDER)
---------------------------------------------------------------------
local function spawnInitialForPlayer(plr)
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

local STARTING_GOLD = 200
local GOLD_TICK_SECONDS = 1
local GOLD_TICK_AMOUNT  = 1

local function initGold(plr)
	if plr:GetAttribute("Gold") == nil then
		plr:SetAttribute("Gold", STARTING_GOLD)
	end
end

local function addGold(plr, amount)
	local cur = plr:GetAttribute("Gold") or 0
	plr:SetAttribute("Gold", math.max(0, cur + amount))
end

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

local function parseHexName(name)
	local q, r = string.match(name, "^Hex_(-?%d+)_(-?%d+)$")
	if not q then return nil end
	return tonumber(q), tonumber(r)
end

local function hexKey(q, r)
	return tostring(q) .. "_" .. tostring(r)
end

local function getTileLevel(tileModel)
	local y = tileModel:GetPivot().Position.Y
	return math.floor((y / TILE_STEP) + 0.5)
end

local function clearLinks()
	linksFolder:ClearAllChildren()
end

local function buildStepLinks()
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

local function processUnitQueue(plr, unit)
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

local function enqueueMove(plr, unit, targetPos, slotIndex, totalUnits, addToQueue, faceYaw)
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


local function formationOffset(index, total)
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

local function isWaypointPathValid(fromPos, waypoints)
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

local function computeWaypoints(fromPos, toPos)
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



local function waitArrive(hum, root, goalPos, timeout, arriveRadius)
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


local function watchEdgeJump(unit, hum, root, edgeMidXZ, moveId)
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

local TWO_PI = math.pi * 2

local function lerpAngle(a, b, t)
	local diff = (b - a) % TWO_PI
	if diff > math.pi then
		diff -= TWO_PI
	end
	return a + diff * t
end

local function smoothFaceYaw(unit, hum, root, targetYaw, duration, moveId)
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

---------------------------------------------------------------------
-- COMMAND MOVE
---------------------------------------------------------------------
local function buildIdMapForPlayer(plr)
	local map = {}
	for _, m in ipairs(unitsFolder:GetChildren()) do
		if m:IsA("Model") and CollectionService:HasTag(m, UNIT_TAG) and m:GetAttribute("OwnerUserId") == plr.UserId then
			local id = m:GetAttribute("UnitId")
			if id then
				map[id] = m
			end
		end
	end
	return map
end

---------------------------------------------------------------------
-- HELPER: Finalize Construction (UPDATED POPULATION LOGIC)
---------------------------------------------------------------------
local function finalizeConstruction(buildingModel)
	if not buildingModel or not buildingModel.Parent then return end
	if not buildingModel:GetAttribute("UnderConstruction") then return end

	-- 1. Mark as done immediately
	buildingModel:SetAttribute("UnderConstruction", nil)

	-- [[ NEW: UPDATE PLAYER MAX POPULATION HERE ]] --
	local ownerId = buildingModel:GetAttribute("OwnerUserId")
	local bType = buildingModel:GetAttribute("BuildingType")

	if ownerId and bType == "House" then
		local plr = Players:GetPlayerByUserId(ownerId)
		if plr then
			local curMax = plr:GetAttribute("MaxPopulation") or 10
			plr:SetAttribute("MaxPopulation", curMax + 5)
			print("House Built! Max Population Increased to:", curMax + 5)
		end
	end
	-- [[ END NEW LOGIC ]] --

	-- 2. Destroy the tile underneath (Raycast to find it reliably)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { buildingModel, unitsFolder } 

	local origin = buildingModel:GetPivot().Position + Vector3.new(0, 5, 0)
	local res = workspace:Raycast(origin, Vector3.new(0, -20, 0), params)

	if res and res.Instance then
		local tile = res.Instance:FindFirstAncestorOfClass("Model")
		if tile and string.match(tile.Name, "^Hex") and tile ~= buildingModel then
			tile:Destroy()
		end
	end

	-- 3. Visual Cleanup
	local hl = buildingModel:FindFirstChild("ConstructionHighlight")
	if hl then hl:Destroy() end

	for _, part in ipairs(buildingModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 0 
		end
	end

	refreshTileIncludeList() 
end
---------------------------------------------------------------------
-- BUILDING CONSTRUCTION SYSTEM
---------------------------------------------------------------------
local function executeBuildSequence(plr, unit, buildingModel)
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

-- Helper to count how many of a specific building a player owns
local function getBuildingCount(plr, bType)
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
			warn("RTS: Not enough population capacity to build " .. buildingName)
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

local function getFreeStandPoint(towerModel)
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

local function ungarrisonUnit(unit)
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

-- If an ArcherTower is destroyed while it has garrisoned archers, kill the archers inside.
local TOWER_DEATH_BINDS = {} -- local cache for tower death connections
local function bindTowerDeathKillsGarrison(towerModel)
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

local function garrisonUnitInTower(unit, towerModel)
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
-- [RTSUnitServer.lua] ADD THIS HELPER FUNCTION
local function getTargetRadius(model)
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

local function getApproachPosNearBuilding(buildingModel, fromPos)
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



local function tweenModelPivot(model, goalCFrame, duration)
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

local function getBestTreeRootPart(treeModel)
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

local function fallTree(treeModel, chopperModel)
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

local function executeChopSequence(plr, unit, treeModel)
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
	end
end)

-- [[ NEW: DELETE OWNED UNIT (Roster GUI) ]]
local function findUnitById(unitId)
	if typeof(unitId) ~= "string" then return nil end
	for _, u in ipairs(unitsFolder:GetChildren()) do
		if u:IsA("Model") and u:GetAttribute("UnitId") == unitId then
			return u
		end
	end
	return nil
end

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

-- [[ NEW: RECRUITMENT SYSTEM (Safe Spawn) ]]

local UNIT_COST_GOLD = 100
local UNIT_COST_WOOD = 50
local RECRUIT_TIME = 5


local function processQueue(plr)
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
	if (currentPop + #queue) >= maxPop then return end 

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
-- OPTIMIZED UNIT MANAGER (Centralized Heartbeat)
---------------------------------------------------------------------

-- [[ 1. LOGIC HELPERS ]] --
local UnreachableCache = {}
local CombatAnimCache = {} 

local function markUnreachable(unit, targetModel)
	if not UnreachableCache[unit] then UnreachableCache[unit] = {} end
	UnreachableCache[unit][targetModel] = os.clock() + 3.0
end

local function isUnreachable(unit, targetModel)
	if not UnreachableCache[unit] then return false end
	local expire = UnreachableCache[unit][targetModel]
	if expire and os.clock() < expire then
		return true
	end
	if expire then UnreachableCache[unit][targetModel] = nil end
	return false
end

-- [RTSUnitServer.lua] Update the destroyStructure function
local function destroyStructure(building)
	if building:GetAttribute("IsDead") then return end
	building:SetAttribute("IsDead", true)

	-- [[ NEW: Reduce Max Population if it was a House ]]
	local ownerId = building:GetAttribute("OwnerUserId")
	local bType = building:GetAttribute("BuildingType")
	if ownerId and bType == "House" then
		local plr = Players:GetPlayerByUserId(ownerId)
		if plr then
			local cur = plr:GetAttribute("MaxPopulation") or 10
			-- Remove the 5 pop this house provided
			plr:SetAttribute("MaxPopulation", math.max(0, cur - 5))
		end
	end


	-- [[ FIX: If an ArcherTower dies, force garrisoned units to unanchor + die ]]
	if bType == "ArcherTower" then
		local towerId = building:GetAttribute("BuildingId")
		if towerId then
			for _, unit in ipairs(unitsFolder:GetChildren()) do
				if unit:IsA("Model")
					and unit:GetAttribute("IsGarrisoned") == true
					and unit:GetAttribute("GarrisonTowerId") == towerId then

					-- Clear slot on this tower (prevents future "full" bug)
					local slotIndex = unit:GetAttribute("GarrisonSlot")
					if slotIndex then
						building:SetAttribute("Slot_"..slotIndex.."_Occupied", nil)
					end

					-- Clear garrison state so they don't remain frozen/anchored
					unit:SetAttribute("IsGarrisoned", false)
					unit:SetAttribute("GarrisonSlot", nil)
					unit:SetAttribute("GarrisonTowerId", nil)

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
		end
	end

	-- Disable Logic
	CollectionService:RemoveTag(building, BUILDING_TAG)
	building:SetAttribute("OwnerUserId", nil) 

	-- Visual Collapse
	local tilePart = building:FindFirstChild("Tile") or building:FindFirstChild("HexTileBase") or building.PrimaryPart

	for _, p in ipairs(building:GetDescendants()) do
		if p:IsA("BasePart") and p ~= tilePart then
			p.Anchored = false
			p.CanCollide = false 
			p.AssemblyLinearVelocity = Vector3.new(math.random()-0.5, math.random(), math.random()-0.5) * 15
		end
	end

	-- Cleanup
	task.delay(4, function()
		if not building or not building.Parent then return end
		-- Delete debris
		for _, p in ipairs(building:GetDescendants()) do
			if p:IsA("BasePart") and p ~= tilePart then p:Destroy() end
		end
		-- Keep the base tile as "Ruins"
		if tilePart then
			tilePart.Anchored = true
			tilePart.CanCollide = true
			building.Name = "Ruins_" .. building.Name 
		end
		-- Ensure attributes are gone so Client stops rendering HP/Fire
		building:SetAttribute("Health", nil)
		building:SetAttribute("MaxHP", nil)
	end)
end

-- [RTSUnitServer.lua] REPLACE findNearestEnemy
local function findNearestEnemy(unit, range)
	local myOwner = unit:GetAttribute("OwnerUserId")
	local root = ensurePrimaryPart(unit)
	if not root then return nil end

	local bestTarget = nil
	local minDst = range

	-- Helper to check distance
	local function check(target)
		local tRoot = ensurePrimaryPart(target)
		if tRoot then
			local rawDist = (tRoot.Position - root.Position).Magnitude
			local edgeDist = rawDist - getTargetRadius(target) -- SUBTRACT RADIUS

			if edgeDist < minDst then
				minDst = edgeDist
				return true
			end
		end
		return false
	end

	-- 1. Check Units
	for _, other in ipairs(unitsFolder:GetChildren()) do
		if other:IsA("Model") and other ~= unit then
			local otherOwner = other:GetAttribute("OwnerUserId")
			-- FIX: Removed "and otherOwner ~= -1" so we can attack enemies
			if otherOwner and otherOwner ~= myOwner then
				if isUnreachable(unit, other) then continue end
				local oHum = other:FindFirstChildOfClass("Humanoid")
				if oHum and oHum.Health > 0 then
					if check(other) then bestTarget = other end
				end
			end
		end
	end

	-- 2. Check Buildings
	local buildings = CollectionService:GetTagged(BUILDING_TAG)
	for _, b in ipairs(buildings) do
		local bOwner = b:GetAttribute("OwnerUserId")
		-- FIX: Removed "and bOwner ~= -1"
		if bOwner and bOwner ~= myOwner and not b:GetAttribute("IsDead") and not b:GetAttribute("UnderConstruction") then
			if check(b) then bestTarget = b end
		end
	end

	return bestTarget
end

local function getCombatAnim(hum, animId)
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

-- cleanup caches on removal
unitsFolder.ChildRemoved:Connect(function(child)
	local hum = child:FindFirstChildOfClass("Humanoid")
	if hum and CombatAnimCache[hum] then CombatAnimCache[hum] = nil end
	if UnreachableCache[child] then UnreachableCache[child] = nil end
end)


-- [[ 2. MAIN LOGIC LOOP ]] --

-- Settings for "Staggered" Updates
local COMBAT_TICK_RATE = 0.2  -- Combat units think every 0.2s
local WORKER_TICK_RATE = 0.6  -- Builders look for work every 0.6s

-- We use Heartbeat to run ONE high-performance loop for everyone
-- [RTSUnitServer.lua] REPLACE THE ENTIRE RunService.Heartbeat BLOCK

-- Optimization: Reusable Raycast Params (Create this ONCE outside the loop)
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
-- We ignore units so they don't block "vision" (prevents getting stuck behind friends)
sightParams.FilterDescendantsInstances = { workspace:FindFirstChild("RTSUnits") } 

-- [RTSUnitServer.lua] REPLACE THE ENTIRE RunService.Heartbeat BLOCK

-- Optimization: Reusable Raycast Params
local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude
sightParams.FilterDescendantsInstances = { workspace:FindFirstChild("RTSUnits") } 

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()

	for _, unit in ipairs(unitsFolder:GetChildren()) do
		if not unit:IsA("Model") then continue end
		if unit:GetAttribute("IsDead") then continue end

		-- Initialize Random Offset
		if not unit:GetAttribute("NextThink") then
			unit:SetAttribute("NextThink", now + math.random() * 0.5)
			continue
		end

		if now < unit:GetAttribute("NextThink") then continue end

		-----------------------------------------------------------------
		-- UNIT LOGIC EXECUTION
		-----------------------------------------------------------------
		local uType = unit:GetAttribute("UnitType")
		local isBuilder = (uType == "Builder")

		local interval = isBuilder and WORKER_TICK_RATE or COMBAT_TICK_RATE
		unit:SetAttribute("NextThink", now + interval)

		-- [[ A. BUILDER LOGIC (AUTO-CHOP) ]] --
		-- [[ A. BUILDER LOGIC (AUTO-CHOP) ]] --
		-- [[ A. BUILDER LOGIC (AUTO-WORK: BUILD > CHOP) ]] --
		if isBuilder then
			-- 1. Check if strictly busy (Chopping OR Moving OR Has Pending Commands)
			local isChopping = (UNIT_ACTION_TRACKS[unit] ~= nil)
			local hasOrders  = (UNIT_CMD_QUEUE[unit] and #UNIT_CMD_QUEUE[unit] > 0)
			local isRunning  = (QUEUE_RUNNING[unit] == true)

			-- Only look for work if completely idle
			if not isChopping and not hasOrders and not isRunning then

				local root = ensurePrimaryPart(unit)
				if root then
					local myOwnerId = unit:GetAttribute("OwnerUserId")
					local plr = Players:GetPlayerByUserId(myOwnerId)

					if plr then
						-------------------------------------------------------
						-- PRIORITY 1: FIND NEARBY CONSTRUCTION
						-------------------------------------------------------
						local bestBuild = nil
						local bestBuildDist = 60 -- Range to auto-detect buildings

						-- Use CollectionService for efficiency (defined as "RTSBuilding" at top of script)
						local buildings = CollectionService:GetTagged(BUILDING_TAG)

						for _, b in ipairs(buildings) do
							-- Check ownership and if it needs work
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
							-- FOUND BUILDING: Start work immediately
							QUEUE_RUNNING[unit] = true

							task.spawn(function()
								-- We need the tile to destroy it when done (standard executeBuildSequence arg)
								local tile = getHexTileFromWorld(bestBuild:GetPivot().Position)

								executeBuildSequence(plr, unit, bestBuild, tile)

								-- Release unit when finished
								QUEUE_RUNNING[unit] = false
							end)

							-- Skip the tree check below since we found a building
							continue 
						end

						-------------------------------------------------------
						-- PRIORITY 2: FIND MARKED TREES (Auto-Chop)
						-------------------------------------------------------
						local searchRange = 50
						local bestTree = nil
						local bestDist = searchRange

						for _, obj in ipairs(workspace:GetChildren()) do
							if obj:IsA("Model") and not TreeClaims[obj] then
								local markedGlobal = obj:GetAttribute("MarkedForChop")
								local markedPlayer = obj:GetAttribute("MarkedForChop_"..tostring(myOwnerId))

								if (markedGlobal or markedPlayer) and isValidTreeModel(obj) then
									local tRoot = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
									if tRoot then
										local dist = (tRoot.Position - root.Position).Magnitude
										if dist < bestDist then
											bestDist = dist
											bestTree = obj
										end
									end
								end
							end
						end

						-- Also check tagged trees (supports trees inside folders / not direct Workspace children)
						for _, obj in ipairs(CollectionService:GetTagged(TREE_TAG)) do
							if obj and obj:IsA("Model") and not TreeClaims[obj] then
								local markedGlobal = obj:GetAttribute("MarkedForChop")
								local markedPlayer = obj:GetAttribute("MarkedForChop_"..tostring(myOwnerId))

								if (markedGlobal or markedPlayer) and isValidTreeModel(obj) then
									local tRoot = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
									if tRoot then
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
							-- FOUND TREE: Start chopping
							QUEUE_RUNNING[unit] = true 

							task.spawn(function()
								executeChopSequence(plr, unit, bestTree)
								QUEUE_RUNNING[unit] = false 
							end)
						end
					end
				end
			end
		end

		-- [[ B. COMBAT LOGIC ]]
		local stats = UNIT_TYPES[uType]
		if stats and stats.IsCombat and not UNIT_ACTION_TRACKS[unit] then
			local hum = unit:FindFirstChildOfClass("Humanoid")
			local root = ensurePrimaryPart(unit)

			if hum and root and hum.Health > 0 then

				-- [[ CHECK GARRISON STATE ]]
				local isGarrisoned = unit:GetAttribute("IsGarrisoned")

				-- Tower bonus (only for ranged units like archers)
				local TOWER_RANGED_RANGE_BONUS = 15
				local towerRangeBonus = (isGarrisoned and stats.IsRanged) and TOWER_RANGED_RANGE_BONUS or 0

				local effectiveAggroRange = (stats.AggroRange or 0) + towerRangeBonus
				local effectiveAttackRange = (stats.Range or 0) + towerRangeBonus

				local currentTargetName = unit:GetAttribute("CombatTarget")
				local targetModel = nil
				local isMoving = QUEUE_RUNNING[unit] == true

				-- 1. Sticky Targeting (mainly useful for melee; ranged will override with closest targeting below)
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

				-- 2. Targeting / Auto-Acquire
				local scanRange = isMoving and (effectiveAggroRange * 0.8) or effectiveAggroRange

				if stats.IsRanged then
					-- [[ RANGED: ALWAYS AIM FOR CLOSEST TARGET ]]
					local nearest = findNearestEnemy(unit, scanRange)

					if nearest then
						-- If we weren't attacking before, show alert once
						if not unit:GetAttribute("IsAttacking") then
							VisualEffect:FireAllClients("CombatAlert", root.Position, "!")
						end

						-- If moving, cancel movement to fight immediately
						if isMoving then
							local q = UNIT_CMD_QUEUE[unit]; if q then table.clear(q) end
							QUEUE_RUNNING[unit] = false
							hum:MoveTo(root.Position)
							setUnitWalking(unit, false)
							isMoving = false
						end

						-- Retarget instantly to closest
						targetModel = nearest
						unit:SetAttribute("CombatTarget", targetModel.Name)
					else
						-- No enemies nearby
						targetModel = nil
						unit:SetAttribute("CombatTarget", nil)
						if not isMoving then
							setUnitWalking(unit, false)
							unit:SetAttribute("IsAttacking", false)
						end
					end
				else
					-- [[ NON-RANGED: Keep original "only acquire if no target" behavior ]]
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

				-- 3. Attack Execution
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

						-- [[ MANUAL ROTATION FOR GARRISONED UNITS ]]
						if isGarrisoned then
							local facePos = Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z)
							local targetCF = CFrame.lookAt(root.Position, facePos)
							root.CFrame = root.CFrame:Lerp(targetCF, 0.2)
						end

						if edgeDist <= attackRangeBuffer then
							-- [[ ATTACKING ]]
							unit:SetAttribute("IsAttacking", true)

							if root.AssemblyLinearVelocity.Magnitude > 0.5 then
								hum:MoveTo(root.Position); setUnitWalking(unit, false)
							end

							local lastAtk = unit:GetAttribute("LastAttack") or 0
							if now - lastAtk > stats.AttackSpeed then
								unit:SetAttribute("LastAttack", now)

								-- Face Target (Only needed if not garrisoned or to snap alignment)
								if not isGarrisoned then
									local facePos = Vector3.new(tRoot.Position.X, root.Position.Y, tRoot.Position.Z)
									root.CFrame = CFrame.lookAt(root.Position, facePos)
								end

								if stats.IsRanged then
									-- [[ RANGED ]]
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
									-- [[ MELEE ]]
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
							-- [[ PURSUING ]]
							-- If garrisoned, DO NOT MOVE.
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