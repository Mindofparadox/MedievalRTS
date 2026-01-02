-- HexGenScript.lua
-- Map generation with peaks + snowy peaks + rivers + trees + grass clutter
-- NEW: Spawns Rock resource nodes ONLY on peak tiles (HillPeak/HillPeak2/HillPeak3/SnowyPeak1)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- Tile sets folder
local TileFolder = ReplicatedStorage:WaitForChild("HexTiles")


-- Individual tile models
local GrassTile = TileFolder:WaitForChild("GrassTile")
local DirtTile  = TileFolder:WaitForChild("DirtTile")
local StoneTile = TileFolder:WaitForChild("StoneTile")
local WaterTile = TileFolder:WaitForChild("WaterTile")
local SandTile  = TileFolder:WaitForChild("SandTile")

-- Hill tiles (grassy, can have trees)
local HillTile      = TileFolder:WaitForChild("HexTileHill")      -- first level hill
local HillTile2     = TileFolder:WaitForChild("HexTileHill2")     -- second, higher hill
local HillPeakTile  = TileFolder:WaitForChild("HexTileHillPeak")  -- peak hill (2 steps above normal)

local HillPeakTile2 = TileFolder:WaitForChild("HexTileHillPeak2") -- higher than HillPeak
local HillPeakTile3 = TileFolder:WaitForChild("HexTileHillPeak3") -- higher than HillPeak2
local SnowyPeakTile1 = TileFolder:WaitForChild("SnowyPeak1") -- higher than HillPeak3 (snow mountains)

-- Tree source model lives inside GrassyTreeTile1
local GrassyTreeTile1 = TileFolder:WaitForChild("GrassyTreeTile1")
local TreeTemplate    = GrassyTreeTile1:WaitForChild("Tree")
local TreeHexRef      = GrassyTreeTile1:WaitForChild("HexTile")

-- Decorative grass models (small clutter)
local GrassFolder = ReplicatedStorage:WaitForChild("Grass")
local GrassVariants = {}

-- [[ 1. ADD THIS WITH THE OTHER FOLDERS AT THE TOP ]] --
local ResourceNodesFolder = workspace:FindFirstChild("ResourceNodes") or Instance.new("Folder", workspace)
ResourceNodesFolder.Name = "ResourceNodes"

local DecorFolder = workspace:FindFirstChild("RTS_Decor") or Instance.new("Folder", workspace)
DecorFolder.Name = "RTS_Decor"

-- ... [Scroll down to the Grass Spawning loop, approx line 615] ...



for _, obj in ipairs(GrassFolder:GetChildren()) do
	if obj:IsA("Model") or obj:IsA("BasePart") then
		table.insert(GrassVariants, obj)
	end
end

-- Resource nodes (RTS harvesting)
local ResourcesFolder = ReplicatedStorage:WaitForChild("Resources")
local RockResourceTemplate = ResourcesFolder:WaitForChild("Rock")

---------------------------------------------------------------------
-- CONFIGURATION
---------------------------------------------------------------------
local TILE_Y = 0

-- Rectangular map size in axial coords
local HALF_Q = 70      -- horizontal
local HALF_R = 70      -- vertical

local PACKING_FACTOR = 1.0

-- NOISE / HEIGHT SETTINGS
local SEED = math.random(1, 1000000000)

local NOISE_SCALE = 22          -- lower = more detailed shapes
local HEIGHT_SCALE = 2.20       -- > 1.0 = taller terrain (more hills/peaks)

-- Height thresholds (tuned for more grass, banded hills, rare stone)
local OCEAN_HEIGHT  = -0.23     -- below this = ocean
local BEACH_HEIGHT  = -0.02     -- low land / beaches

local HILL_LOW      =  0.28     -- start of highland band (low hills)
local HILL_HIGH     =  0.37     -- above this = high hills
local STONE_HEIGHT  =  0.48     -- above this = stone peaks (non-hill)
local PEAK2_HEIGHT  =  0.60     -- above this = HillPeak2
local PEAK3_HEIGHT  =  0.72     -- above this = HillPeak3
local SNOWY_HEIGHT  =  0.84     -- above this = SnowyPeak1

-- Island centers in normalized board space (-1..1, -1..1)
local ISLAND_CENTERS = {
	{ 0.0,  0.0},   -- center
	{-0.45, -0.1},  -- left-bottom-ish
	{ 0.45,  0.2},  -- right-top-ish
}

-- Land exists mainly within this radius of a center
local CENTER_RADIUS = 0.60

-- Domain-warp settings (organic shapes)
local WARP_SCALE     = 0.7
local WARP_STRENGTH  = 1.0

-- RIVER SETTINGS
local MAP_WIDTH  = HALF_Q * 2 + 1
local MAP_HEIGHT = HALF_R * 2 + 1
local NUM_RIVERS  = 6
local RIVER_STEPS = math.max(MAP_WIDTH, MAP_HEIGHT) * 2

-- RESOURCE SPAWNING (peaks)
local ROCK_SPAWN_CHANCE = 0.14        -- chance per eligible peak tile
local ROCK_MIN_PER_TILE = 1
local ROCK_MAX_PER_TILE = 2
local ROCK_SCATTER_RADIUS_FACTOR = 0.38 -- relative to HEX_RADIUS

-- Use size from GrassTile (all tiles should match scale)
local samplePart = GrassTile.PrimaryPart or GrassTile:FindFirstChildWhichIsA("BasePart")
local size = samplePart.Size
local maxDim = math.max(size.X, size.Z)
local HEX_RADIUS = (maxDim / 2) * PACKING_FACTOR

-- Tree offset (tree pivot in HEX-local space)
local TREE_LOCAL = TreeHexRef:GetPivot():ToObjectSpace(TreeTemplate:GetPivot())
local TREE_OFFSET_POS = TREE_LOCAL.Position
local TREE_EXTRA_Y = -6 -- adjust if you want (try 0 or 0.1)

local function pivotInstance(inst, cf)
	if inst:IsA("Model") then
		inst:PivotTo(cf)
	elseif inst:IsA("BasePart") then
		inst.CFrame = cf
	end
end

-- Helper: get a representative surface color from a tile (first BasePart)
local function getTileSurfaceColor(tileModel)
	local p = tileModel.PrimaryPart or tileModel:FindFirstChildWhichIsA("BasePart", true)
	if p then
		return p.Color
	end
	return Color3.new(0.5, 0.5, 0.5)
end

-- Helper: apply a color to all BaseParts inside an instance (including the instance itself)
local function setAllPartsColor(inst, color)
	if inst:IsA("BasePart") then
		inst.Color = color
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = color
		end
	end
end

-- Helper: move an instance up/down by dy studs
local function offsetInstanceY(inst, dy)
	if inst:IsA("Model") then
		inst:PivotTo(inst:GetPivot() * CFrame.new(0, dy, 0))
	elseif inst:IsA("BasePart") then
		inst.CFrame = inst.CFrame * CFrame.new(0, dy, 0)
	end
end

-- Helper: snap the bottom of an instance to a world Y value
local function snapBottomToY(inst, targetY, extraY)
	extraY = extraY or 0
	local minY = math.huge
	if inst:IsA("BasePart") then
		minY = inst.Position.Y - (inst.Size.Y * 0.5)
	else
		for _, d in ipairs(inst:GetDescendants()) do
			if d:IsA("BasePart") then
				local bottomY = d.Position.Y - (d.Size.Y * 0.5)
				if bottomY < minY then
					minY = bottomY
				end
			end
		end
	end
	if minY == math.huge then
		return
	end
	local deltaY = targetY - minY
	offsetInstanceY(inst, deltaY + extraY)
end

local function snapTreeToTileTop(treeModel, tileModel)
	local tilePivot = tileModel:GetPivot()
	local tileSize = tileModel:GetExtentsSize()
	local tileTopY = tilePivot.Position.Y + tileSize.Y * 0.5

	-- Find tree bottom Y
	local minY = math.huge
	for _, d in ipairs(treeModel:GetDescendants()) do
		if d:IsA("BasePart") then
			local bottomY = d.Position.Y - (d.Size.Y * 0.5)
			if bottomY < minY then
				minY = bottomY
			end
		end
	end

	local deltaY = tileTopY - minY
	treeModel:PivotTo(treeModel:GetPivot() * CFrame.new(0, deltaY + TREE_EXTRA_Y, 0))
end

---------------------------------------------------------------------
-- MATH: Pointy-Topped Hex
---------------------------------------------------------------------
local function axialToWorld(q, r)
	local x = HEX_RADIUS * math.sqrt(3) * (q + r/2)
	local z = HEX_RADIUS * 1.5 * r
	return Vector3.new(x, TILE_Y, z)
end

-- Normalized board coordinates (-1..1)
local function getNormalizedPos(q, r)
	local dx = q / HALF_Q
	local dy = r / HALF_R
	return dx, dy
end

-- Distance to nearest island center in normalized board space
local function getCenterDistance(dx, dy)
	local best = math.huge
	for _, c in ipairs(ISLAND_CENTERS) do
		local cx, cy = c[1], c[2]
		local ddx = dx - cx
		local ddy = dy - cy
		local d = math.sqrt(ddx * ddx + ddy * ddy)
		if d < best then
			best = d
		end
	end
	return best
end

---------------------------------------------------------------------
-- HEIGHT FUNCTION (domain-warped, multi-center islands)
---------------------------------------------------------------------
local function getHeight(q, r)
	local x = q / NOISE_SCALE
	local y = r / NOISE_SCALE

	-- Domain warp
	local wx = math.noise(x * WARP_SCALE, y * WARP_SCALE, SEED + 200) * WARP_STRENGTH
	local wy = math.noise(x * WARP_SCALE, y * WARP_SCALE, SEED + 400) * WARP_STRENGTH

	local sx = x + wx
	local sy = y + wy

	-- Three-octave fractal noise
	local n1 = math.noise(sx,       sy,       SEED)
	local n2 = math.noise(sx * 2,   sy * 2,   SEED + 101) * 0.6
	local n3 = math.noise(sx * 4,   sy * 4,   SEED + 303) * 0.3

	local h = (n1 + n2 + n3) / (1 + 0.6 + 0.3)

	-- Falloff from nearest island center
	local dx, dy = getNormalizedPos(q, r)
	local centerDist = getCenterDistance(dx, dy)

	h = h - centerDist * 0.20

	-- Scale overall height so more tiles reach hill / peak thresholds
	h = h * HEIGHT_SCALE

	return h
end

---------------------------------------------------------------------
-- HEX DATA / HELPERS
---------------------------------------------------------------------
local HexData = {}

local function getKey(q, r)
	return q .. "_" .. r
end

local function getHex(q, r)
	return HexData[getKey(q, r)]
end

-- 6 axial neighbors (pointy-top)
local neighborDirs = {
	{ 1,  0},
	{ 1, -1},
	{ 0, -1},
	{-1,  0},
	{-1,  1},
	{ 0,  1},
}

---------------------------------------------------------------------
-- BIOME SELECTION FROM HEIGHT (for non-hill land)
-- returns: tileModelTemplate, hasTree
---------------------------------------------------------------------
local function getLandModelFromHeight(h)
	-- NOTE: very high tiles (h >= STONE_HEIGHT) are now handled
	-- in the final assignment pass as HillPeakTile, so we do NOT
	-- return StoneTile here for h >= STONE_HEIGHT.

	-- Upper highland, but not hills (ridge shoulders etc.)
	if h > HILL_HIGH then
		local roll = math.random()
		if roll < 0.10 then
			return StoneTile, false      -- 10% stone
		elseif roll < 0.40 then
			return DirtTile, false       -- 30% dirt
		else
			local hasTree = (math.random() < 0.35)
			return GrassTile, hasTree    -- 60% grass
		end
	end

	-- Mid land: now mostly grass, some dirt, tiny stone
	if h > BEACH_HEIGHT then
		local roll = math.random()
		if roll < 0.03 then
			return StoneTile, false      -- 3% stone
		elseif roll < 0.28 then
			return DirtTile, false       -- 25% dirt
		else
			local hasTree = (math.random() < 0.60)
			return GrassTile, hasTree    -- 72% grass
		end
	end

	-- Low land near beach: very rare stone pockets
	if h > BEACH_HEIGHT - 0.05 and math.random() < 0.02 then
		return StoneTile, false
	end

	-- Grass zone: more trees than before
	local treeChance = 0.55 -- 55% of low tiles get a tree
	local hasTree = math.random() < treeChance

	return GrassTile, hasTree
end

---------------------------------------------------------------------
-- RIVER GENERATION
---------------------------------------------------------------------

-- Pick a random inland, non-ocean, relatively high tile near any island center
local function pickRiverStart()
	local candidates = {}
	for _, hex in pairs(HexData) do
		if not hex.isOcean then
			local dx, dy = getNormalizedPos(hex.q, hex.r)
			local centerDist = getCenterDistance(dx, dy)

			if centerDist < 0.5 and hex.height > BEACH_HEIGHT then
				table.insert(candidates, hex)
			end
		end
	end

	if #candidates == 0 then
		return nil
	end

	return candidates[math.random(1, #candidates)]
end

-- Carve a river following lowest-height neighbors (downhill through land)
local function carveRiver(startHex, maxSteps)
	local current = startHex

	for _ = 1, maxSteps do
		if not current or current.isRiver or current.isOcean then
			break
		end

		current.isRiver = true

		local bestNeighbor = nil
		local bestScore = math.huge

		for _, dir in ipairs(neighborDirs) do
			local nq = current.q + dir[1]
			local nr = current.r + dir[2]
			local neigh = getHex(nq, nr)

			if neigh and not neigh.isRiver and not neigh.isOcean then
				local score = neigh.height
				if score < bestScore then
					bestScore = score
					bestNeighbor = neigh
				end
			end
		end

		if not bestNeighbor then
			break
		end

		current = bestNeighbor
	end
end

---------------------------------------------------------------------
-- BUILD HEXDATA (HEIGHT & POSITIONS)
---------------------------------------------------------------------
math.randomseed(tick())

for q = -HALF_Q, HALF_Q do
	for r = -HALF_R, HALF_R do
		local worldPos = axialToWorld(q, r)
		local height = getHeight(q, r)

		local key = getKey(q, r)
		HexData[key] = {
			q = q,
			r = r,
			worldPos = worldPos,
			height = height,
			isOcean = false,
			isRiver = false,
			isCoast = false,
			isHillCandidate = false,
			isHill = false,
			isHighHill = false,
			isPeakHill = false,
			hasTree = false,
			tileModelTemplate = nil,
		}
	end
end

---------------------------------------------------------------------
-- CLASSIFY OCEAN (edges + low height + multi-center radius)
---------------------------------------------------------------------
for _, hex in pairs(HexData) do
	local q = hex.q
	local r = hex.r

	local dx, dy = getNormalizedPos(q, r)
	local centerDist = getCenterDistance(dx, dy)

	local radiusNoise = math.noise(dx * 1.3, dy * 1.3, SEED + 999) * 0.05
	local effectiveRadius = CENTER_RADIUS + radiusNoise

	local isOutsideCenters = centerDist > effectiveRadius
	local isLowHeight = hex.height < OCEAN_HEIGHT
	local isEdge = (math.abs(q) == HALF_Q) or (math.abs(r) == HALF_R)

	if isOutsideCenters or isEdge or isLowHeight then
		hex.isOcean = true
	end
end

---------------------------------------------------------------------
-- CARVE RIVERS (only through land)
---------------------------------------------------------------------
for i = 1, NUM_RIVERS do
	local startHex = pickRiverStart()
	if startHex then
		carveRiver(startHex, RIVER_STEPS)
	end
end

---------------------------------------------------------------------
-- MARK COASTLINE TILES
-- Land touching ANY water (ocean OR river) becomes sand
---------------------------------------------------------------------
-- First ring: tiles directly adjacent to water
for _, hex in pairs(HexData) do
	if not hex.isOcean and not hex.isRiver then
		for _, dir in ipairs(neighborDirs) do
			local nq = hex.q + dir[1]
			local nr = hex.r + dir[2]
			local neigh = getHex(nq, nr)

			if neigh and (neigh.isOcean or neigh.isRiver) then
				hex.isCoast = true
				break
			end
		end
	end
end

---------------------------------------------------------------------
-- MARK HILL CANDIDATES (elevated inland tiles)
---------------------------------------------------------------------
for _, hex in pairs(HexData) do
	if not hex.isOcean and not hex.isRiver and not hex.isCoast then
		-- Much broader band so hills are more common
		if hex.height > (HILL_LOW - 0.20) and hex.height < STONE_HEIGHT then
			hex.isHillCandidate = true
		end
	end
end

-- First pass: convert candidates to hills using local neighborhood
for _, hex in pairs(HexData) do
	if hex.isHillCandidate then
		local neighborHillish = 0

		for _, dir in ipairs(neighborDirs) do
			local n = getHex(hex.q + dir[1], hex.r + dir[2])
			if n and not n.isOcean and not n.isRiver and not n.isCoast then
				if n.height > (HILL_LOW - 0.20) and n.height < STONE_HEIGHT then
					neighborHillish += 1
				end
			end
		end

		-- Base hill decision
		if neighborHillish >= 1
			or hex.height > (HILL_LOW - 0.03)
			or math.random() < 0.40 then
			hex.isHill = true
		end
	end
end

-- Extra passes: fill "holes" inside hill clusters so we don't get low pits
for iteration = 1, 2 do
	local toPromote = {}

	for _, hex in pairs(HexData) do
		if not hex.isOcean and not hex.isRiver and not hex.isCoast and not hex.isHill then
			local hillNeighbors = 0

			for _, dir in ipairs(neighborDirs) do
				local n = getHex(hex.q + dir[1], hex.r + dir[2])
				if n and n.isHill then
					hillNeighbors += 1
				end
			end

			-- If most neighbors are hills, promote this tile too
			if hillNeighbors >= 4 then
				table.insert(toPromote, hex)
			end
		end
	end

	for _, hex in ipairs(toPromote) do
		hex.isHill = true

		-- Pull up the height a bit so it won't look like a sunken tile
		if hex.height < HILL_LOW then
			hex.height = HILL_LOW + 0.01
		end
	end
end

-- Split hills into low hills and high hills (and peaks) based on height
-- (high hills / peaks still only come from existing hills)
for _, hex in pairs(HexData) do
	if hex.isHill then
		local h = hex.height

		-- Peak hills: highest part of the hill band
		if h >= (HILL_HIGH + 0.05) then
			hex.isHighHill = true
			hex.isPeakHill = true
			-- Normal high hills (fairly common within hill band)
		elseif h >= HILL_HIGH or (h >= HILL_LOW and math.random() < 0.5) then
			hex.isHighHill = true
		end
	end
end

---------------------------------------------------------------------
-- ASSIGN FINAL TILE MODEL
---------------------------------------------------------------------
for _, hex in pairs(HexData) do
	if hex.isOcean or hex.isRiver then
		hex.tileModelTemplate = WaterTile
		hex.hasTree = false

	elseif hex.isCoast then
		-- Mostly sand, but some rocky shoreline
		local rockyChance = 0.18  -- tweak this for more/less rocky coast
		if hex.height > (OCEAN_HEIGHT + 0.03) and math.random() < rockyChance then
			hex.tileModelTemplate = StoneTile
			hex.hasTree = false
		else
			hex.tileModelTemplate = SandTile
			hex.hasTree = false
		end

		-- Highest inland tile becomes a SNOWY PEAK tile directly
	elseif hex.height >= SNOWY_HEIGHT then
		hex.tileModelTemplate = SnowyPeakTile1
		hex.hasTree = false
		hex.isPeakHill = true

		-- Any ultra high inland tile becomes a PEAK3 tile directly
	elseif hex.height >= PEAK3_HEIGHT then
		hex.tileModelTemplate = HillPeakTile3
		hex.hasTree = false
		hex.isPeakHill = true

		-- Any ultra high inland tile becomes a PEAK2 tile directly
	elseif hex.height >= PEAK2_HEIGHT then
		hex.tileModelTemplate = HillPeakTile2
		hex.hasTree = false
		hex.isPeakHill = true

		-- Any very high inland tile becomes a PEAK tile directly
	elseif hex.height >= STONE_HEIGHT then
		hex.tileModelTemplate = HillPeakTile
		hex.hasTree = false
		hex.isPeakHill = true

	elseif hex.isHighHill then
		-- Higher grassy hill
		hex.tileModelTemplate = HillTile2
		hex.hasTree = (math.random() < 0.4)

	elseif hex.isHill then
		-- Lower grassy hill
		hex.tileModelTemplate = HillTile
		hex.hasTree = (math.random() < 0.45)

	else
		local modelTemplate, hasTree = getLandModelFromHeight(hex.height)
		hex.tileModelTemplate = modelTemplate
		hex.hasTree = hasTree
	end
end

---------------------------------------------------------------------
-- SPAWN TILES
---------------------------------------------------------------------
local LAY_FLAT_ROTATION = CFrame.Angles(math.rad(-90), 0, 0)
local tileCount = 0

-- Folder to keep spawned resource nodes organized
local ResourceNodesFolder = workspace:FindFirstChild("ResourceNodes")
if not ResourceNodesFolder then
	ResourceNodesFolder = Instance.new("Folder")
	ResourceNodesFolder.Name = "ResourceNodes"
	ResourceNodesFolder.Parent = workspace
end

for _, hex in pairs(HexData) do
	local template = hex.tileModelTemplate
	if template then
		local tileModel = template:Clone()
		tileModel.Name = "Hex_" .. hex.q .. "_" .. hex.r
		tileModel.Parent = workspace

		-- Tile metadata for RTS logic (client can check walkable/biome)
		tileModel:SetAttribute("IsWater", template == WaterTile)
		tileModel:SetAttribute("IsWalkable", template ~= WaterTile)
		tileModel:SetAttribute("TileKind", template.Name)
		tileModel:SetAttribute("HasTree", false)
		tileModel:SetAttribute("HasRockNode", false)

		-- Make water tiles unpathfindable (PathfindingModifier label used by server costs)
		if template == WaterTile then
			local surfacePart = tileModel.PrimaryPart or tileModel:FindFirstChildWhichIsA("BasePart", true)
			if surfacePart then
				local mod = Instance.new("PathfindingModifier")
				mod.Label = "Water"
				mod.PassThrough = false
				mod.Parent = surfacePart
			end
		end

		-- Anchor every part of the tile
		for _, obj in ipairs(tileModel:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
			end
		end

		-- Random 60  rotation for visual variation
		local snapIndex = math.random(0, 5)
		local snapAngle = math.rad(snapIndex * 60)

		-- WORLD-SPACE HEIGHT OFFSET FOR HILLS
		local heightOffset = 0
		if template == HillTile then
			heightOffset = 1.243
		elseif template == HillTile2 then
			heightOffset = 1.243 * 2
		elseif template == HillPeakTile then
			heightOffset = 1.243 * 3
		elseif template == HillPeakTile2 then
			heightOffset = 1.243 * 4
		elseif template == HillPeakTile3 then
			heightOffset = 1.243 * 5
		elseif template == SnowyPeakTile1 then
			heightOffset = 1.243 * 6
		end

		local worldPosWithOffset = hex.worldPos + Vector3.new(0, heightOffset, 0)

		local finalCFrame =
			CFrame.new(worldPosWithOffset)
			* CFrame.Angles(0, snapAngle, 0)
			* LAY_FLAT_ROTATION

		tileModel:PivotTo(finalCFrame)

		-----------------------------------------------------------------
		-- TREES (only on grass / hill tiles)
		-----------------------------------------------------------------
		local canHaveTree =
			(template == GrassTile)
			or (template == HillTile)
			or (template == HillTile2)

		if hex.hasTree and canHaveTree then
			tileModel:SetAttribute("HasTree", true)

			local treeModel = TreeTemplate:Clone()
			treeModel.Parent = workspace
			treeModel:SetAttribute("IsRTSTree", true)
			CollectionService:AddTag(treeModel, "RTSTree")

			for _, obj in ipairs(treeModel:GetDescendants()) do
				if obj:IsA("BasePart") then
					obj.Anchored = true
				end
			end

			-- 1) raw attachment CFrame (gives X/Z center)
			local attachmentWorldCFrame = tileModel:GetPivot() * TREE_LOCAL

			-- 2) safe surface height (tile top)
			local tilePivot = tileModel:GetPivot()
			local tileHeight = tileModel:GetExtentsSize().Y
			local surfaceY = tilePivot.Position.Y + (tileHeight / 2)

			-- 3) force Y to surface
			local targetPos = Vector3.new(
				attachmentWorldCFrame.Position.X,
				surfaceY + 2,
				attachmentWorldCFrame.Position.Z
			)

			-- 4) upright rotation
			local finalTreeCFrame = CFrame.new(targetPos) * CFrame.Angles(0, snapAngle, 0)
			treeModel:PivotTo(finalTreeCFrame)

			-- 5) final snap
			snapTreeToTileTop(treeModel, tileModel)
		end

		-----------------------------------------------------------------
		-- DECORATIVE GRASS (only on grass / hill tiles, NOT peaks)
		-----------------------------------------------------------------
		local isGrassLike =
			(template == GrassTile) or
			(template == HillTile) or
			(template == HillTile2)

		if isGrassLike and #GrassVariants > 0 then
			if math.random() < 0.80 then
				local clumpCount = math.random(2, 4)

				local tilePivot = tileModel:GetPivot()
				local tileSize = tileModel:GetExtentsSize()
				local tileTopY = tilePivot.Position.Y + tileSize.Y * 0.5

				local scatterRadius = HEX_RADIUS * 0.45

				for _ = 1, clumpCount do
					-- 1. Pick a random grass template
					local templateIndex = math.random(1, #GrassVariants)
					local grassTemplate = GrassVariants[templateIndex]

					-- 2. Clone it and put it in the DecorFolder
					local grassModel = grassTemplate:Clone()
					grassModel.Parent = DecorFolder 

					-- [FIX] Decorative grass should never block placement / selection
					-- (We still block on Trees/Water/Existing Structures via tile attributes)
					if grassModel:IsA("BasePart") then
						grassModel.Anchored = true
						grassModel.CanCollide = false
						grassModel.CanQuery = false
						grassModel.CanTouch = false
					else
						for _, d in ipairs(grassModel:GetDescendants()) do
							if d:IsA("BasePart") then
								d.Anchored = true
								d.CanCollide = false
								d.CanQuery = false
								d.CanTouch = false
							end
						end
					end


					-- 3. Positioning Logic
					local angle = math.random() * math.pi * 2
					local dist  = math.random() * scatterRadius
					local offsetX = math.cos(angle) * dist
					local offsetZ = math.sin(angle) * dist

					local rayOrigin = Vector3.new(
						tilePivot.Position.X + offsetX,
						tileTopY + 10,
						tilePivot.Position.Z + offsetZ
					)

					local rayDirection = Vector3.new(0, -30, 0)

					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { tileModel }

					local result = workspace:Raycast(rayOrigin, rayDirection, params)

					local hitPos
					if result then
						hitPos = result.Position + Vector3.new(0, -0.05, 0)
					else
						hitPos = Vector3.new(rayOrigin.X, tileTopY, rayOrigin.Z)
					end

					local yaw = math.rad(math.random(0, 359))

					pivotInstance(grassModel, CFrame.new(hitPos) * CFrame.Angles(0, yaw, 0))
				end
			end
		end

		-----------------------------------------------------------------
		-- ROCK RESOURCE NODES (only on peak / snowy peak tiles)
		-----------------------------------------------------------------
		local isPeakTile =
			(template == HillPeakTile)
			or (template == HillPeakTile2)
			or (template == HillPeakTile3)
			or (template == SnowyPeakTile1)

		if isPeakTile and RockResourceTemplate then
			if math.random() < ROCK_SPAWN_CHANCE then
				tileModel:SetAttribute("HasRockNode", true)

				local tilePivot = tileModel:GetPivot()
				local tileSize = tileModel:GetExtentsSize()
				local tileTopY = tilePivot.Position.Y + tileSize.Y * 0.5
				local scatterRadius = HEX_RADIUS * ROCK_SCATTER_RADIUS_FACTOR
				local tileColor = getTileSurfaceColor(tileModel)

				local nodeCount = math.random(ROCK_MIN_PER_TILE, ROCK_MAX_PER_TILE)
				for idx = 1, nodeCount do
					local rock = RockResourceTemplate:Clone()
					rock.Name = ("Rock_%d_%d_%d"):format(hex.q, hex.r, idx)
					rock.Parent = ResourceNodesFolder
					rock:SetAttribute("IsResourceNode", true)
					rock:SetAttribute("ResourceType", "Rock")

					-- Anchor all parts so map gen stays static
					if rock:IsA("BasePart") then
						rock.Anchored = true
					end
					for _, obj in ipairs(rock:GetDescendants()) do
						if obj:IsA("BasePart") then
							obj.Anchored = true
						end
					end

					-- Scatter on the tile surface
					local angle = math.random() * math.pi * 2
					local dist  = math.random() * scatterRadius
					local offsetX = math.cos(angle) * dist
					local offsetZ = math.sin(angle) * dist

					local rayOrigin = Vector3.new(
						tilePivot.Position.X + offsetX,
						tileTopY + 25,
						tilePivot.Position.Z + offsetZ
					)
					local rayDirection = Vector3.new(0, -80, 0)

					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { tileModel }

					local result = workspace:Raycast(rayOrigin, rayDirection, params)
					local surfaceY
					local hitPos
					if result then
						surfaceY = result.Position.Y
						hitPos = result.Position
					else
						surfaceY = tileTopY
						hitPos = Vector3.new(rayOrigin.X, tileTopY, rayOrigin.Z)
					end

					local yaw = math.rad(math.random(0, 359))
					pivotInstance(rock, CFrame.new(Vector3.new(hitPos.X, surfaceY + 2, hitPos.Z)) * CFrame.Angles(0, yaw, 0))
					snapBottomToY(rock, surfaceY, 0.02)
					setAllPartsColor(rock, tileColor)
				end
			end
		end

		tileCount += 1
	end
end

print("Generated hex archipelago. Seed:", SEED, " Tiles:", tileCount)
