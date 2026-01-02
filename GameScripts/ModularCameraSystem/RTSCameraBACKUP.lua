local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local SetCameraFocus = Remotes:WaitForChild("SetCameraFocus")
-- [[ NEW: Get the CameraReturn BindableEvent ]]
local CameraReturn = Remotes:WaitForChild("CameraReturn") 

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

pcall(function()
	script.ResetOnSpawn = false
end)

---------------------------------------------------------------------
-- SETTINGS
---------------------------------------------------------------------
local MOVE_SPEED      = 90
local BOOST_SPEED     = 220
local ROT_SPEED       = 0.008
local MIN_ZOOM        = 20
local MAX_ZOOM        = 140
local ZOOM_SPEED      = 8
local MIN_PITCH       = math.rad(15)
local MAX_PITCH       = math.rad(80)

local ROT_SMOOTHNESS  = 18
local ZOOM_SMOOTHNESS = 18

-- Start view
local focusPos = Vector3.new(0, 0, 0)
local hasServerFocus = false

local yaw       = math.rad(45)
local pitch     = math.rad(55)
local zoom      = 80

-- Targets
local targetYaw   = yaw
local targetPitch = pitch
local targetZoom  = zoom

local TWO_PI = math.pi * 2

---------------------------------------------------------------------
-- INTERNAL STATE
---------------------------------------------------------------------
local rotating = false
local keysDown = { W=false, A=false, S=false, D=false, Shift=false }

local function clamp(x, a, b)
	return math.max(a, math.min(b, x))
end

local function expLerpAlpha(strength, dt)
	return 1 - math.exp(-strength * dt)
end

---------------------------------------------------------------------
-- DISABLE CONTROLS
---------------------------------------------------------------------
local function disableDefaultControls()
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and pm and pm.GetControls then
		local controls = pm:GetControls()
		if controls and controls.Disable then
			controls:Disable()
		end
	end
end

---------------------------------------------------------------------
-- HIDE CHARACTER
---------------------------------------------------------------------
local function hideAndFreezeCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.AutoRotate = false
		hum.PlatformStand = true
	end

	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end

	local function hideDesc(d)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			d.CastShadow = false
			d.CanCollide = false
		elseif d:IsA("Decal") then
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end

	for _, d in ipairs(char:GetDescendants()) do
		hideDesc(d)
	end

	char.DescendantAdded:Connect(hideDesc)
end

local function applyCharacterRules()
	local char = player.Character
	if not char then return end
	hideAndFreezeCharacter(char)
end

---------------------------------------------------------------------
-- CAMERA UPDATE
---------------------------------------------------------------------
local function ensureCamera()
	local current = workspace.CurrentCamera
	if current and current ~= camera then
		camera = current
	end
end

local function updateCamera(dt)
	ensureCamera()
	if not camera then return end

	camera.CameraType = Enum.CameraType.Scriptable

	targetPitch = clamp(targetPitch, MIN_PITCH, MAX_PITCH)
	targetZoom  = clamp(targetZoom,  MIN_ZOOM,  MAX_ZOOM)

	local aRot  = expLerpAlpha(ROT_SMOOTHNESS, dt)
	local aZoom = expLerpAlpha(ZOOM_SMOOTHNESS, dt)

	targetYaw = targetYaw % TWO_PI
	yaw = yaw % TWO_PI

	local dyaw = (targetYaw - yaw)
	if dyaw > math.pi then dyaw -= TWO_PI elseif dyaw < -math.pi then dyaw += TWO_PI end
	yaw += dyaw * aRot

	pitch += (targetPitch - pitch) * aRot
	zoom  += (targetZoom  - zoom)  * aZoom

	pitch = clamp(pitch, MIN_PITCH, MAX_PITCH)
	zoom  = clamp(zoom,  MIN_ZOOM,  MAX_ZOOM)

	local offsetDir = Vector3.new(
		math.cos(pitch) * math.sin(yaw),
		math.sin(pitch),
		math.cos(pitch) * math.cos(yaw)
	)

	local forwardFlat = Vector3.new(-offsetDir.X, 0, -offsetDir.Z)
	if forwardFlat.Magnitude < 1e-4 then forwardFlat = Vector3.new(0, 0, -1) else forwardFlat = forwardFlat.Unit end
	local rightFlat = Vector3.new(-forwardFlat.Z, 0, forwardFlat.X)

	local move = Vector3.zero
	if keysDown.W then move += forwardFlat end
	if keysDown.S then move -= forwardFlat end
	if keysDown.D then move += rightFlat end
	if keysDown.A then move -= rightFlat end

	local currentSpeed = keysDown.Shift and BOOST_SPEED or MOVE_SPEED

	if move.Magnitude > 0 then
		focusPos += move.Unit * currentSpeed * dt
	end

	local camPos = focusPos + offsetDir * zoom
	camera.CFrame = CFrame.new(camPos, focusPos)
end

---------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.W then keysDown.W = true end
	if input.KeyCode == Enum.KeyCode.A then keysDown.A = true end
	if input.KeyCode == Enum.KeyCode.S then keysDown.S = true end
	if input.KeyCode == Enum.KeyCode.D then keysDown.D = true end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		keysDown.Shift = true
	end

	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end)

UserInputService.InputEnded:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.W then keysDown.W = false end
	if input.KeyCode == Enum.KeyCode.A then keysDown.A = false end
	if input.KeyCode == Enum.KeyCode.S then keysDown.S = false end
	if input.KeyCode == Enum.KeyCode.D then keysDown.D = false end

	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		keysDown.Shift = false
	end

	if input.UserInputType == Enum.UserInputType.MouseButton3 then
		if rotating then
			rotating = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
end)

UserInputService.InputChanged:Connect(function(input, gp)
	if gp then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetZoom -= input.Position.Z * ZOOM_SPEED
		targetZoom = clamp(targetZoom, MIN_ZOOM, MAX_ZOOM)
	end
	if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
		local dx = input.Delta.X
		local dy = input.Delta.Y
		targetYaw   -= dx * ROT_SPEED
		targetPitch += dy * ROT_SPEED
		targetPitch = clamp(targetPitch, MIN_PITCH, MAX_PITCH)
	end
end)

---------------------------------------------------------------------
-- BOOTSTRAP
---------------------------------------------------------------------
-- 1. Initial Spawn from Server
SetCameraFocus.OnClientEvent:Connect(function(pos)
	if typeof(pos) == "Vector3" then
		focusPos = pos
		hasServerFocus = true
		-- Reset rotation on fresh spawn
		yaw = math.rad(45)
		targetYaw = yaw
	end
end)

-- 2. Button Click Listener (Fixes the Home Button)
CameraReturn.Event:Connect(function(pos)
	if typeof(pos) == "Vector3" then
		focusPos = pos
		hasServerFocus = true
	end
end)

local function init()
	ensureCamera()
	disableDefaultControls()

	if not hasServerFocus then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			focusPos = hrp.Position
		end
	end
	applyCharacterRules()
end

player.CharacterAdded:Connect(function()
	task.wait(0.1)
	disableDefaultControls()
	applyCharacterRules()
	if not hasServerFocus then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then focusPos = hrp.Position end
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ensureCamera)

init()
RunService.RenderStepped:Connect(updateCamera)