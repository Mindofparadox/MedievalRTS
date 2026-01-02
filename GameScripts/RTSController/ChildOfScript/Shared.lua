--// RTSController Modular Split
--// Shared state + services + remotes + config
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = {} :: any

--// StarterPlayerScripts / RTSController.lua
--// Selection, Command Move, Path Visuals, Hover Highlights, AND HEALTH BARS

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local CommandMove = Remotes:WaitForChild("CommandMove")
local CommandGarrisonTower = Remotes:WaitForChild("CommandGarrisonTower")
local PathUpdate = Remotes:WaitForChild("PathUpdate")
local CommandChopTree = Remotes:WaitForChild("CommandChopTree")
local CommandCancel = Remotes:WaitForChild("CommandCancel")
local ToggleTreeMark = Remotes:WaitForChild("ToggleTreeMark")
local CommandMineStone = Remotes:WaitForChild("CommandMineStone")
local ToggleStoneMark  = Remotes:WaitForChild("ToggleStoneMark")
local RecruitUnit = Remotes:WaitForChild("RecruitUnit")
local UpdateBaseQueue = Remotes:WaitForChild("UpdateBaseQueue")
local CommandPlaceBuilding = Remotes:WaitForChild("CommandPlaceBuilding") -- Ensure this exists
local VisualEffect = Remotes:WaitForChild("VisualEffect")
local DeleteUnit = Remotes:WaitForChild("DeleteUnit")


local unitsFolder = workspace:WaitForChild("RTSUnits")
local startPlacement, cancelPlacement, updateGhost

-- [[ PLACEMENT STATE ]]
S.isPlacing = false
S.placementGhost = nil
S.recruitConnection = nil -- Store the button connection here
S.placementName = nil
S.placementRotation = 0 -- 0 to 5
S.placementOffset = CFrame.new()
S.currentSelectedBuilding = nil -- Global tracker for the script

-- [[ 1. NEW HELPER FUNCTION ]] --
local function getIgnoreList()
	local list = { S.unitsFolder }

	-- Ignore the building ghost itself
	if S.placementGhost then
		table.insert(list, S.placementGhost)
	end

	-- Ignore Decorative Grass so we can click "through" it
	local decor = workspace:FindFirstChild("RTS_Decor")
	if decor then table.insert(list, decor) end

	-- Ignore Resource Nodes (Rocks) so we snap to the ground
	local res = workspace:FindFirstChild("ResourceNodes")
	if res then table.insert(list, res) end

	return list
end
---------------------------------------------------------------------
-- CONFIG
---------------------------------------------------------------------
local BUILDER_RANGE = 18 
local HEALTH_BAR_SHOW_DIST = 60 -- Distance to show health bars


-- [[ NEW: RESPONSIVE SCALING FUNCTION ]] --
local function makeResponsive(frame)
	local uiScale = Instance.new("UIScale")
	uiScale.Parent = frame

	local function update()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize

		-- 1. Base Scale on Height (Target: 900px height standard)
		local targetHeight = 900
		local scale = math.clamp(vp.Y / targetHeight, 0.6, 1.3)

		-- 2. Width Constraint (Ensure it never exceeds screen width)
		-- We use the frame's offset width to check if it fits
		local frameWidth = frame.Size.X.Offset
		if frameWidth > 0 then
			local maxScale = (vp.X * 0.9) / frameWidth -- Keep 90% screen width max
			if scale > maxScale then
				scale = maxScale
			end
		end

		uiScale.Scale = scale
	end

	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end



-- Export shared references so other modules can read/write the same state
S.Players = Players
S.UserInputService = UserInputService
S.RunService = RunService
S.ReplicatedStorage = ReplicatedStorage
S.CollectionService = CollectionService

S.player = player
S.mouse = mouse

S.Remotes = Remotes
S.CommandMove = CommandMove
S.CommandGarrisonTower = CommandGarrisonTower
S.PathUpdate = PathUpdate
S.CommandChopTree = CommandChopTree
S.CommandCancel = CommandCancel
S.ToggleTreeMark = ToggleTreeMark
S.CommandMineStone = CommandMineStone
S.ToggleStoneMark = ToggleStoneMark
S.RecruitUnit = RecruitUnit
S.UpdateBaseQueue = UpdateBaseQueue
S.CommandPlaceBuilding = CommandPlaceBuilding
S.VisualEffect = VisualEffect
S.DeleteUnit = DeleteUnit

S.unitsFolder = unitsFolder
S.getIgnoreList = getIgnoreList

S.BUILDER_RANGE = BUILDER_RANGE
S.HEALTH_BAR_SHOW_DIST = HEALTH_BAR_SHOW_DIST
S.makeResponsive = makeResponsive

-- Forward-defined functions (filled in later by Main module)
S.startPlacement = S.startPlacement
S.cancelPlacement = S.cancelPlacement
S.updateGhost = S.updateGhost

return S