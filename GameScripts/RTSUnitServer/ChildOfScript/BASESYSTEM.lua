-- Modules/BASESYSTEM.lua
return function(S)
	-- Section: BASE SYSTEM
	-- Aliases from shared state
	local Players = S.Players
	local ReplicatedStorage = S.ReplicatedStorage
	local SetCameraFocus = S.SetCameraFocus
	local refreshTileIncludeList = S.refreshTileIncludeList

	---------------------------------------------------------------------
	-- BASE SYSTEM
	---------------------------------------------------------------------
	local BASE_TEMPLATE_PATH = {"RTSBases", "HexTilePlayerBase"}

	local BASE_MIN_DISTANCE = 140        
	local WATER_AVOID_RADIUS = 110       

	local PlayerBaseModel = {}           
	local TakenBasePositions = {}        

	local getBaseTemplate
	getBaseTemplate = function()
		local folder = ReplicatedStorage:FindFirstChild(BASE_TEMPLATE_PATH[1])
		if not folder then return nil end
		local m = folder:FindFirstChild(BASE_TEMPLATE_PATH[2])
		if m and m:IsA("Model") then
			return m
		end
		return nil
	end
	S.getBaseTemplate = getBaseTemplate


	local setFlagToPlayerAvatar
	setFlagToPlayerAvatar = function(baseModel, userId)
		local ok, thumb = pcall(function()
			return Players:GetUserThumbnailAsync(
				userId,
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size420x420
			)
		end)
		if not ok or not thumb then return end

		for _, d in ipairs(baseModel:GetDescendants()) do
			if d:IsA("Decal") then
				d.Texture = thumb
			elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
				d.Image = thumb
			end
		end
	end
	S.setFlagToPlayerAvatar = setFlagToPlayerAvatar


	local getAllHexTiles
	getAllHexTiles = function()
		local tiles = {}
		for _, inst in ipairs(workspace:GetChildren()) do
			if inst:IsA("Model") and string.match(inst.Name, "^Hex_%-?%d+_%-?%d+$") then
				table.insert(tiles, inst)
			end
		end
		return tiles
	end
	S.getAllHexTiles = getAllHexTiles


	local isWaterTile
	isWaterTile = function(tileModel)
		return tileModel:GetAttribute("IsWater") == true
	end
	S.isWaterTile = isWaterTile


	local isWalkableTile
	isWalkableTile = function(tileModel)
		return tileModel:GetAttribute("IsWalkable") == true
	end
	S.isWalkableTile = isWalkableTile


	local tooClose
	tooClose = function(posA, posB, dist)
		local a = Vector3.new(posA.X, 0, posA.Z)
		local b = Vector3.new(posB.X, 0, posB.Z)
		return (a - b).Magnitude < dist
	end
	S.tooClose = tooClose


	local pickValidBaseTile
	pickValidBaseTile = function()
		local tiles = getAllHexTiles()

		local candidates = {}
		local waterPositions = {}

		for _, t in ipairs(tiles) do
			local p = t:GetPivot().Position

			if isWaterTile(t) then
				table.insert(waterPositions, p)
			elseif isWalkableTile(t) then
				if t:GetAttribute("HasTree") ~= true then
					table.insert(candidates, t)
				end
			end
		end

		if #candidates == 0 then return nil end

		for _ = 1, 200 do
			local t = candidates[math.random(1, #candidates)]
			local p = t:GetPivot().Position

			local bad = false
			for _, used in ipairs(TakenBasePositions) do
				if tooClose(p, used, BASE_MIN_DISTANCE) then
					bad = true
					break
				end
			end
			if bad then
				continue
			end

			for _, wpos in ipairs(waterPositions) do
				if tooClose(p, wpos, WATER_AVOID_RADIUS) then
					bad = true
					break
				end
			end
			if bad then
				continue
			end

			return t
		end

		return candidates[1]
	end
	S.pickValidBaseTile = pickValidBaseTile


	local getModelBottomY
	getModelBottomY = function(model)
		local minY = math.huge
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local y = d.Position.Y - (d.Size.Y * 0.5)
				if y < minY then
					minY = y
				end
			end
		end
		return minY
	end
	S.getModelBottomY = getModelBottomY


	local BASE_NAMEPLATE_MAX_DISTANCE = 65
	local BASE_NAMEPLATE_OFFSET_Y = 10

	local setBaseOwnerNameplate
	setBaseOwnerNameplate = function(baseModel, ownerPlayer)
		local old = baseModel:FindFirstChild("RTS_BaseNameplate")
		if old then old:Destroy() end

		local adornee = baseModel:FindFirstChild("HexTileBase", true)
		if not (adornee and adornee:IsA("BasePart")) then
			adornee = baseModel:FindFirstChildWhichIsA("BasePart", true)
		end
		if not adornee then return end

		local bb = Instance.new("BillboardGui")
		bb.Name = "RTS_BaseNameplate"
		bb.Adornee = adornee
		bb.AlwaysOnTop = true
		bb.Size = UDim2.fromOffset(260, 50)
		bb.StudsOffset = Vector3.new(0, BASE_NAMEPLATE_OFFSET_Y, 0)
		bb.MaxDistance = BASE_NAMEPLATE_MAX_DISTANCE 
		bb.Parent = baseModel

		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromScale(1, 1)
		tl.TextScaled = true
		tl.Font = Enum.Font.GothamBold
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.35
		tl.Text = ownerPlayer.Name .. "'s Village"
		tl.Parent = bb
	end
	S.setBaseOwnerNameplate = setBaseOwnerNameplate


	local spawnPlayerBase
	spawnPlayerBase = function(plr)
		local template = getBaseTemplate()
		if not template then
			warn("RTSUnitServer: Missing base template ReplicatedStorage/RTSBases/HexTilePlayerBase")
			return nil
		end

		local baseTile = pickValidBaseTile()
		if not baseTile then
			warn("RTSUnitServer: Could not find a valid base tile.")
			return nil
		end

		local tileBasePart = baseTile:FindFirstChild("HexTileBase", true)
		local tileCF = tileBasePart and tileBasePart.CFrame or baseTile:GetPivot()
		local tileName = baseTile.Name
		local tileAttrs = baseTile:GetAttributes()

		local p = tileCF.Position
		local _, yaw, _ = tileCF:ToOrientation()

		local basePos = p
		table.insert(TakenBasePositions, basePos)

		baseTile:Destroy()

		local base = template:Clone()
		base.Name = tileName
		base.Parent = workspace

		for _, obj in ipairs(base:GetDescendants()) do
			if obj:IsA("BasePart") then
				obj.Anchored = true
			end
		end

		local desiredTileCF = CFrame.new(p) * CFrame.Angles(0, yaw, 0)

		do
			local hexPart = base:FindFirstChild("HexTileBase", true)
			if hexPart and hexPart:IsA("BasePart") then
				local pivotCF = base:GetPivot()
				local partRel = pivotCF:ToObjectSpace(hexPart.CFrame)
				local desiredPivot = desiredTileCF * partRel:Inverse()
				base:PivotTo(desiredPivot)
			else
				base:PivotTo(desiredTileCF)
			end
		end

		for k, v in pairs(tileAttrs) do
			base:SetAttribute(k, v)
		end

		base:SetAttribute("BaseOwnerUserId", plr.UserId)

		setFlagToPlayerAvatar(base, plr.UserId)
		setBaseOwnerNameplate(base, plr)

		plr:SetAttribute("RTS_BasePos", basePos)
		PlayerBaseModel[plr.UserId] = base

		SetCameraFocus:FireClient(plr, basePos)

		refreshTileIncludeList()

		return basePos
	end
	S.spawnPlayerBase = spawnPlayerBase



	-- Export locals (final values)
	S.BASE_MIN_DISTANCE = BASE_MIN_DISTANCE
	S.BASE_NAMEPLATE_MAX_DISTANCE = BASE_NAMEPLATE_MAX_DISTANCE
	S.BASE_NAMEPLATE_OFFSET_Y = BASE_NAMEPLATE_OFFSET_Y
	S.BASE_TEMPLATE_PATH = BASE_TEMPLATE_PATH
	S.PlayerBaseModel = PlayerBaseModel
	S.TakenBasePositions = TakenBasePositions
	S.WATER_AVOID_RADIUS = WATER_AVOID_RADIUS
	return true
end