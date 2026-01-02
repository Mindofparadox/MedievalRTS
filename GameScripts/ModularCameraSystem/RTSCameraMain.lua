local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Modules
local Config = require(script.Parent.CameraConfig)
local MathUtils = require(script.Parent.CameraMath)
local CharUtil = require(script.Parent.CharacterUtil)
local Input = require(script.Parent.InputController)

-- Remotes
local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local SetCameraFocus = Remotes:WaitForChild("SetCameraFocus")
local CameraReturn = Remotes:WaitForChild("CameraReturn")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

pcall(function() script.ResetOnSpawn = false end)

-- State
local focusPos = Vector3.new(0, 0, 0)
local hasServerFocus = false

local yaw   = Config.START_YAW
local pitch = Config.START_PITCH
local zoom  = Config.START_ZOOM

local targetYaw   = yaw
local targetPitch = pitch
local targetZoom  = zoom

local TWO_PI = math.pi * 2

---------------------------------------------------------------------
-- CAMERA UPDATE LOGIC
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

	-- 1. Clamp Targets
	targetPitch = MathUtils.clamp(targetPitch, Config.MIN_PITCH, Config.MAX_PITCH)
	targetZoom  = MathUtils.clamp(targetZoom,  Config.MIN_ZOOM,  Config.MAX_ZOOM)

	-- 2. Lerp Values
	local aRot  = MathUtils.expLerpAlpha(Config.ROT_SMOOTHNESS, dt)
	local aZoom = MathUtils.expLerpAlpha(Config.ZOOM_SMOOTHNESS, dt)

	-- 3. Handle Yaw Wrapping
	targetYaw = targetYaw % TWO_PI
	yaw = yaw % TWO_PI

	local dyaw = (targetYaw - yaw)
	if dyaw > math.pi then dyaw -= TWO_PI elseif dyaw < -math.pi then dyaw += TWO_PI end
	yaw += dyaw * aRot

	pitch += (targetPitch - pitch) * aRot
	zoom  += (targetZoom  - zoom)  * aZoom

	pitch = MathUtils.clamp(pitch, Config.MIN_PITCH, Config.MAX_PITCH)
	zoom  = MathUtils.clamp(zoom,  Config.MIN_ZOOM,  Config.MAX_ZOOM)

	-- 4. Calculate Vectors
	local offsetDir = MathUtils.calculateOffsetDir(pitch, yaw)
	local forwardFlat, rightFlat = MathUtils.calculateMoveVectors(offsetDir)

	-- 5. Movement Logic
	local move = Vector3.zero
	if Input.keysDown.W then move += forwardFlat end
	if Input.keysDown.S then move -= forwardFlat end
	if Input.keysDown.D then move += rightFlat end
	if Input.keysDown.A then move -= rightFlat end

	local currentSpeed = Input.keysDown.Shift and Config.BOOST_SPEED or Config.MOVE_SPEED

	if move.Magnitude > 0 then
		focusPos += move.Unit * currentSpeed * dt
	end

	-- 6. Apply CFrame
	local camPos = focusPos + offsetDir * zoom
	camera.CFrame = CFrame.new(camPos, focusPos)
end

---------------------------------------------------------------------
-- INPUT BINDINGS
---------------------------------------------------------------------
Input.OnZoom = function(deltaZ)
	targetZoom -= deltaZ * Config.ZOOM_SPEED
	targetZoom = MathUtils.clamp(targetZoom, Config.MIN_ZOOM, Config.MAX_ZOOM)
end

Input.OnRotate = function(dx, dy)
	targetYaw   -= dx * Config.ROT_SPEED
	targetPitch += dy * Config.ROT_SPEED
	targetPitch = MathUtils.clamp(targetPitch, Config.MIN_PITCH, Config.MAX_PITCH)
end

---------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------
local function init()
	ensureCamera()
	CharUtil.disableDefaultControls()

	if not hasServerFocus then
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			focusPos = hrp.Position
		end
	end

	if player.Character then
		CharUtil.hideAndFreeze(player.Character)
	end
end

-- Server Events
SetCameraFocus.OnClientEvent:Connect(function(pos)
	if typeof(pos) == "Vector3" then
		focusPos = pos
		hasServerFocus = true
		yaw = math.rad(45)
		targetYaw = yaw
	end
end)

CameraReturn.Event:Connect(function(pos)
	if typeof(pos) == "Vector3" then
		focusPos = pos
		hasServerFocus = true
	end
end)

-- Character Events
player.CharacterAdded:Connect(function(char)
	task.wait(0.1)
	CharUtil.disableDefaultControls()
	CharUtil.hideAndFreeze(char)
	if not hasServerFocus then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then focusPos = hrp.Position end
	end
end)

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(ensureCamera)

-- Start Input and Loop
Input.start()
init()
RunService.RenderStepped:Connect(updateCamera)