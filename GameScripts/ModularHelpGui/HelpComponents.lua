local HelpComponents = {}
local Config = require(script.Parent.HelpConfig)

function HelpComponents.createScreenGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RTSHelpGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	return gui
end

function HelpComponents.createToggleButton(parent)
	local btn = Instance.new("TextButton")
	btn.Name = "HelpButton"
	btn.Text = "?"
	btn.Font = Config.FONTS.Title
	btn.TextSize = 24
	btn.TextColor3 = Color3.new(1,1,1)
	btn.BackgroundColor3 = Config.COLORS.ButtonBackground
	btn.BackgroundTransparency = 0.1
	btn.AnchorPoint = Vector2.new(1, 1)
	btn.Position = UDim2.new(1, -20, 1, -80)
	btn.Size = Config.SIZES.ButtonSize
	btn.AutoButtonColor = true
	btn.Parent = parent

	local corner = Instance.new("UICorner", btn)
	corner.CornerRadius = UDim.new(1, 0)

	local stroke = Instance.new("UIStroke", btn)
	stroke.Color = Color3.new(1,1,1)
	stroke.Transparency = 0.8
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	return btn
end

function HelpComponents.createMainFrame(parent)
	local frame = Instance.new("Frame")
	frame.Name = "ControlsFrame"
	frame.Size = Config.SIZES.WindowSize
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = Config.COLORS.MainBackground
	frame.Visible = false
	frame.ClipsDescendants = true
	frame.Parent = parent

	local uiScale = Instance.new("UIScale", frame)

	local corner = Instance.new("UICorner", frame)
	corner.CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = Config.COLORS.Stroke
	stroke.Thickness = 2

	return frame, uiScale
end

function HelpComponents.createHeader(parent)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 50)
	header.BackgroundColor3 = Config.COLORS.HeaderBackground
	header.BorderSizePixel = 0
	header.Parent = parent

	local title = Instance.new("TextLabel")
	title.Text = "CONTROLS"
	title.Font = Config.FONTS.Title
	title.TextSize = 18
	title.TextColor3 = Config.COLORS.TextHeader
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, -60, 1, 0)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = header

	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "X"
	closeBtn.Font = Config.FONTS.Key
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = Config.COLORS.CloseRed
	closeBtn.BackgroundTransparency = 1
	closeBtn.Size = UDim2.fromOffset(50, 50)
	closeBtn.Position = UDim2.new(1, -50, 0, 0)
	closeBtn.Parent = header

	return closeBtn
end

function HelpComponents.populateList(parent)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.Position = UDim2.new(0, 0, 0, 50)
	scroll.Size = UDim2.new(1, 0, 1, -50)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100,100,100)
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout", scroll)
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local pad = Instance.new("UIPadding", scroll)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)

	local order = 1

	local function createRow(text, action, layoutOrder)
		local row = Instance.new("Frame")
		row.LayoutOrder = layoutOrder
		row.Size = UDim2.new(0.92, 0, 0, 40)
		row.BackgroundColor3 = Config.COLORS.RowBackground
		row.BackgroundTransparency = 0.6
		row.Parent = scroll

		local rc = Instance.new("UICorner", row); rc.CornerRadius = UDim.new(0, 6)

		local keyFrame = Instance.new("Frame", row)
		keyFrame.BackgroundColor3 = Config.COLORS.KeyCapBackground
		keyFrame.Size = UDim2.new(0, 120, 0, 28)
		keyFrame.Position = UDim2.new(0, 10, 0.5, 0)
		keyFrame.AnchorPoint = Vector2.new(0, 0.5)
		local kc = Instance.new("UICorner", keyFrame); kc.CornerRadius = UDim.new(0, 4)
		local ks = Instance.new("UIStroke", keyFrame); ks.Color = Color3.fromRGB(80,80,80); ks.Thickness = 1

		local kl = Instance.new("TextLabel", keyFrame)
		kl.Size = UDim2.fromScale(1,1); kl.BackgroundTransparency = 1; kl.Text = text
		kl.Font = Config.FONTS.Key; kl.TextColor3 = Config.COLORS.TextKey; kl.TextSize = 12

		local al = Instance.new("TextLabel", row)
		al.Size = UDim2.new(1, -150, 1, 0); al.Position = UDim2.new(0, 140, 0, 0)
		al.BackgroundTransparency = 1; al.Text = action; al.TextXAlignment = Enum.TextXAlignment.Left
		al.Font = Config.FONTS.Action; al.TextColor3 = Config.COLORS.TextNormal; al.TextSize = 13
	end

	local function createSection(text, layoutOrder)
		local l = Instance.new("TextLabel", scroll)
		l.LayoutOrder = layoutOrder; l.Size = UDim2.new(1,0,0,30); l.BackgroundTransparency = 1
		l.Text = text; l.Font = Config.FONTS.Title; l.TextColor3 = Config.COLORS.TextSection; l.TextSize = 11
	end

	for _, sectionData in ipairs(Config.CONTROLS_DATA) do
		createSection(sectionData.Section, order)
		order += 1
		for _, entry in ipairs(sectionData.Entries) do
			createRow(entry.Key, entry.Action, order)
			order += 1
		end
	end
end

return HelpComponents