local MapRenderer = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local MapConfig = require(script.Parent.MapConfig)

-- Load Folders
local TileFolder = ReplicatedStorage:WaitForChild("HexTiles")
local ResourcesFolder = ReplicatedStorage:WaitForChild("Resources")
local GrassFolder = ReplicatedStorage:WaitForChild("Grass")

-- Load Asset References
local Assets = {
	GrassTile = TileFolder:WaitForChild("GrassTile"),
	DirtTile = TileFolder:WaitForChild("DirtTile"),
	StoneTile = TileFolder:WaitForChild("StoneTile"),
	WaterTile = TileFolder:WaitForChild("WaterTile"),
	SandTile = TileFolder:WaitForChild("SandTile"),
	HexTileHill = TileFolder:WaitForChild("HexTileHill"),
	HexTileHill2 = TileFolder:WaitForChild("HexTileHill2"),
	HexTileHillPeak = TileFolder:WaitForChild("HexTileHillPeak"),
	HexTileHillPeak2 = TileFolder:WaitForChild("HexTileHillPeak2"),
	HexTileHillPeak3 = TileFolder:WaitForChild("HexTileHillPeak3"),
	SnowyPeak1 = TileFolder:WaitForChild("SnowyPeak1"),
}

local GrassyTreeTile1 = TileFolder:WaitForChild("GrassyTreeTile1")
local TreeTemplate = GrassyTreeTile1:WaitForChild("Tree")
local TreeHexRef = GrassyTreeTile1:WaitForChild("HexTile")
local RockResourceTemplate = ResourcesFolder:WaitForChild("Rock")

-- Grass Variants List
local GrassVariants = {}
for _, obj in ipairs(GrassFolder:GetChildren()) do
	if obj:IsA("Model") or obj:IsA("BasePart") then table.insert(GrassVariants, obj) end
end

-- Helpers
local function setAllPartsColor(inst, color)
	if inst:IsA("BasePart") then inst.Color = color end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then d.Color = color end
	end
end

local function getTileSurfaceColor(tileModel)
	local p = tileModel.PrimaryPart or tileModel:FindFirstChildWhichIsA("BasePart", true)
	return p and p.Color or Color3.new(0.5,0.5,0.5)
end

function MapRenderer.calculateHexRadius()
	local sample = Assets.GrassTile.PrimaryPart or Assets.GrassTile:FindFirstChildWhichIsA("BasePart")
	local maxDim = math.max(sample.Size.X, sample.Size.Z)
	return (maxDim / 2) * MapConfig.PACKING_FACTOR
end

function MapRenderer.spawnMap(hexData, hexRadius)
	-- Folder Setup
	local mapRoot = workspace:FindFirstChild("MapRoot") or Instance.new("Folder", workspace)
	mapRoot.Name = "MapRoot"
	mapRoot:ClearAllChildren()

	local decorFolder = Instance.new("Folder", workspace)
	decorFolder.Name = "RTS_Decor"

	local resNodesFolder = workspace:FindFirstChild("ResourceNodes") or Instance.new("Folder", workspace)
	resNodesFolder.Name = "ResourceNodes"
	resNodesFolder:ClearAllChildren()

	local layFlat = CFrame.Angles(math.rad(-90), 0, 0)
	local treeLocal = TreeHexRef:GetPivot():ToObjectSpace(TreeTemplate:GetPivot())

	local tileCount = 0

	for _, hex in pairs(hexData) do
		local template = Assets[hex.biome]
		if not template then warn("Missing asset:", hex.biome) continue end

		local tile = template:Clone()
		tile.Name = "Hex_"..hex.q.."_"..hex.r
		tile.Parent = workspace

		-- Attributes
		tile:SetAttribute("IsWater", hex.biome == "WaterTile")
		tile:SetAttribute("IsWalkable", hex.biome ~= "WaterTile")
		tile:SetAttribute("TileKind", hex.biome)
		tile:SetAttribute("HasTree", false)
		tile:SetAttribute("HasRockNode", false)

		-- Pathfinding Modifier for Water
		if hex.biome == "WaterTile" then
			local surf = tile.PrimaryPart or tile:FindFirstChildWhichIsA("BasePart", true)
			if surf then
				local mod = Instance.new("PathfindingModifier")
				mod.Label = "Water"; mod.PassThrough = false; mod.Parent = surf
			end
		end

		-- Anchoring
		for _, v in ipairs(tile:GetDescendants()) do 
			if v:IsA("BasePart") then v.Anchored = true end 
		end

		-- Rotation & Height Offset
		local snapAngle = math.rad(math.random(0,5)*60)
		local heightOffset = 0
		if hex.biome == "HexTileHill" then heightOffset = 1.243
		elseif hex.biome == "HexTileHill2" then heightOffset = 1.243 * 2
		elseif hex.biome == "HexTileHillPeak" then heightOffset = 1.243 * 3
		elseif hex.biome == "HexTileHillPeak2" then heightOffset = 1.243 * 4
		elseif hex.biome == "HexTileHillPeak3" then heightOffset = 1.243 * 5
		elseif hex.biome == "SnowyPeak1" then heightOffset = 1.243 * 6
		end

		local finalPos = hex.worldPos + Vector3.new(0, heightOffset, 0)
		tile:PivotTo(CFrame.new(finalPos) * CFrame.Angles(0, snapAngle, 0) * layFlat)

		-- TREES
		local canHaveTree = (hex.biome == "GrassTile" or hex.biome == "HexTileHill" or hex.biome == "HexTileHill2")
		if hex.hasTree and canHaveTree then
			tile:SetAttribute("HasTree", true)
			local tree = TreeTemplate:Clone()
			tree.Parent = mapRoot
			tree:SetAttribute("IsRTSTree", true)
			CollectionService:AddTag(tree, "RTSTree")

			for _, v in ipairs(tree:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = true end end

			local tilePivot = tile:GetPivot()
			local tileH = tile:GetExtentsSize().Y
			local surfaceY = tilePivot.Position.Y + (tileH / 2)

			-- Tree Positioning Logic
			local attWCF = tilePivot * treeLocal
			local tPos = Vector3.new(attWCF.Position.X, surfaceY + 2, attWCF.Position.Z)
			tree:PivotTo(CFrame.new(tPos) * CFrame.Angles(0, snapAngle, 0))

			-- Snap Tree Bottom
			local minY = math.huge
			for _, d in ipairs(tree:GetDescendants()) do
				if d:IsA("BasePart") then
					local by = d.Position.Y - (d.Size.Y * 0.5)
					if by < minY then minY = by end
				end
			end
			local delta = surfaceY - minY
			tree:PivotTo(tree:GetPivot() * CFrame.new(0, delta + MapConfig.TREE_OFFSET_Y, 0))
		end

		-- DECORATIVE GRASS
		if (hex.biome == "GrassTile" or hex.biome == "HexTileHill" or hex.biome == "HexTileHill2") and #GrassVariants > 0 then
			if math.random() < 0.8 then
				for _ = 1, math.random(2,4) do
					local gTemplate = GrassVariants[math.random(1, #GrassVariants)]
					local gModel = gTemplate:Clone()
					gModel.Parent = decorFolder

					-- Disable collision/query
					local function clean(o) 
						if o:IsA("BasePart") then 
							o.Anchored=true; o.CanCollide=false; o.CanQuery=false; o.CanTouch=false 
						end 
					end
					clean(gModel); for _,v in ipairs(gModel:GetDescendants()) do clean(v) end

					-- Raycast Logic
					local tilePivot = tile:GetPivot()
					local tileTopY = tilePivot.Position.Y + tile:GetExtentsSize().Y * 0.5
					local angle = math.random() * math.pi * 2
					local dist = math.random() * (hexRadius * 0.45)
					local rOrigin = Vector3.new(tilePivot.Position.X + math.cos(angle)*dist, tileTopY + 10, tilePivot.Position.Z + math.sin(angle)*dist)

					local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = {tile}
					local res = workspace:Raycast(rOrigin, Vector3.new(0,-30,0), params)
					local hitPos = res and (res.Position + Vector3.new(0, -0.05, 0)) or Vector3.new(rOrigin.X, tileTopY, rOrigin.Z)

					if gModel:IsA("Model") then
						gModel:PivotTo(CFrame.new(hitPos) * CFrame.Angles(0, math.rad(math.random(0,359)), 0))
					else
						gModel.CFrame = CFrame.new(hitPos) * CFrame.Angles(0, math.rad(math.random(0,359)), 0)
					end
				end
			end
		end

		-- ROCKS (Peaks)
		local isPeak = (hex.biome == "HexTileHillPeak" or hex.biome == "HexTileHillPeak2" or hex.biome == "HexTileHillPeak3" or hex.biome == "SnowyPeak1")
		if isPeak and RockResourceTemplate and math.random() < MapConfig.ROCK_SPAWN_CHANCE then
			tile:SetAttribute("HasRockNode", true)
			local tileColor = getTileSurfaceColor(tile)
			local tilePivot = tile:GetPivot()
			local tileTopY = tilePivot.Position.Y + tile:GetExtentsSize().Y * 0.5

			for i = 1, math.random(MapConfig.ROCK_MIN_PER_TILE, MapConfig.ROCK_MAX_PER_TILE) do
				local rock = RockResourceTemplate:Clone()
				rock.Name = string.format("Rock_%d_%d_%d", hex.q, hex.r, i)
				rock.Parent = resNodesFolder
				rock:SetAttribute("IsResourceNode", true)
				rock:SetAttribute("ResourceType", "Rock")

				for _, v in ipairs(rock:GetDescendants()) do if v:IsA("BasePart") then v.Anchored = true end end

				local angle = math.random() * math.pi * 2
				local dist = math.random() * (hexRadius * MapConfig.ROCK_SCATTER_FACTOR)
				local rOrigin = Vector3.new(tilePivot.Position.X + math.cos(angle)*dist, tileTopY + 25, tilePivot.Position.Z + math.sin(angle)*dist)

				local params = RaycastParams.new(); params.FilterType = Enum.RaycastFilterType.Include; params.FilterDescendantsInstances = {tile}
				local res = workspace:Raycast(rOrigin, Vector3.new(0,-80,0), params)
				local surfY = res and res.Position.Y or tileTopY
				local hitPos = res and res.Position or Vector3.new(rOrigin.X, tileTopY, rOrigin.Z)

				if rock:IsA("Model") then
					rock:PivotTo(CFrame.new(hitPos.X, surfY + 2, hitPos.Z) * CFrame.Angles(0, math.rad(math.random(0,359)), 0))
				else
					rock.CFrame = CFrame.new(hitPos.X, surfY + 2, hitPos.Z) * CFrame.Angles(0, math.rad(math.random(0,359)), 0)
				end

				-- Snap Bottom
				local minY = math.huge
				local function check(o) if o:IsA("BasePart") then local by = o.Position.Y - o.Size.Y*0.5; if by < minY then minY = by end end end
				check(rock); for _,v in ipairs(rock:GetDescendants()) do check(v) end
				local dy = surfY - minY
				if rock:IsA("Model") then rock:PivotTo(rock:GetPivot() * CFrame.new(0, dy + 0.02, 0)) else rock.CFrame = rock.CFrame * CFrame.new(0, dy + 0.02, 0) end

				setAllPartsColor(rock, tileColor)
			end
		end
		tileCount = tileCount + 1
	end
	print("Map Rendered. Tiles:", tileCount)
end

return MapRenderer