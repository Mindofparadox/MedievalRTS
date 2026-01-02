-- Modules/CONFIG.lua
return function(S)
	-- Section: CONFIG
	-- Aliases from shared state
	local CommandPlaceBuilding = S.CommandPlaceBuilding

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

	local getPlayerPopulation
	getPlayerPopulation = function(plr)
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

		-- 2. Count Pop-Cost Buildings (Farms, Sawmills, etc.)
		-- IMPORTANT: We count them immediately on placement (even if UnderConstruction),
		-- because placement already reserves population via PopCost checks.
		for _, b in ipairs(workspace:GetChildren()) do
			if b:IsA("Model") and b:GetAttribute("OwnerUserId") == plr.UserId then
				local bType = b:GetAttribute("BuildingType")
				local bStats = BUILDING_STATS[bType]
				local popCost = bStats and bStats.PopCost

				if popCost then
					count = count + popCost
				else
					-- Backward/legacy aliases (in case your client calls it "WoodMill")
					if bType == "WoodMill" or bType == "Woodmill" then
						count = count + 5
					end
				end
			end
		end

		return count
	end
	S.getPlayerPopulation = getPlayerPopulation

	-- Default Attack Animation (R6 Slash)
	-- [REPLACE DEFAULT_ATTACK_ANIM WITH THIS TABLE]
	local ATTACK_ANIMS = {
		"rbxassetid://99522595035363",
		"rbxassetid://134315501581444",
		"rbxassetid://138535139242491",
		"rbxassetid://100832261779703"
	}

	local EDGE_JUMP_RADIUS = 2.8   

	-- Export locals (final values)
	S.ARRIVE_RADIUS = ARRIVE_RADIUS
	S.ATTACK_ANIMS = ATTACK_ANIMS
	S.BUILDING_STATS = BUILDING_STATS
	S.BUILDING_TAG = BUILDING_TAG
	S.EDGE_JUMP_RADIUS = EDGE_JUMP_RADIUS
	S.MAX_STEP_UP = MAX_STEP_UP
	S.PATH_AGENT = PATH_AGENT
	S.TILE_STEP = TILE_STEP
	S.TOWER_RANGED_RANGE_BONUS = TOWER_RANGED_RANGE_BONUS
	S.UNIT_TAG = UNIT_TAG
	S.UNIT_TYPES = UNIT_TYPES
	S.WALK_SPEED = WALK_SPEED
	return true
end