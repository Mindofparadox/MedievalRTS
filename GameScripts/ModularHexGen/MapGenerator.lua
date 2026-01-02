local MapGenerator = {}
local MapConfig = require(script.Parent.MapConfig)
local HexMath = require(script.Parent.HexMath)

local NEIGHBORS = {{1,0}, {1,-1}, {0,-1}, {-1,0}, {-1,1}, {0,1}}

local function getKey(q, r) return q .. "_" .. r end

-- Helper to find neighbors
local function getNeighbor(hexData, q, r, dir)
	local nKey = getKey(q + dir[1], r + dir[2])
	return hexData[nKey]
end

local function getHeight(q, r, seed)
	local x = q / MapConfig.NOISE_SCALE
	local y = r / MapConfig.NOISE_SCALE

	-- Domain warp
	local wx = math.noise(x * MapConfig.WARP_SCALE, y * MapConfig.WARP_SCALE, seed + 200) * MapConfig.WARP_STRENGTH
	local wy = math.noise(x * MapConfig.WARP_SCALE, y * MapConfig.WARP_SCALE, seed + 400) * MapConfig.WARP_STRENGTH
	local sx = x + wx
	local sy = y + wy

	local n1 = math.noise(sx, sy, seed)
	local n2 = math.noise(sx * 2, sy * 2, seed + 101) * 0.6
	local n3 = math.noise(sx * 4, sy * 4, seed + 303) * 0.3
	local h = (n1 + n2 + n3) / 1.9

	local dx, dy = HexMath.getNormalizedPos(q, r, MapConfig.HALF_Q, MapConfig.HALF_R)
	local centerDist = HexMath.getCenterDistance(dx, dy, MapConfig.ISLAND_CENTERS)

	h = h - centerDist * 0.20
	return h * MapConfig.HEIGHT_SCALE
end

-- Logic for non-hill land types
local function getLandTypeFromHeight(h)
	if h > MapConfig.HILL_HIGH then
		local roll = math.random()
		if roll < 0.10 then return "StoneTile", false
		elseif roll < 0.40 then return "DirtTile", false
		else return "GrassTile", (math.random() < 0.35) end
	end
	if h > MapConfig.BEACH_HEIGHT then
		local roll = math.random()
		if roll < 0.03 then return "StoneTile", false
		elseif roll < 0.28 then return "DirtTile", false
		else return "GrassTile", (math.random() < 0.60) end
	end
	if h > MapConfig.BEACH_HEIGHT - 0.05 and math.random() < 0.02 then
		return "StoneTile", false
	end

	-- Low grass zone
	return "GrassTile", (math.random() < MapConfig.TREE_CHANCE_GRASS)
end

function MapGenerator.generateData(seed, hexRadius)
	local hexData = {}
	math.randomseed(seed)

	-- 1. Base Generation
	for q = -MapConfig.HALF_Q, MapConfig.HALF_Q do
		for r = -MapConfig.HALF_R, MapConfig.HALF_R do
			local h = getHeight(q, r, seed)
			local worldPos = HexMath.axialToWorld(q, r, hexRadius, MapConfig.TILE_Y)

			hexData[getKey(q,r)] = {
				q = q, r = r, worldPos = worldPos, height = h,
				isOcean = false, isRiver = false, isCoast = false,
				isHill = false, isHighHill = false, isPeakHill = false,
				biome = nil, hasTree = false
			}
		end
	end

	-- 2. Classify Ocean
	for _, hex in pairs(hexData) do
		local dx, dy = HexMath.getNormalizedPos(hex.q, hex.r, MapConfig.HALF_Q, MapConfig.HALF_R)
		local dist = HexMath.getCenterDistance(dx, dy, MapConfig.ISLAND_CENTERS)
		local noise = math.noise(dx * 1.3, dy * 1.3, seed + 999) * 0.05

		if (dist > (MapConfig.CENTER_RADIUS + noise)) 
			or (math.abs(hex.q) == MapConfig.HALF_Q) or (math.abs(hex.r) == MapConfig.HALF_R)
			or (hex.height < MapConfig.OCEAN_HEIGHT) then
			hex.isOcean = true
		end
	end

	-- 3. Rivers
	local riverSteps = math.max(MapConfig.HALF_Q*2, MapConfig.HALF_R*2) * 2
	for i = 1, MapConfig.NUM_RIVERS do
		-- Pick Start
		local candidates = {}
		for _, hex in pairs(hexData) do
			if not hex.isOcean then
				local dx, dy = HexMath.getNormalizedPos(hex.q, hex.r, MapConfig.HALF_Q, MapConfig.HALF_R)
				if HexMath.getCenterDistance(dx, dy, MapConfig.ISLAND_CENTERS) < 0.5 and hex.height > MapConfig.BEACH_HEIGHT then
					table.insert(candidates, hex)
				end
			end
		end

		if #candidates > 0 then
			local current = candidates[math.random(#candidates)]
			-- Carve
			for _ = 1, riverSteps do
				if not current or current.isRiver or current.isOcean then break end
				current.isRiver = true

				local bestN, bestScore = nil, math.huge
				for _, dir in ipairs(NEIGHBORS) do
					local n = getNeighbor(hexData, current.q, current.r, dir)
					if n and not n.isRiver and not n.isOcean and n.height < bestScore then
						bestScore = n.height
						bestN = n
					end
				end
				current = bestN
			end
		end
	end

	-- 4. Coastlines
	for _, hex in pairs(hexData) do
		if not hex.isOcean and not hex.isRiver then
			for _, dir in ipairs(NEIGHBORS) do
				local n = getNeighbor(hexData, hex.q, hex.r, dir)
				if n and (n.isOcean or n.isRiver) then
					hex.isCoast = true
					break
				end
			end
		end
	end

	-- 5. Hill Processing (The complex logic from original script)
	-- Mark Candidates
	for _, hex in pairs(hexData) do
		if not hex.isOcean and not hex.isRiver and not hex.isCoast then
			if hex.height > (MapConfig.HILL_LOW - 0.20) and hex.height < MapConfig.STONE_HEIGHT then
				hex.isHillCandidate = true
			end
		end
	end

	-- First pass
	for _, hex in pairs(hexData) do
		if hex.isHillCandidate then
			local neighborHillish = 0
			for _, dir in ipairs(NEIGHBORS) do
				local n = getNeighbor(hexData, hex.q, hex.r, dir)
				if n and not n.isOcean and not n.isRiver and not n.isCoast 
					and n.height > (MapConfig.HILL_LOW - 0.20) and n.height < MapConfig.STONE_HEIGHT then
					neighborHillish = neighborHillish + 1
				end
			end
			if neighborHillish >= 1 or hex.height > (MapConfig.HILL_LOW - 0.03) or math.random() < 0.40 then
				hex.isHill = true
			end
		end
	end

	-- Smoothing passes (Fill holes)
	for pass = 1, 2 do
		local toPromote = {}
		for _, hex in pairs(hexData) do
			if not hex.isOcean and not hex.isRiver and not hex.isCoast and not hex.isHill then
				local hillNeighbors = 0
				for _, dir in ipairs(NEIGHBORS) do
					local n = getNeighbor(hexData, hex.q, hex.r, dir)
					if n and n.isHill then hillNeighbors = hillNeighbors + 1 end
				end
				if hillNeighbors >= 4 then table.insert(toPromote, hex) end
			end
		end
		for _, hx in ipairs(toPromote) do
			hx.isHill = true
			if hx.height < MapConfig.HILL_LOW then hx.height = MapConfig.HILL_LOW + 0.01 end
		end
	end

	-- Classify Hill Types
	for _, hex in pairs(hexData) do
		if hex.isHill then
			if hex.height >= (MapConfig.HILL_HIGH + 0.05) then
				hex.isHighHill = true; hex.isPeakHill = true
			elseif hex.height >= MapConfig.HILL_HIGH or (hex.height >= MapConfig.HILL_LOW and math.random() < 0.5) then
				hex.isHighHill = true
			end
		end
	end

	-- 6. Final Assignment
	for _, hex in pairs(hexData) do
		if hex.isOcean or hex.isRiver then
			hex.biome = "WaterTile"; hex.hasTree = false
		elseif hex.isCoast then
			if hex.height > (MapConfig.OCEAN_HEIGHT + 0.03) and math.random() < 0.18 then
				hex.biome = "StoneTile"
			else
				hex.biome = "SandTile"
			end
			hex.hasTree = false
		elseif hex.height >= MapConfig.SNOWY_HEIGHT then
			hex.biome = "SnowyPeak1"; hex.hasTree = false; hex.isPeakHill = true
		elseif hex.height >= MapConfig.PEAK3_HEIGHT then
			hex.biome = "HexTileHillPeak3"; hex.hasTree = false; hex.isPeakHill = true
		elseif hex.height >= MapConfig.PEAK2_HEIGHT then
			hex.biome = "HexTileHillPeak2"; hex.hasTree = false; hex.isPeakHill = true
		elseif hex.height >= MapConfig.STONE_HEIGHT then
			hex.biome = "HexTileHillPeak"; hex.hasTree = false; hex.isPeakHill = true
		elseif hex.isHighHill then
			hex.biome = "HexTileHill2"; hex.hasTree = (math.random() < 0.4)
		elseif hex.isHill then
			hex.biome = "HexTileHill"; hex.hasTree = (math.random() < 0.45)
		else
			local b, t = getLandTypeFromHeight(hex.height)
			hex.biome = b; hex.hasTree = t
		end
	end

	return hexData
end

return MapGenerator