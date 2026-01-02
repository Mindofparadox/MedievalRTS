-- ServerScriptService / RTSAdminServer.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local OWNER_ID = 1962138076 -- REPLACE THIS WITH YOUR USER ID
local ADMIN_REMOTE_NAME = "RTSAdminAction"

local Remotes = ReplicatedStorage:FindFirstChild("RTSRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "RTSRemotes"
	Remotes.Parent = ReplicatedStorage
end

local AdminRemote = Remotes:FindFirstChild(ADMIN_REMOTE_NAME)
if not AdminRemote then
	AdminRemote = Instance.new("RemoteEvent")
	AdminRemote.Name = ADMIN_REMOTE_NAME
	AdminRemote.Parent = Remotes
end

local function spawnUnit(plr, unitType, pos, ownerIdOverride)
	local unitsFolder = workspace:FindFirstChild("RTSUnits")
	local template = ReplicatedStorage:WaitForChild("Units"):FindFirstChild(unitType)

	if template and unitsFolder then
		local unit = template:Clone()
		local n = math.random(1000, 99999)

		-- Setup Identity
		unit.Name = unitType .. "_" .. n
		unit.Parent = unitsFolder

		-- Check for Enemy Status (ID -1)
		local finalOwner = ownerIdOverride or plr.UserId
		local isEnemy = (finalOwner == -1)

		unit:SetAttribute("OwnerUserId", finalOwner)
		unit:SetAttribute("UnitId", tostring(finalOwner) .. "_" .. n)
		unit:SetAttribute("UnitType", unitType)

		CollectionService:AddTag(unit, "RTSUnit")

		-- Spawn
		unit:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))

		-- Setup Admin Nameplate
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(120, 20)
		bb.StudsOffset = Vector3.new(0, 3.5, 0)
		bb.AlwaysOnTop = true
		bb.Parent = unit

		local t = Instance.new("TextLabel", bb)
		t.Size = UDim2.fromScale(1,1)
		t.BackgroundTransparency = 1
		t.TextStrokeTransparency = 0
		t.Font = Enum.Font.GothamBlack

		if isEnemy then
			t.Text = "ENEMY UNIT"
			t.TextColor3 = Color3.fromRGB(255, 50, 50) -- Red
		else
			t.Text = "ADMIN SPAWN"
			t.TextColor3 = Color3.fromRGB(255, 100, 255) -- Purple
		end
	end
end

local function paintTile(targetTileModel, newTileName)
	if not targetTileModel or not targetTileModel.Parent then return end
	local tileFolder = ReplicatedStorage:FindFirstChild("HexTiles")
	local template = tileFolder and tileFolder:FindFirstChild(newTileName)
	if not template then return end

	local oldCF = targetTileModel:GetPivot()
	local oldName = targetTileModel.Name
	local parent = targetTileModel.Parent

	targetTileModel:Destroy()

	local newTile = template:Clone()
	newTile.Name = oldName
	newTile.Parent = parent
	newTile:PivotTo(oldCF)

	newTile:SetAttribute("IsWater", newTileName == "WaterTile")
	newTile:SetAttribute("IsWalkable", newTileName ~= "WaterTile")
	newTile:SetAttribute("TileKind", newTileName)

	for _, p in ipairs(newTile:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end
end


-- [[ Admin building HP (keeps admin-spawned buildings compatible with the main building/health system) ]]
local ADMIN_BUILDING_HP = {
	RTSBarracks = 800,
	House = 400,
	Farm = 500,
	RTSSawmill = 600,
	Palisade = 1500,
	Palisade2 = 2500,
	ArcherTower = 1000,
}

-- Helpers for admin building placement (match RTSUnitServer placement rules)
local function getHexModelFromWorld(pos)
	local unitsFolder = workspace:FindFirstChild("RTSUnits")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = unitsFolder and { unitsFolder } or {}
	params.IgnoreWater = true

	local origin = pos + Vector3.new(0, 250, 0)
	local res = workspace:Raycast(origin, Vector3.new(0, -900, 0), params)
	if not res then return nil end

	local inst = res.Instance
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
	if not tile then return true end
	if tile:GetAttribute("IsWater") == true then
		return true
	end
	if tile:GetAttribute("IsWalkable") ~= true then
		return true
	end
	return false
end

local function finalizeAdminConstruction(plr, buildingModel)
	-- Mark complete (matches RTSUnitServer: UnderConstruction == nil means complete)
	buildingModel:SetAttribute("UnderConstruction", nil)
	buildingModel:SetAttribute("ConstructionProgress", nil)
	buildingModel:SetAttribute("ConstructionMax", nil)

	-- House pop cap bonus (matches RTSUnitServer finalizeConstruction)
	if buildingModel:GetAttribute("BuildingType") == "House" then
		local curMax = plr:GetAttribute("MaxPopulation") or 10
		plr:SetAttribute("MaxPopulation", curMax + 5)
	end

	-- Destroy the underlying tile so raycasts hit the building model named "Hex_x_y"
	local unitsFolder = workspace:FindFirstChild("RTSUnits")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { buildingModel }
	if unitsFolder then table.insert(exclude, unitsFolder) end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true

	local origin = buildingModel:GetPivot().Position + Vector3.new(0, 5, 0)
	local res = workspace:Raycast(origin, Vector3.new(0, -40, 0), params)

	if res and res.Instance then
		local tile = res.Instance:FindFirstAncestorOfClass("Model")
		if tile and string.match(tile.Name, "^Hex_") and tile ~= buildingModel then
			tile:Destroy()
		end
	end
end

local function forceBuild(plr, buildingName, pos, rotationIndex)
	-- Snap to Hex tile (server authoritative)
	local tile = getHexModelFromWorld(pos)
	if not tile then return end
	if isForbiddenDestinationTile(tile) then return end
	if tile:GetAttribute("HasTree") == true then return end
	if tile:GetAttribute("IsBuilding") == true then return end

	local bFolder = ReplicatedStorage:FindFirstChild("Buildings")
	local template = bFolder and bFolder:FindFirstChild(buildingName)
	if not template then return end

	local tileName = tile.Name
	local tileAttrs = tile:GetAttributes()
	local p = getTileTruePosition(tile)

	local building = template:Clone()
	building.Name = tileName
	building.Parent = workspace

	CollectionService:AddTag(building, "RTSBuilding")

	building:SetAttribute("BuildingType", buildingName)
	building:SetAttribute("OwnerUserId", plr.UserId)
	building:SetAttribute("IsBuilding", true)
	building:SetAttribute("UnderConstruction", true) -- completed below

	-- Ensure Health/MaxHP exist for systems that expect them
	local maxHp = building:GetAttribute("MaxHP") or ADMIN_BUILDING_HP[buildingName]
	if maxHp then
		building:SetAttribute("MaxHP", maxHp)
		building:SetAttribute("Health", building:GetAttribute("Health") or maxHp)
	end

	-- Copy tile attributes onto the building model (matches RTSUnitServer)
	for k, v in pairs(tileAttrs) do
		building:SetAttribute(k, v)
	end

	-- Ensure towers have stable ids for garrison matching
	if buildingName == "ArcherTower" and not building:GetAttribute("BuildingId") then
		building:SetAttribute("BuildingId", HttpService:GenerateGUID(false))
	end

	-- Place + rotate around Y in 60-degree increments (hex rotation)
	local rotAngle = math.rad((rotationIndex or 0) * 60)
	local targetCF = CFrame.new(p) * CFrame.Angles(0, rotAngle, 0)

	-- Align model so it stands upright (use base-part offset like RTSUnitServer)
	local buildingBase = building:FindFirstChild("Tile") or building.PrimaryPart
	if buildingBase then
		local baseCF = buildingBase:IsA("BasePart") and buildingBase.CFrame or buildingBase:GetPivot()
		local modelCF = building:GetPivot()
		local offset = baseCF:Inverse() * modelCF
		building:PivotTo(targetCF * offset)
	else
		building:PivotTo(targetCF)
	end

	-- Anchor parts (admin builds are instant)
	for _, d in ipairs(building:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = true
		end
	end

	-- Match palisade pathfinding blockers
	if buildingName == "Palisade" then
		building:SetAttribute("IsWalkable", false)
		local obstaclePart = building:FindFirstChild("Tile") or building.PrimaryPart
		if obstaclePart then
			local mod = Instance.new("PathfindingModifier")
			mod.Label = "Wall"
			mod.PassThrough = false
			mod.Parent = obstaclePart
		end
	elseif buildingName == "Palisade2" then
		building:SetAttribute("IsWalkable", false)
		local obstaclePart = building:FindFirstChild("Tile") or building:FindFirstChild("Palisade2") or building.PrimaryPart
		if obstaclePart then
			local mod = Instance.new("PathfindingModifier")
			mod.Name = "WallModifier"
			mod.Label = "Wall"
			mod.PassThrough = false
			mod.Parent = obstaclePart
		end
	end

	finalizeAdminConstruction(plr, building)
end


AdminRemote.OnServerEvent:Connect(function(plr, action, data)
	if plr.UserId ~= OWNER_ID then return end -- Security Check

	if action == "SpawnUnit" then
		-- If client says "IsEnemy = true", we set owner to -1
		local owner = data.Enemy and -1 or plr.UserId
		spawnUnit(plr, data.Type, data.Pos, owner)

	elseif action == "Resources" then
		local g = plr:GetAttribute("Gold") or 0
		local w = plr:GetAttribute("Wood") or 0
		local s = plr:GetAttribute("Stone") or 0
		plr:SetAttribute("Gold", g + (data.Gold or 0))
		plr:SetAttribute("Wood", w + (data.Wood or 0))
		plr:SetAttribute("Stone", s + (data.Stone or 0))

	elseif action == "Population" then
		local cur = plr:GetAttribute("MaxPopulation") or 10
		local delta = (data and data.Delta) or 0
		plr:SetAttribute("MaxPopulation", math.max(0, cur + delta))


	elseif action == "Tile" then
		paintTile(data.Target, data.TileName)

	elseif action == "Building" then
		forceBuild(plr, data.Name, data.Pos, data.RotationIndex)

	elseif action == "Destroy" then
		if data.Target and data.Target.Parent then
			data.Target:Destroy()
		end
	end
end)