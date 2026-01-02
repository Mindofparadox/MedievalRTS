local CurrencyComponents = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CurrencyConfig = require(script.Parent.CurrencyConfig)

-- Helper to find icon texture
local function getIconTexture(key)
	local folder = ReplicatedStorage:FindFirstChild("ResourceIcons")
	if folder then
		local decal = folder:FindFirstChild(key)
		if decal and decal:IsA("Decal") then
			return decal.Texture
		end
	end
	return ""
end

function CurrencyComponents.createScreenGui(player)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RTSCurrencyGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function CurrencyComponents.createMainFrame(parent)
	local frame = Instance.new("Frame")
	frame.Name = "ResourceFrame"
	frame.AnchorPoint = Vector2.new(1, 0)
	frame.Position = CurrencyConfig.LAYOUT.FramePosition
	frame.Size = CurrencyConfig.LAYOUT.FrameSize
	frame.BackgroundColor3 = CurrencyConfig.COLORS.FrameBg
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = parent

	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = CurrencyConfig.COLORS.FrameStroke; stroke.Transparency = 0.4; stroke.Thickness = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, 10)

	local list = Instance.new("UIListLayout", frame)
	list.SortOrder = Enum.SortOrder.LayoutOrder; list.Padding = UDim.new(0, 4)

	local pad = Instance.new("UIPadding", frame)
	pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)

	return frame
end

function CurrencyComponents.createRow(parent, def, layoutOrder)
	local row = Instance.new("Frame")
	row.Name = def.Key .. "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 24)
	row.LayoutOrder = layoutOrder
	row.Parent = parent

	-- ICON HOLDER
	local iconHolder = Instance.new("Frame", row)
	iconHolder.AnchorPoint = Vector2.new(0, 0.5); iconHolder.Position = UDim2.new(0,0,0.5,0)
	iconHolder.Size = UDim2.fromOffset(22, 22); iconHolder.BackgroundColor3 = CurrencyConfig.COLORS.IconBg

	local ic = Instance.new("UICorner", iconHolder); ic.CornerRadius = UDim.new(0, 6)
	local is = Instance.new("UIStroke", iconHolder); is.Color = CurrencyConfig.COLORS.FrameStroke; is.Transparency = 0.55

	local texture = getIconTexture(def.Key)
	local icon = Instance.new("ImageLabel", iconHolder)
	icon.BackgroundTransparency = 1; icon.Size = UDim2.fromScale(1,1); icon.ScaleType = Enum.ScaleType.Fit
	icon.Image = texture
	icon.Visible = (texture ~= "")

	local fallback = Instance.new("TextLabel", iconHolder)
	fallback.BackgroundTransparency = 1; fallback.Size = UDim2.fromScale(1,1)
	fallback.Font = Enum.Font.GothamBlack; fallback.TextSize = 12; fallback.TextColor3 = Color3.new(0.8,0.8,0.8)
	fallback.Text = string.sub(def.Name, 1, 1)
	fallback.Visible = (texture == "")

	-- NAME
	local name = Instance.new("TextLabel", row)
	name.BackgroundTransparency = 1; name.AnchorPoint = Vector2.new(0, 0.5); name.Position = UDim2.new(0, 30, 0.5, 0)
	name.Size = UDim2.new(0, 80, 1, 0); name.Font = Enum.Font.GothamBold; name.TextSize = 13
	name.TextColor3 = CurrencyConfig.COLORS.TextName; name.TextXAlignment = Enum.TextXAlignment.Left
	name.Text = def.Name

	-- VALUE (We return this so the controller can update it)
	local value = Instance.new("TextLabel", row)
	value.BackgroundTransparency = 1; value.AnchorPoint = Vector2.new(1, 0.5); value.Position = UDim2.new(1, 0, 0.5, 0)
	value.Size = UDim2.new(0, 82, 1, 0); value.Font = Enum.Font.GothamBlack; value.TextSize = 14
	value.TextColor3 = CurrencyConfig.COLORS.TextValue; value.TextXAlignment = Enum.TextXAlignment.Right
	value.Text = "0"

	return row, value
end

function CurrencyComponents.createHomeButton(parent)
	local btn = Instance.new("TextButton")
	btn.Name = "HomeButton"
	btn.Text = "¦" -- Use a nice icon here if you have one
	btn.TextSize = 24
	btn.Font = Enum.Font.GothamBold
	btn.TextColor3 = Color3.new(1,1,1)
	btn.BackgroundColor3 = CurrencyConfig.COLORS.HomeButton
	btn.BackgroundTransparency = 0.2
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = CurrencyConfig.LAYOUT.HomeBtnPosition
	btn.Size = UDim2.fromOffset(50, 50)
	btn.Parent = parent

	local c = Instance.new("UICorner", btn); c.CornerRadius = UDim.new(1, 0)

	return btn
end

return CurrencyComponents