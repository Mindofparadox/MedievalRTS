--// RTSController Modular Split
--// Helpers (raycasts, hover targeting, bezier, utility)
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)

local Players = S.Players
local UserInputService = S.UserInputService
local RunService = S.RunService
local ReplicatedStorage = S.ReplicatedStorage
local CollectionService = S.CollectionService

local player = S.player
local mouse = S.mouse
local unitsFolder = S.unitsFolder

local getIgnoreList = S.getIgnoreList

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function getUnitId(model)
	return model:GetAttribute("UnitId")
end

local function quadBezier(t, p0, p1, p2)
	local l1 = p0:Lerp(p1, t)
	local l2 = p1:Lerp(p2, t)
	return l1:Lerp(l2, t)
end

local function updateBuildingFire(model, healthPct)
	local firePart = model:FindFirstChild("FireEffectPart")

	if healthPct < 0.4 and healthPct > 0 and not model:GetAttribute("IsDead") then
		if not firePart then
			firePart = Instance.new("Part")
			firePart.Name = "FireEffectPart"
			firePart.Transparency = 1
			firePart.CanCollide = false
			firePart.Anchored = true
			firePart.Size = Vector3.new(1,1,1)

			firePart.CFrame = CFrame.new(model:GetPivot().Position + Vector3.new(0, 5, 0))
			firePart.Parent = model

			local fire = Instance.new("Fire")
			fire.Size = 12
			fire.Heat = 20
			fire.Parent = firePart

			local smoke = Instance.new("Smoke")
			smoke.Opacity = 0.4
			smoke.RiseVelocity = 15
			smoke.Size = 8
			smoke.Parent = firePart
		end
	else
		if firePart then firePart:Destroy() end
	end
end

local function isOwnedUnit(model)
	return model:GetAttribute("OwnerUserId") == player.UserId
end

local function getUnitType(model)
	return model:GetAttribute("UnitType") or model.Name
end

local function clamp2(a, b)
	return Vector2.new(math.min(a.X, b.X), math.min(a.Y, b.Y)), Vector2.new(math.max(a.X, b.X), math.max(a.Y, b.Y))
end

local function pointInRect(p, a, b)
	local minV, maxV = clamp2(a, b)
	return p.X >= minV.X and p.X <= maxV.X and p.Y >= minV.Y and p.Y <= maxV.Y
end

local function getModelScreenPos(model)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local pp = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
	if not pp then return nil end
	local v, onScreen = cam:WorldToViewportPoint(pp.Position)
	if not onScreen then return nil end
	return Vector2.new(v.X, v.Y)
end

---------------------------------------------------------------------
-- Stone normalization (mirrors tree “model-level” behavior)
---------------------------------------------------------------------
local function normalizeStoneModel(model)
	if not model then return nil end
	local resFolder = workspace:FindFirstChild("ResourceNodes")

	local stoneModel = model
	while stoneModel do
		if stoneModel:GetAttribute("IsRTSStone") == true
			or CollectionService:HasTag(stoneModel, "RTSStone")
			or (resFolder and stoneModel:IsDescendantOf(resFolder) and string.match(stoneModel.Name, "^Rock_")) then
			return stoneModel
		end

		-- climb to next ancestor Model
		local p = stoneModel.Parent
		while p and not p:IsA("Model") do
			p = p.Parent
		end
		stoneModel = p
	end

	return nil
end

---------------------------------------------------------------------
-- Target identification (Unit / Tree / Stone / Building / Tile)
---------------------------------------------------------------------
local function identifyTarget(model)
	if not model then return nil end
	if model.Parent == unitsFolder then return "Unit" end

	-- Trees (same logic style as original)
	if model:GetAttribute("IsRTSTree") == true
		or CollectionService:HasTag(model, "RTSTree")
		or model.Name == "Tree" then
		return "Tree"
	end

	-- Stones (mineable): accept top-level Rock_ inside ResourceNodes (or explicit attr/tag)
	do
		local stoneRoot = normalizeStoneModel(model)
		if stoneRoot then
			return "Stone"
		end
	end

	-- Buildings
	if CollectionService:HasTag(model, "RTSBuilding") or model:GetAttribute("IsBuilding") then
		return "Building"
	end

	-- Hex tiles
	if string.match(model.Name, "^Hex_%-?%d+_%-?%d+$") then
		return "Tile"
	end

	return nil
end

local function getHoverTarget()
	local target = mouse.Target
	if not target then return nil, nil end

	local model = target:FindFirstAncestorOfClass("Model")
	if not model then return nil, nil end

	local typeFound = identifyTarget(model)
	if not typeFound then return nil, nil end

	-- For stones, always return the normalized Rock_* model so mark/mine works
	if typeFound == "Stone" then
		return normalizeStoneModel(model) or model, typeFound
	end

	return model, typeFound
end

---------------------------------------------------------------------
-- Mouse queries
---------------------------------------------------------------------
local function getUnitUnderMouse()
	local model, typeStr = getHoverTarget()
	if model and typeStr == "Unit" and isOwnedUnit(model) then
		return model
	end
	return nil
end

local function getTreeUnderMouse()
	local model, typeStr = getHoverTarget()
	if model and typeStr == "Tree" then
		return model
	end
	return nil
end

local function getStoneUnderMouse()
	local model, typeStr = getHoverTarget()
	if model and typeStr == "Stone" then
		return normalizeStoneModel(model) or model
	end
	return nil
end

local function findUnitById(unitId)
	for _, model in ipairs(unitsFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("UnitId") == unitId then
			return model
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Raycast helper: find the Hex_ tile position under the mouse
---------------------------------------------------------------------
local function getMouseWorldHit()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local ml = UserInputService:GetMouseLocation()
	local viewRay = cam:ViewportPointToRay(ml.X, ml.Y)

	local baseIgnore = getIgnoreList() or {}
	local ignore = {}
	for i = 1, #baseIgnore do ignore[i] = baseIgnore[i] end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true

	for _ = 1, 12 do
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(viewRay.Origin, viewRay.Direction * 5000, params)
		if not hit or not hit.Instance then
			return nil
		end

		local inst = hit.Instance
		local model = inst:FindFirstAncestorOfClass("Model")
		if model and string.match(model.Name, "^Hex_%-?%d+_%-?%d+$") then
			return hit.Position
		end

		if model then
			table.insert(ignore, model)
		else
			table.insert(ignore, inst)
		end
	end

	return nil
end

---------------------------------------------------------------------
-- Export helper functions used by other modules
---------------------------------------------------------------------
S.getUnitId = getUnitId
S.quadBezier = quadBezier
S.updateBuildingFire = updateBuildingFire
S.isOwnedUnit = isOwnedUnit
S.getUnitType = getUnitType
S.clamp2 = clamp2
S.pointInRect = pointInRect
S.getModelScreenPos = getModelScreenPos
S.identifyTarget = identifyTarget
S.getHoverTarget = getHoverTarget
S.getUnitUnderMouse = getUnitUnderMouse
S.getTreeUnderMouse = getTreeUnderMouse
S.getStoneUnderMouse = getStoneUnderMouse
S.findUnitById = findUnitById
S.getMouseWorldHit = getMouseWorldHit
S.normalizeStoneModel = normalizeStoneModel

return true
