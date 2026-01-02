-- Modules/UNITTEMPLATE.lua
return function(S)
	-- Section: UNIT TEMPLATE
	-- Aliases from shared state
	local CollectionService = S.CollectionService
	local RTS_UNIT_GROUP = S.RTS_UNIT_GROUP
	local ReplicatedStorage = S.ReplicatedStorage
	local UNIT_TAG = S.UNIT_TAG
	local WALK_SPEED = S.WALK_SPEED

	---------------------------------------------------------------------
	-- UNIT TEMPLATE
	---------------------------------------------------------------------
	local getUnitTemplate
	getUnitTemplate = function()
		local units = ReplicatedStorage:FindFirstChild("Units")
		if not units then return nil end
		local builder = units:FindFirstChild("Builder")
		if builder and builder:IsA("Model") then
			return builder
		end
		return nil
	end
	S.getUnitTemplate = getUnitTemplate


	-- [RTSUnitServer.lua] New Helper to handle unit death consistently
	local setupUnitDeath
	setupUnitDeath = function(unit, ownerPlayer)
		local hum = unit:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		hum.Died:Connect(function()
			if unit:GetAttribute("IsDead") then return end
			unit:SetAttribute("IsDead", true)

			-- 1. Remove from Population immediately
			-- We do this by parenting it out of the RTSUnits folder
			unit.Parent = workspace 

			-- 2. Disable Logic
			unit:SetAttribute("OwnerUserId", nil)
			CollectionService:RemoveTag(unit, UNIT_TAG)

			-- 3. Visual Cleanup
			local np = unit:FindFirstChild("RTS_Nameplate")
			if np then np:Destroy() end

			-- 4. Physics Cleanup (Freeze bodies so they don't lag)
			for _, p in ipairs(unit:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.Anchored = true 
				end
			end

			-- 5. Delete after short delay
			task.delay(1.5, function()
				if unit then unit:Destroy() end
			end)
		end)
	end
	S.setupUnitDeath = setupUnitDeath


	local ensurePrimaryPart
	ensurePrimaryPart = function(model)
		if model.PrimaryPart then return model.PrimaryPart end
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			model.PrimaryPart = hrp
			return hrp
		end
		local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
		if anyPart then
			model.PrimaryPart = anyPart
			return anyPart
		end
		return nil
	end
	S.ensurePrimaryPart = ensurePrimaryPart




	---------------------------------------------------------------------
	-- DEFAULT R6 ANIMS (server-side fallback)
	---------------------------------------------------------------------
	local DEFAULT_R6_IDLE_ANIM_ID = "rbxassetid://180435571"
	local DEFAULT_R6_WALK_ANIM_ID = "rbxassetid://180426354"
	local DEFAULT_R6_CHOP_ANIM_ID = "rbxassetid://114317758495104"

	local UnitAnim = {} 
	local UnreachableCache = {}

	local ensureDefaultR6Anims
	ensureDefaultR6Anims = function(unitModel)
		local animInst = unitModel:FindFirstChild("Animate")
		if animInst and (animInst:IsA("Script") or animInst:IsA("LocalScript")) then
			animInst.Disabled = true
		end

		local hum = unitModel:FindFirstChildOfClass("Humanoid")
		if not hum then return end

		if UnitAnim[unitModel] then return end

		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end

		local idleAnim = Instance.new("Animation")
		idleAnim.AnimationId = DEFAULT_R6_IDLE_ANIM_ID

		local walkAnim = Instance.new("Animation")
		walkAnim.AnimationId = DEFAULT_R6_WALK_ANIM_ID

		local idleTrack = animator:LoadAnimation(idleAnim)
		idleTrack.Priority = Enum.AnimationPriority.Idle
		idleTrack.Looped = true

		local walkTrack = animator:LoadAnimation(walkAnim)
		walkTrack.Priority = Enum.AnimationPriority.Movement
		walkTrack.Looped = true

		idleTrack:Play(0.1)

		local conns = {}

		conns.running = hum.Running:Connect(function(speed)
			if speed > 0.1 then
				if idleTrack.IsPlaying then idleTrack:Stop(0.15) end
				if not walkTrack.IsPlaying then walkTrack:Play(0.1) end
				walkTrack:AdjustSpeed(math.clamp(speed / WALK_SPEED, 0.8, 1.6))
			else
				if walkTrack.IsPlaying then walkTrack:Stop(0.15) end
				if not idleTrack.IsPlaying then idleTrack:Play(0.1) end
			end
		end)

		conns.state = hum.StateChanged:Connect(function(_, newState)
			if newState == Enum.HumanoidStateType.Jumping
				or newState == Enum.HumanoidStateType.Freefall
				or newState == Enum.HumanoidStateType.FallingDown
				or newState == Enum.HumanoidStateType.Climbing
			then
				if walkTrack.IsPlaying then walkTrack:Stop(0.1) end
			end
		end)

		UnitAnim[unitModel] = { idle = idleTrack, walk = walkTrack, conns = conns }
	end
	S.ensureDefaultR6Anims = ensureDefaultR6Anims



	local setUnitWalking
	setUnitWalking = function(unitModel, walking, speedMul)
		ensureDefaultR6Anims(unitModel)

		local pack = UnitAnim[unitModel]
		if not pack then return end

		speedMul = speedMul or 1

		if walking then
			if pack.idle and pack.idle.IsPlaying then
				pack.idle:Stop(0.12)
			end
			if pack.walk and (not pack.walk.IsPlaying) then
				pack.walk:Play(0.08)
			end
			if pack.walk then
				pack.walk:AdjustSpeed(speedMul)
			end
		else
			if pack.walk and pack.walk.IsPlaying then
				pack.walk:Stop(0.12)
			end
			if pack.idle and (not pack.idle.IsPlaying) then
				pack.idle:Play(0.08)
			end
		end
	end
	S.setUnitWalking = setUnitWalking


	local playChopAnimation
	playChopAnimation = function(unitModel)
		local hum = unitModel:FindFirstChildOfClass("Humanoid")
		if not hum then return nil end

		local animator = hum:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = hum
		end

		local anim = Instance.new("Animation")
		anim.AnimationId = DEFAULT_R6_CHOP_ANIM_ID

		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action 
		track.Looped = true
		track:Play()

		return track
	end
	S.playChopAnimation = playChopAnimation


	-- [[ REPLACE YOUR EXISTING prepUnitForWorld FUNCTION WITH THIS ]]
	local prepUnitForWorld
	prepUnitForWorld = function(unitModel)
		for _, d in ipairs(unitModel:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				-- [[ FIX 1: Apply Collision Group ]]
				d.CollisionGroup = RTS_UNIT_GROUP
			end
		end

		local root = ensurePrimaryPart(unitModel)
		local hum = unitModel:FindFirstChildOfClass("Humanoid")

		if hum then
			hum.BreakJointsOnDeath = false -- keep body from scattering into parts
			hum.WalkSpeed = 12 -- Slightly faster for responsiveness
			hum.AutoRotate = true

			-- [[ FIX 2: Optimize Physics ]]
			-- Disable expensive states
			hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			hum:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)

			-- Make unit lighter (mass 1) to prevent physics heavy interactions
			if root then 
				root.CustomPhysicalProperties = PhysicalProperties.new(1, 0.3, 0.5, 1, 1) 
			end
		end

		ensureDefaultR6Anims(unitModel)
	end
	S.prepUnitForWorld = prepUnitForWorld


	local possessiveName
	possessiveName = function(name)
		local last = string.sub(name, -1)
		if string.lower(last) == "s" then
			return name .. "'"
		end
		return name .. "'s"
	end
	S.possessiveName = possessiveName


	local setUnitNameplate
	setUnitNameplate = function(unitModel, ownerName, unitType)
		local old = unitModel:FindFirstChild("RTS_Nameplate")
		if old then old:Destroy() end

		local head = unitModel:FindFirstChild("Head", true)
		local adornee = (head and head:IsA("BasePart")) and head or ensurePrimaryPart(unitModel)
		if not adornee then return end

		local bb = Instance.new("BillboardGui")
		bb.Name = "RTS_Nameplate"
		bb.Adornee = adornee
		bb.AlwaysOnTop = true

		bb.Size = UDim2.fromOffset(120, 18)    
		bb.StudsOffset = Vector3.new(0, 3.2, 0) 
		bb.MaxDistance = 55 

		bb.Parent = unitModel

		local tl = Instance.new("TextLabel")
		tl.BackgroundTransparency = 1
		tl.Size = UDim2.fromScale(1, 1)

		tl.TextScaled = false
		tl.TextSize = 10 
		tl.Font = Enum.Font.GothamBold
		tl.TextColor3 = Color3.new(1, 1, 1)
		tl.TextStrokeTransparency = 0.35
		tl.Text = ("%s %s"):format(possessiveName(ownerName), unitType)
		tl.Parent = bb
	end
	S.setUnitNameplate = setUnitNameplate



	-- Export locals (final values)
	S.DEFAULT_R6_CHOP_ANIM_ID = DEFAULT_R6_CHOP_ANIM_ID
	S.DEFAULT_R6_IDLE_ANIM_ID = DEFAULT_R6_IDLE_ANIM_ID
	S.DEFAULT_R6_WALK_ANIM_ID = DEFAULT_R6_WALK_ANIM_ID
	S.UnitAnim = UnitAnim
	S.UnreachableCache = UnreachableCache
	return true
end