local MapConfig = require(script.Parent.MapConfig)
local MapGenerator = require(script.Parent.MapGenerator)
local MapRenderer = require(script.Parent.MapRenderer)

local SEED = math.random(1, 1000000000)
print("Generating Map with Seed:", SEED)

-- 1. Calculate physical size based on assets
local hexRadius = MapRenderer.calculateHexRadius()

-- 2. Generate pure data (Math & Logic)
local hexData = MapGenerator.generateData(SEED, hexRadius)

-- 3. Render the map (Visuals)
MapRenderer.spawnMap(hexData, hexRadius)