local AdminComponents = {}
local Config = require(script.Parent.AdminConfig)

function AdminComponents.createGui(player)
	local sg = Instance.new("ScreenGui")
	sg.Name = "RTSAdmin"
	sg.ResetOnSpawn = false
	sg.Enabled = false
	sg.Parent = player:WaitForChild("PlayerGui")
	return sg
end

function AdminComponents.createMainFrame(parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(500, 350)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = Config.COLORS.FrameBg
	f.BorderSizePixel = 2
	f.BorderColor3 = Config.COLORS.FrameBorder
	f.Parent = parent

	local t = Instance.new("TextLabel", f)
	t.Size = UDim2.new(1, 0, 0, 30)
	t.BackgroundColor3 = Config.COLORS.HeaderBg
	t.TextColor3 = Config.COLORS.Text
	t.Font = Enum.Font.GothamBlack
	t.Text = "  ADMIN CONTROL PANEL (Owner Only)"
	t.TextXAlignment = Enum.TextXAlignment.Left

	return f
end

function AdminComponents.createContainers(mainFrame)
	local tabs = Instance.new("Frame", mainFrame)
	tabs.Position = UDim2.new(0, 0, 0, 30)
	tabs.Size = UDim2.new(0, 100, 1, -30)
	tabs.BackgroundColor3 = Config.COLORS.TabContainerBg

	local layout = Instance.new("UIListLayout", tabs)
	layout.Padding = UDim.new(0, 5)

	local content = Instance.new("Frame", mainFrame)
	content.Position = UDim2.new(0, 110, 0, 40)
	content.Size = UDim2.new(1, -120, 1, -50)
	content.BackgroundTransparency = 1

	local grid = Instance.new("UIGridLayout", content)
	grid.CellSize = UDim2.fromOffset(110, 40)
	grid.CellPadding = UDim2.fromOffset(10, 10)

	return tabs, content
end

function AdminComponents.createTabButton(parent, text, callback)
	local b = Instance.new("TextButton", parent)
	b.Size = UDim2.new(1, 0, 0, 40)
	b.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	b.TextColor3 = Config.COLORS.Text
	b.Font = Enum.Font.GothamBold
	b.Text = text
	b.MouseButton1Click:Connect(callback)
	return b
end

function AdminComponents.createToolButton(parent, text, color, callback)
	local b = Instance.new("TextButton", parent)
	b.BackgroundColor3 = color or Config.COLORS.ButtonDefault
	b.TextColor3 = Config.COLORS.Text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 11
	b.Text = text
	local c = Instance.new("UICorner", b); c.CornerRadius = UDim.new(0, 4)
	b.MouseButton1Click:Connect(callback)
	return b
end

return AdminComponents