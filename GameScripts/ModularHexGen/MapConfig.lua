local MapConfig = {}

---------------------------------------------------------------------
-- MAP SETTINGS
---------------------------------------------------------------------
MapConfig.TILE_Y = 0
MapConfig.HALF_Q = 70      -- Horizontal Radius
MapConfig.HALF_R = 70      -- Vertical Radius
MapConfig.PACKING_FACTOR = 1.0

-- NOISE SETTINGS
-- (Seed is generated in Main and passed in, or set here)
MapConfig.NOISE_SCALE = 22
MapConfig.HEIGHT_SCALE = 2.20

-- HEIGHT THRESHOLDS
MapConfig.OCEAN_HEIGHT  = -0.23
MapConfig.BEACH_HEIGHT  = -0.02
MapConfig.HILL_LOW      =  0.28
MapConfig.HILL_HIGH     =  0.37
MapConfig.STONE_HEIGHT  =  0.48
MapConfig.PEAK2_HEIGHT  =  0.60
MapConfig.PEAK3_HEIGHT  =  0.72
MapConfig.SNOWY_HEIGHT  =  0.84

-- ISLAND SHAPE
MapConfig.ISLAND_CENTERS = {
	{ 0.0,  0.0},   -- center
	{-0.45, -0.1},  -- left-bottom
	{ 0.45,  0.2},  -- right-top
}
MapConfig.CENTER_RADIUS = 0.60
MapConfig.WARP_SCALE    = 0.7
MapConfig.WARP_STRENGTH = 1.0

-- RIVERS
MapConfig.NUM_RIVERS = 6
MapConfig.RIVER_STEPS_MULTIPLIER = 2 -- Used to calc steps based on map size

-- SPAWNING CHANCES
MapConfig.ROCK_SPAWN_CHANCE = 0.14
MapConfig.ROCK_MIN_PER_TILE = 1
MapConfig.ROCK_MAX_PER_TILE = 2
MapConfig.ROCK_SCATTER_FACTOR = 0.38 -- Relative to Hex Radius

MapConfig.TREE_CHANCE_GRASS = 0.55
MapConfig.TREE_OFFSET_Y = -6 -- From your script (TREE_EXTRA_Y)

return MapConfig