-- StarterPlayerScripts / RTSCurrencyGui.lua (LocalScript)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage") 

local player = Players.LocalPlayer

local Remotes = ReplicatedStorage:WaitForChild("RTSRemotes")
local CameraReturn = Remotes:WaitForChild("CameraReturn") 

local unitsFolder = workspace:WaitForChild("RTSUnits")

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "RTSCurrencyGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "ResourceFrame"
frame.AnchorPoint = Vector2.new(1, 0)
frame.Position = UDim2.new(1, -14, 0, 14)
frame.Size = UDim2.new(0, 210, 0, 130)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BackgroundTransparency = 0.15


local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 90)
stroke.Transparency = 0.4
stroke.Thickness = 1
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = frame
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Left
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 4)
list.Parent = frame

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 10)
padding.PaddingRight = UDim.new(0, 10)
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 8)
padding.Parent = frame

local IconFolder = ReplicatedStorage:FindFirstChild("ResourceIcons")

local function iconFromDecal(key: string): string
	if not IconFolder then return "" end
	local d = IconFolder:FindFirstChild(key)
	if d and d:IsA("Decal") then
		return d.Texture or ""
	end
	return ""
end

local RESOURCE_DEFS = {
	{ Key = "Gold",  Name = "Gold",  Icon = iconFromDecal("Gold")  },
	{ Key = "Wood",  Name = "Wood",  Icon = iconFromDecal("Wood")  },
	{ Key = "Stone", Name = "Stone", Icon = iconFromDecal("Stone") },
	{ Key = "Pop",   Name = "Pop",   Icon = iconFromDecal("Pop"), IsComputed = true },
}

local Rows = {} -- Rows[Key] = { Row=Frame, Value=TextLabel }

local function makeResourceRow(order, def)
	local row = Instance.new("Frame")
	row.Name = def.Key .. "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = order
	row.Parent = frame

	-- Icon holder
	local iconHolder = Instance.new("Frame")
	iconHolder.Name = "IconHolder"
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.Position = UDim2.new(0, 0, 0.5, 0)
	iconHolder.Size = UDim2.fromOffset(22, 22)
	iconHolder.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
	iconHolder.BorderSizePixel = 0
	iconHolder.Parent = row

	local ic = Instance.new("UICorner")
	ic.CornerRadius = UDim.new(0, 6)
	ic.Parent = iconHolder

	local istroke = Instance.new("UIStroke")
	istroke.Color = Color3.fromRGB(80, 80, 90)
	istroke.Transparency = 0.55
	istroke.Thickness = 1
	istroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	istroke.Parent = iconHolder

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromScale(1, 1)
	icon.Image = def.Icon or ""
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = iconHolder

	-- Fallback letter (only shows if you haven’t set an icon id yet)
	local fallback = Instance.new("TextLabel")
	fallback.Name = "Fallback"
	fallback.BackgroundTransparency = 1
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.Font = Enum.Font.GothamBlack
	fallback.TextSize = 12
	fallback.TextColor3 = Color3.fromRGB(220, 220, 220)
	fallback.Text = string.sub(def.Name or def.Key, 1, 1)
	fallback.Parent = iconHolder

	local hasIcon = (def.Icon and def.Icon ~= "" and def.Icon ~= "rbxassetid://0")
	icon.Visible = hasIcon
	fallback.Visible = not hasIcon

	-- Name
	local name = Instance.new("TextLabel")
	name.Name = "Name"
	name.BackgroundTransparency = 1
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.new(0, 30, 0.5, 0)
	name.Size = UDim2.new(0, 80, 1, 0)
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = Color3.fromRGB(235, 235, 235)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.Name
	name.Parent = row

	-- Value
	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, 0, 0.5, 0)
	value.Size = UDim2.new(0, 82, 1, 0)
	value.Font = Enum.Font.GothamBlack
	value.TextSize = 14
	value.TextColor3 = Color3.fromRGB(255, 255, 255)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = "0"
	value.Parent = row

	Rows[def.Key] = { Row = row, Value = value }
	return row
end

for i, def in ipairs(RESOURCE_DEFS) do
	makeResourceRow(i, def)
end


local function refresh()
	-- Simple resources
	Rows.Gold.Value.Text = tostring(player:GetAttribute("Gold") or 0)
	Rows.Wood.Value.Text = tostring(player:GetAttribute("Wood") or 0)
	Rows.Stone.Value.Text = tostring(player:GetAttribute("Stone") or 0)


	-- Population (computed)
	local maxPop = player:GetAttribute("MaxPopulation") or 10


	-- 1) Count Units
	local pop = 0
	for _, u in ipairs(unitsFolder:GetChildren()) do
		if u:GetAttribute("OwnerUserId") == player.UserId then
			pop += 1
		end
	end


	-- 2) Count Active Buildings (Farm + Sawmill)
	for _, b in ipairs(workspace:GetChildren()) do
		if b:IsA("Model") and b:GetAttribute("OwnerUserId") == player.UserId then
			local bType = b:GetAttribute("BuildingType")
			local isComplete = not b:GetAttribute("UnderConstruction")
			if isComplete then
				if bType == "Farm" then
					pop += 5
				elseif bType == "RTSSawmill" then
					pop += 5
				end
			end
		end
	end


	if pop >= maxPop then
		Rows.Pop.Value.TextColor3 = Color3.fromRGB(255, 80, 80)
		Rows.Pop.Value.Text = string.format("%d/%d", pop, maxPop)
	else
		Rows.Pop.Value.TextColor3 = Color3.fromRGB(255, 255, 255)
		Rows.Pop.Value.Text = string.format("%d/%d", pop, maxPop)
	end
end


refresh()


-- Resource attributes
player:GetAttributeChangedSignal("Gold"):Connect(refresh)
player:GetAttributeChangedSignal("Wood"):Connect(refresh)
player:GetAttributeChangedSignal("Stone"):Connect(refresh)
player:GetAttributeChangedSignal("MaxPopulation"):Connect(refresh)


-- Unit folder changes affect Pop
unitsFolder.ChildAdded:Connect(refresh)
unitsFolder.ChildRemoved:Connect(refresh)


-- Building changes affect Pop
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") then
		refresh()
		child:GetAttributeChangedSignal("UnderConstruction"):Connect(refresh)
	end
end)


workspace.ChildRemoved:Connect(function(child)
	if child:IsA("Model") then refresh() end
end)


for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") then
		child:GetAttributeChangedSignal("UnderConstruction"):Connect(refresh)
	end
end

refresh()
player:GetAttributeChangedSignal("Gold"):Connect(refresh)
player:GetAttributeChangedSignal("Wood"):Connect(refresh)
player:GetAttributeChangedSignal("MaxPopulation"):Connect(refresh)

unitsFolder.ChildAdded:Connect(refresh)
unitsFolder.ChildRemoved:Connect(refresh)

-- [[ UPDATE POPULATION WHEN BUILDINGS (FARMS) SPAWN/FINISH ]] --
workspace.ChildAdded:Connect(function(child)
	if child:IsA("Model") then 
		refresh() 
		-- Listen for construction finish
		child:GetAttributeChangedSignal("UnderConstruction"):Connect(refresh)
	end
end)

workspace.ChildRemoved:Connect(function(child)
	if child:IsA("Model") then refresh() end
end)

-- Initialize listeners on existing buildings
for _, child in ipairs(workspace:GetChildren()) do
	if child:IsA("Model") then
		child:GetAttributeChangedSignal("UnderConstruction"):Connect(refresh)
	end
end


-- [[ Home Button Logic ]] --
local homeBtn = Instance.new("TextButton")
homeBtn.Name = "HomeButton"
homeBtn.Text = "¦"
homeBtn.TextSize = 24
homeBtn.Font = Enum.Font.GothamBold
homeBtn.TextColor3 = Color3.new(1, 1, 1)
homeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
homeBtn.BackgroundTransparency = 0.2
homeBtn.AnchorPoint = Vector2.new(1, 1)
homeBtn.Position = UDim2.new(1, -20, 1, -20) 
homeBtn.Size = UDim2.fromOffset(50, 50)
homeBtn.Parent = gui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(1, 0) -- Circle
btnCorner.Parent = homeBtn

homeBtn.MouseButton1Click:Connect(function()
	local basePos = player:GetAttribute("RTS_BasePos")
	if basePos then
		CameraReturn:Fire(basePos)
	end
end)