-- Modules/REMOTES.lua
return function(S)
	-- Section: REMOTES
	-- Aliases from shared state
	local ReplicatedStorage = S.ReplicatedStorage

	---------------------------------------------------------------------
	-- REMOTES
	---------------------------------------------------------------------
	local Remotes = ReplicatedStorage:FindFirstChild("RTSRemotes")
	if not Remotes then
		Remotes = Instance.new("Folder")
		Remotes.Name = "RTSRemotes"
		Remotes.Parent = ReplicatedStorage
	end
	-- [[ INSERT AT THE VERY TOP OF RTSUnitServer.lua ]]
	local PhysicsService = game:GetService("PhysicsService")

	local RTS_UNIT_GROUP = "RTSUnitGroup"
	local setupCollisionGroups
	setupCollisionGroups = function()
		local success, err = pcall(function()
			-- Create the group
			PhysicsService:RegisterCollisionGroup(RTS_UNIT_GROUP)
			-- Tell the group NOT to collide with itself
			PhysicsService:CollisionGroupSetCollidable(RTS_UNIT_GROUP, RTS_UNIT_GROUP, false)
		end)
	end
	S.setupCollisionGroups = setupCollisionGroups

	setupCollisionGroups()

	local getOrCreateRemote
	getOrCreateRemote = function(name)
		local r = Remotes:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = Remotes
		end
		return r
	end
	S.getOrCreateRemote = getOrCreateRemote


	local CommandMove = getOrCreateRemote("CommandMove")
	local CommandGarrisonTower = getOrCreateRemote("CommandGarrisonTower")
	local CommandChopTree = getOrCreateRemote("CommandChopTree")
	local ToggleTreeMark = getOrCreateRemote("ToggleTreeMark")
	local CommandMineStone = getOrCreateRemote("CommandMineStone")
	local ToggleStoneMark  = getOrCreateRemote("ToggleStoneMark")
	local SetBuilderAuto = getOrCreateRemote("SetBuilderAuto")
	local PathUpdate  = getOrCreateRemote("PathUpdate")
	local SetCameraFocus = getOrCreateRemote("SetCameraFocus")
	local CommandCancel = getOrCreateRemote("CommandCancel")
	local DeleteUnit = getOrCreateRemote("DeleteUnit")
	local UpdateBaseQueue = getOrCreateRemote("UpdateBaseQueue")
	local CommandPlaceBuilding = getOrCreateRemote("CommandPlaceBuilding")
	local RecruitUnit = getOrCreateRemote("RecruitUnit")
	local VisualEffect = getOrCreateRemote("VisualEffect") -- New remote for damage numbers/sounds
	local ClientNotify = getOrCreateRemote("ClientNotify") -- Client-side popups (errors/warnings)
	local HttpService = game:GetService("HttpService") -- [[ ADDED THIS ]]

	---------------------------------------------------------------------
	-- [[ NEW: SKIN COLOR PALETTE ]]
	---------------------------------------------------------------------
	local SKIN_TONES = {
		Color3.fromRGB(255, 224, 189), -- Light
		Color3.fromRGB(255, 205, 148),
		Color3.fromRGB(234, 192, 134),
		Color3.fromRGB(255, 173, 96),
		Color3.fromRGB(224, 172, 105),
		Color3.fromRGB(198, 134, 66),
		Color3.fromRGB(141, 85, 36),   -- Medium Dark
		Color3.fromRGB(117, 65, 33),
		Color3.fromRGB(92, 58, 33),
		Color3.fromRGB(60, 34, 20),    -- Dark
	}

	local randomizeSkin
	randomizeSkin = function(unitModel)
		local skinColor = SKIN_TONES[math.random(1, #SKIN_TONES)]

		local bc = unitModel:FindFirstChildOfClass("BodyColors")
		if bc then
			bc.HeadColor3 = skinColor
			bc.LeftArmColor3 = skinColor
			bc.RightArmColor3 = skinColor
			bc.LeftLegColor3 = skinColor
			bc.RightLegColor3 = skinColor
			bc.TorsoColor3 = skinColor
		end

		for _, part in ipairs(unitModel:GetChildren()) do
			if part:IsA("BasePart") then
				if part.Name == "Head" or part.Name == "Torso" 
					or string.match(part.Name, "Arm") 
					or string.match(part.Name, "Leg") then
					part.Color = skinColor
				end
			end
		end
	end
	S.randomizeSkin = randomizeSkin

	local CameraReturn = Remotes:FindFirstChild("CameraReturn")
	if not CameraReturn then
		CameraReturn = Instance.new("BindableEvent")
		CameraReturn.Name = "CameraReturn"
		CameraReturn.Parent = Remotes
	end

	-- Export locals (final values)
	S.CameraReturn = CameraReturn
	S.CommandCancel = CommandCancel
	S.CommandChopTree = CommandChopTree
	S.CommandGarrisonTower = CommandGarrisonTower
	S.CommandMove = CommandMove
	S.CommandPlaceBuilding = CommandPlaceBuilding
	S.DeleteUnit = DeleteUnit
	S.HttpService = HttpService
	S.PathUpdate = PathUpdate
	S.PhysicsService = PhysicsService
	S.RTS_UNIT_GROUP = RTS_UNIT_GROUP
	S.RecruitUnit = RecruitUnit
	S.Remotes = Remotes
	S.SKIN_TONES = SKIN_TONES
	S.SetCameraFocus = SetCameraFocus
	S.ToggleTreeMark = ToggleTreeMark
	S.UpdateBaseQueue = UpdateBaseQueue
	S.VisualEffect = VisualEffect
	S.ClientNotify = ClientNotify
	S.CommandMineStone = CommandMineStone
	S.ToggleStoneMark = ToggleStoneMark
	S.SetBuilderAuto = SetBuilderAuto
	return true
end