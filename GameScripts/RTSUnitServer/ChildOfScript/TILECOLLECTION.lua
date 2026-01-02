-- Modules/TILECOLLECTION.lua
return function(S)
	-- Section: TILE COLLECTION
	---------------------------------------------------------------------
	-- TILE COLLECTION 
	---------------------------------------------------------------------
	local TileIncludeList = { workspace.Terrain } 
	local TileSetReady = false

	local refreshTileIncludeList
	refreshTileIncludeList = function()
		TileIncludeList = { workspace.Terrain }
		for _, inst in ipairs(workspace:GetChildren()) do
			if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
				table.insert(TileIncludeList, inst)
			end
		end
		TileSetReady = (#TileIncludeList > 1)
	end
	S.refreshTileIncludeList = refreshTileIncludeList


	local rayToGround
	rayToGround = function(pos)
		if not TileSetReady then
			refreshTileIncludeList()
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = TileIncludeList
		params.IgnoreWater = true

		local origin = pos + Vector3.new(0, 250, 0)
		local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), params)
		if result then
			return result.Position
		end
		return pos
	end
	S.rayToGround = rayToGround


	local getHexTileFromWorld
	getHexTileFromWorld = function(pos)
		if not TileSetReady then
			refreshTileIncludeList()
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = TileIncludeList
		params.IgnoreWater = true

		local origin = pos + Vector3.new(0, 250, 0)
		local result = workspace:Raycast(origin, Vector3.new(0, -900, 0), params)
		if not result then return nil end

		local inst = result.Instance
		while inst do
			if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
				return inst
			end
			inst = inst.Parent
		end
		return nil
	end
	S.getHexTileFromWorld = getHexTileFromWorld


	local getTileTruePosition
	getTileTruePosition = function(tileModel)
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
	S.getTileTruePosition = getTileTruePosition


	local isForbiddenDestinationTile
	isForbiddenDestinationTile = function(tile)
		if not tile then return false end
		if tile:GetAttribute("IsWater") == true then
			return true
		end
		if tile:GetAttribute("IsWalkable") ~= true then
			return true
		end
		return false
	end
	S.isForbiddenDestinationTile = isForbiddenDestinationTile


	local snapCommandToTileCenter
	snapCommandToTileCenter = function(worldPos)
		local tile = getHexTileFromWorld(worldPos)
		if tile then
			if isForbiddenDestinationTile(tile) then
				return nil
			end
			return tile:GetPivot().Position
		end
		return worldPos
	end
	S.snapCommandToTileCenter = snapCommandToTileCenter


	-- Export locals (final values)
	S.TileIncludeList = TileIncludeList
	S.TileSetReady = TileSetReady
	return true
end