--// RTSController Modular Split
--// Health bar system
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)

local player = S.player
local unitsFolder = S.unitsFolder
local hpContainer = S.hpContainer
local HEALTH_BAR_SHOW_DIST = S.HEALTH_BAR_SHOW_DIST

---------------------------------------------------------------------
-- [[ NEW: HEALTH BAR SYSTEM ]]
---------------------------------------------------------------------
local healthBars = {} -- [unitModel] = { billboard=Instance, fill=Instance, hum=Humanoid }

-- [RTSController.lua] Replace createHealthBar
local function createHealthBar(target)
	if healthBars[target] then return end 

	local hum = target:FindFirstChildOfClass("Humanoid")
	local isBuilding = target:HasTag("RTSBuilding") or target:GetAttribute("IsBuilding")

	if not hum and not isBuilding then return end

	local pp = target.PrimaryPart or target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildWhichIsA("BasePart")
	if not pp then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "HPBar"
	bb.Adornee = pp
	bb.Size = isBuilding and UDim2.fromScale(6, 0.6) or UDim2.fromScale(2.8, 0.35) -- Bigger bars for buildings
	bb.StudsOffset = Vector3.new(0, isBuilding and 8 or 4.5, 0) -- Higher up for buildings
	bb.AlwaysOnTop = true
	bb.Enabled = false -- Hidden by default (until damaged)
	bb.Parent = hpContainer

	local bg = Instance.new("Frame")
	bg.Name = "BG"
	bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	bg.BorderSizePixel = 0
	bg.Size = UDim2.fromScale(1, 1)
	bg.Parent = bb

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Color3.fromRGB(50, 220, 50) 
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1) 
	fill.Parent = bg

	healthBars[target] = { billboard = bb, fill = fill, hum = hum, isBuilding = isBuilding }
end

local function removeHealthBar(unit)
	local data = healthBars[unit]
	if data then
		if data.billboard then data.billboard:Destroy() end
		healthBars[unit] = nil
	end
end

-- [[ UPDATED: Robust Loading Logic ]]
local function setupUnitVisuals(unit)
	task.spawn(function()
		-- 1. Explicitly wait for Humanoid (up to 10 seconds)
		local hum = unit:FindFirstChild("Humanoid")
		if not hum then
			hum = unit:WaitForChild("Humanoid", 10)
		end

		-- 2. Explicitly wait for Root Part
		local root = unit.PrimaryPart or unit:FindFirstChild("HumanoidRootPart")
		if not root then
			root = unit:WaitForChild("HumanoidRootPart", 10)
		end

		-- 3. Create only if we successfully found parts
		if hum and root then
			createHealthBar(unit)
		end
	end)
end

-- Listen for new units
unitsFolder.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		setupUnitVisuals(child)
	end
end)

unitsFolder.ChildRemoved:Connect(function(child)
	removeHealthBar(child)
end)

-- Initialize existing units (The ones already there when you join)
for _, u in ipairs(unitsFolder:GetChildren()) do
	if u:IsA("Model") then
		setupUnitVisuals(u)
	end
end



S.healthBars = healthBars
S.createHealthBar = createHealthBar
S.removeHealthBar = removeHealthBar
S.setupUnitVisuals = setupUnitVisuals

return true
