local AdminServerLogic = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.AdminServerConfig)

-- Helpers
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
	local bestPart, maxArea = nil, 0
	for _, part in ipairs(tileModel:GetDescendants()) do
		if part:IsA("BasePart") then
			local area = part.Size.X * part.Size.Z
			if area > maxArea then maxArea = area; bestPart = part end
		end
	end
	return bestPart and Vector3.new(bestPart.Position.X, tileModel:GetPivot().Position.Y, bestPart.Position.Z) or tileModel:GetPivot().Position
end

local function finalizeAdminConstruction(plr, buildingModel)
	buildingModel:SetAttribute("UnderConstruction", nil)

	if buildingModel:GetAttribute("BuildingType") == "House" then
		local curMax = plr:GetAttribute("MaxPopulation") or 10
		plr:SetAttribute("MaxPopulation", curMax + 5)
	end

	-- Destroy underlying tile
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { buildingModel, workspace:FindFirstChild("RTSUnits") }
	params.IgnoreWater = true
	local res = workspace:Raycast(buildingModel:GetPivot().Position + Vector3.new(0, 5, 0), Vector3.new(0, -40, 0), params)
	if res and res.Instance then
		local tile = res.Instance:FindFirstAncestorOfClass("Model")
		if tile and string.match(tile.Name, "^Hex_") and tile ~= buildingModel then
			tile:Destroy()
		end
	end
end

-- Core Functions
function AdminServerLogic.spawnUnit(plr, unitType, pos, ownerIdOverride)
	local unitsFolder = workspace:FindFirstChild("RTSUnits")
	local template = ReplicatedStorage:WaitForChild("Units"):FindFirstChild(unitType)

	if template and unitsFolder then
		local unit = template:Clone()
		local n = math.random(1000, 99999)
		unit.Name = unitType .. "_" .. n
		unit.Parent = unitsFolder

		local finalOwner = ownerIdOverride or plr.UserId
		local isEnemy = (finalOwner == -1)

		unit:SetAttribute("OwnerUserId", finalOwner)
		unit:SetAttribute("UnitId", tostring(finalOwner) .. "_" .. n)
		unit:SetAttribute("UnitType", unitType)
		CollectionService:AddTag(unit, "RTSUnit")
		unit:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))

		-- Billboard
		local bb = Instance.new("BillboardGui", unit)
		bb.Size = UDim2.fromOffset(120, 20); bb.StudsOffset = Vector3.new(0, 3.5, 0); bb.AlwaysOnTop = true
		local t = Instance.new("TextLabel", bb); t.Size = UDim2.fromScale(1,1); t.BackgroundTransparency = 1; t.Font = Enum.Font.GothamBlack

		if isEnemy then
			t.Text = "ENEMY UNIT"; t.TextColor3 = Color3.fromRGB(255, 50, 50)
		else
			t.Text = "ADMIN SPAWN"; t.TextColor3 = Color3.fromRGB(255, 100, 255)
		end
	end
end

function AdminServerLogic.paintTile(targetTileModel, newTileName)
	if not targetTileModel or not targetTileModel.Parent then return end
	local tileFolder = ReplicatedStorage:FindFirstChild("HexTiles")
	local template = tileFolder and tileFolder:FindFirstChild(newTileName)
	if not template then return end

	local oldCF, oldName, parent = targetTileModel:GetPivot(), targetTileModel.Name, targetTileModel.Parent
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

function AdminServerLogic.forceBuild(plr, buildingName, pos)
	local tile = getHexModelFromWorld(pos)
	if not tile or tile:GetAttribute("IsWater") or tile:GetAttribute("IsWalkable") == false or tile:GetAttribute("IsBuilding") then return end

	local bFolder = ReplicatedStorage:FindFirstChild("Buildings")
	local template = bFolder and bFolder:FindFirstChild(buildingName)
	if not template then return end

	local building = template:Clone()
	building.Name = tile.Name
	building.Parent = workspace
	CollectionService:AddTag(building, "RTSBuilding")
	building:SetAttribute("BuildingType", buildingName)
	building:SetAttribute("OwnerUserId", plr.UserId)
	building:SetAttribute("IsBuilding", true)

	local maxHp = building:GetAttribute("MaxHP") or Config.BUILDING_HP[buildingName]
	if maxHp then building:SetAttribute("MaxHP", maxHp); building:SetAttribute("Health", maxHp) end
	for k, v in pairs(tile:GetAttributes()) do building:SetAttribute(k, v) end

	if buildingName == "ArcherTower" and not building:GetAttribute("BuildingId") then
		building:SetAttribute("BuildingId", HttpService:GenerateGUID(false))
	end

	local p = getTileTruePosition(tile)
	local targetCF = CFrame.new(p)
	local buildingBase = building:FindFirstChild("Tile") or building.PrimaryPart
	if buildingBase then
		local offset = buildingBase:GetPivot():Inverse() * building:GetPivot()
		building:PivotTo(targetCF * offset)
	else
		building:PivotTo(targetCF)
	end

	for _, d in ipairs(building:GetDescendants()) do if d:IsA("BasePart") then d.Anchored = true; d.CanCollide = true end end

	if buildingName == "Palisade" or buildingName == "Palisade2" then
		building:SetAttribute("IsWalkable", false)
		local obs = building:FindFirstChild("Tile") or building.PrimaryPart
		if obs then 
			local mod = Instance.new("PathfindingModifier"); mod.Label = "Wall"; mod.PassThrough = false; mod.Parent = obs 
		end
	end

	finalizeAdminConstruction(plr, building)
end

return AdminServerLogic