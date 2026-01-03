--// Fog of War system: undiscovered tiles are black until units/buildings reveal them

local S = require(script.Parent.Shared)

local RunService = S.RunService
local CollectionService = S.CollectionService
local ReplicatedStorage = S.ReplicatedStorage
local player = S.player
local unitsFolder = S.unitsFolder

local FogOfWar = {}

-- Vision configuration
local UNIT_VISION_RADIUS = 70
local BUILDING_VISION_RADIUS = 90

-- State holders
local tileCovers: {[Model]: Instance} = {}
local discoveredTiles: {[Model]: boolean} = {}

local overlayFolder = Instance.new("Folder")
overlayFolder.Name = "FogOfWarOverlays"
overlayFolder.Parent = workspace
S.fogOverlayFolder = overlayFolder

local hexTilesFolder = ReplicatedStorage:FindFirstChild("HexTiles")
local fogTileTemplate = hexTilesFolder and hexTilesFolder:FindFirstChild("FogOfWar")

local function isHexTile(inst: Instance)
	return inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") ~= nil
end

local function isOwnedStructure(model: Model)
	local ownerId = model:GetAttribute("OwnerUserId")
	if ownerId and ownerId == player.UserId then
		return true
	end

	local ownerName = model:GetAttribute("Owner")
	if ownerName and ownerName == player.Name then
		return true
	end

	return false
end

local function getTileCoverSize(tile: Model)
	local success, size = pcall(function()
		return tile:GetExtentsSize()
	end)

	if success and size then
		return size + Vector3.new(0.25, 0, 0.25)
	end

	return Vector3.new(12, 1, 12)
end

local function sanitizeCoverPhysics(inst: Instance)
	local function apply(target: Instance)
		if target:IsA("BasePart") then
			target.Anchored = true
			target.CanCollide = false
			target.CanTouch = false
			target.CanQuery = false
			target.Massless = true
			target.CastShadow = false
		end
	end

	apply(inst)

	for _, child in ipairs(inst:GetDescendants()) do
		apply(child)
	end
end

local function setCoverTransparency(cover: Instance, transparency: number)
	if cover:IsA("BasePart") then
		cover.Transparency = transparency
	end

	for _, inst in ipairs(cover:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Transparency = transparency
		end
	end
end

local function createCoverForTile(tile: Model)
	if tileCovers[tile] then return end

	local size = getTileCoverSize(tile)
	local tilePivot = tile:GetPivot()
	local coverHeight = size.Y * 0.5 + 0.2

	local cover
	if fogTileTemplate then
		cover = fogTileTemplate:Clone()
		cover.Name = tile.Name .. "_Fog"
		cover.Parent = overlayFolder
		cover:PivotTo(tilePivot * CFrame.new(0, coverHeight, 0))
		sanitizeCoverPhysics(cover)
	else
		cover = Instance.new("Part")
		cover.Name = tile.Name .. "_Fog"
		cover.Size = Vector3.new(size.X, 0.25, size.Z)
		cover.Anchored = true
		cover.CanCollide = false
		cover.CanTouch = false
		cover.CanQuery = false
		cover.Material = Enum.Material.SmoothPlastic
		cover.Color = Color3.new(0, 0, 0)
		cover.Transparency = 0
		cover.CastShadow = false
		cover.Locked = true
		cover.CFrame = CFrame.new(tilePivot.Position + Vector3.new(0, coverHeight, 0))
		cover.Parent = overlayFolder
	end

	setCoverTransparency(cover, 0)

	tileCovers[tile] = cover
end


local function removeTileCover(tile: Model)
	local cover = tileCovers[tile]
	if cover then
		cover:Destroy()
		tileCovers[tile] = nil
		discoveredTiles[tile] = nil
	end
end

local function trackExistingTiles()
	for _, inst in ipairs(workspace:GetChildren()) do
		if isHexTile(inst) then
			createCoverForTile(inst)
		end
	end
end

local function onWorkspaceChildAdded(child: Instance)
	if isHexTile(child) then
		createCoverForTile(child)
	end
end

local function onWorkspaceChildRemoved(child: Instance)
	if isHexTile(child) then
		removeTileCover(child)
	end
end

local function gatherVisionSources()
	local sources = {}

	-- Player-owned units
	for _, model in ipairs(unitsFolder:GetChildren()) do
		if model:IsA("Model") and S.isOwnedUnit(model) then
			local pos = model:GetPivot().Position
			table.insert(sources, {pos = pos, radius = UNIT_VISION_RADIUS})
		end
	end

	-- Player-owned structures
	for _, structure in ipairs(CollectionService:GetTagged("RTSBuilding")) do
		if structure:IsA("Model") and structure:IsDescendantOf(workspace) and isOwnedStructure(structure) then
			local pos = structure:GetPivot().Position
			table.insert(sources, {pos = pos, radius = BUILDING_VISION_RADIUS})
		end
	end

	return sources
end

local function updateVisibility()
	local sources = gatherVisionSources()
	
	for tile, cover in pairs(tileCovers) do
		if tile.Parent then
			local tilePos = tile:GetPivot().Position
			local visible = false
			
			for _, src in ipairs(sources) do
				if (tilePos - src.pos).Magnitude <= src.radius then
					visible = true
					break
				end
			end
			
			if visible then
				discoveredTiles[tile] = true
				setCoverTransparency(cover, 1)
			elseif discoveredTiles[tile] then
				setCoverTransparency(cover, 0.7)
			else
				setCoverTransparency(cover, 0)
			end
		else
			removeTileCover(tile)
		end
	end
end

function FogOfWar.init()
	trackExistingTiles()

	workspace.ChildAdded:Connect(onWorkspaceChildAdded)
	workspace.ChildRemoved:Connect(onWorkspaceChildRemoved)

	RunService.Heartbeat:Connect(updateVisibility)
end

FogOfWar.init()

return FogOfWar
