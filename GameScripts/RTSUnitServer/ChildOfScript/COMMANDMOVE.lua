-- Modules/COMMANDMOVE.lua
return function(S)
	-- Section: COMMAND MOVE
	-- Aliases from shared state
	local CollectionService = S.CollectionService
	local Players = S.Players
	local UNIT_TAG = S.UNIT_TAG
	local refreshTileIncludeList = S.refreshTileIncludeList
	local unitsFolder = S.unitsFolder

	---------------------------------------------------------------------
	-- COMMAND MOVE
	---------------------------------------------------------------------
	local buildIdMapForPlayer
	buildIdMapForPlayer = function(plr)
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
	S.buildIdMapForPlayer = buildIdMapForPlayer


	---------------------------------------------------------------------
	-- HELPER: Finalize Construction (UPDATED POPULATION LOGIC)
	---------------------------------------------------------------------
	local finalizeConstruction
	finalizeConstruction = function(buildingModel)
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
	S.finalizeConstruction = finalizeConstruction

	return true
end