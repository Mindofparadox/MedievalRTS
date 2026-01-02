local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--// GUI SETUP
local gui = Instance.new("ScreenGui")
gui.Name = "RTSHelpGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10 -- Ensure it renders on top of other RTS elements
gui.Parent = playerGui

---------------------------------------------------------------------
-- 1. THE TOGGLE BUTTON (Bottom Right, Above Home Button)
---------------------------------------------------------------------
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "HelpButton"
toggleBtn.Text = "?"
toggleBtn.Font = Enum.Font.GothamBlack
toggleBtn.TextSize = 24
toggleBtn.TextColor3 = Color3.new(1, 1, 1)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
toggleBtn.BackgroundTransparency = 0.1

-- [[ UPDATED POSITION ]] --
toggleBtn.AnchorPoint = Vector2.new(1, 1)
-- Positioned at (1, -20) (Right aligned) and lifted up by -80 to sit above the Home button
toggleBtn.Position = UDim2.new(1, -20, 1, -80) 
toggleBtn.Size = UDim2.fromOffset(50, 50) -- Matched size to Home Button (usually 50x50) for symmetry
toggleBtn.AutoButtonColor = true
toggleBtn.Parent = gui

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(1, 0) -- Circular (Matches Home Button style)
btnCorner.Parent = toggleBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Color = Color3.fromRGB(255, 255, 255)
btnStroke.Transparency = 0.8
btnStroke.Thickness = 1.5
btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
btnStroke.Parent = toggleBtn

---------------------------------------------------------------------
-- 2. MAIN CONTROL FRAME
---------------------------------------------------------------------
local mainFrame = Instance.new("Frame")
mainFrame.Name = "ControlsFrame"
mainFrame.Size = UDim2.fromOffset(500, 620)
mainFrame.Position = UDim2.fromScale(0.5, 0.5)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = gui

-- Make responsive (Simple scale down if screen is tiny)
local uiScale = Instance.new("UIScale")
uiScale.Parent = mainFrame

local function updateScale()
	local vp = workspace.CurrentCamera.ViewportSize
	if vp.Y < 650 then
		uiScale.Scale = vp.Y / 700
	else
		uiScale.Scale = 1
	end
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- Styling
local mfCorner = Instance.new("UICorner", mainFrame)
mfCorner.CornerRadius = UDim.new(0, 12)

local mfStroke = Instance.new("UIStroke", mainFrame)
mfStroke.Color = Color3.fromRGB(80, 80, 90)
mfStroke.Thickness = 2

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
header.BorderSizePixel = 0
header.Parent = mainFrame

local hTitle = Instance.new("TextLabel")
hTitle.Text = "CONTROLS"
hTitle.Font = Enum.Font.GothamBlack
hTitle.TextSize = 18
hTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
hTitle.BackgroundTransparency = 1
hTitle.Size = UDim2.new(1, -60, 1, 0)
hTitle.Position = UDim2.new(0, 20, 0, 0)
hTitle.TextXAlignment = Enum.TextXAlignment.Left
hTitle.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.BackgroundTransparency = 1
closeBtn.Size = UDim2.fromOffset(50, 50)
closeBtn.Position = UDim2.new(1, -50, 0, 0)
closeBtn.Parent = header

-- Content Container
local content = Instance.new("ScrollingFrame")
content.Name = "List"
content.Position = UDim2.new(0, 0, 0, 50)
content.Size = UDim2.new(1, 0, 1, -50)
content.BackgroundTransparency = 1
content.BorderSizePixel = 0
content.ScrollBarThickness = 4
content.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
content.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = content

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.Parent = content

---------------------------------------------------------------------
-- 3. HELPER TO CREATE ENTRIES
---------------------------------------------------------------------
local function createEntry(keyText, actionText, layoutOrder)
	local row = Instance.new("Frame")
	row.Name = "Row_"..layoutOrder
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(0.92, 0, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
	row.BackgroundTransparency = 0.6
	row.Parent = content

	local rCorner = Instance.new("UICorner", row)
	rCorner.CornerRadius = UDim.new(0, 6)

	-- Key Visual (The "Keycap")
	local keyFrame = Instance.new("Frame")
	keyFrame.Name = "KeyCap"
	keyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	keyFrame.Size = UDim2.new(0, 120, 0, 28)
	keyFrame.Position = UDim2.new(0, 10, 0.5, 0)
	keyFrame.AnchorPoint = Vector2.new(0, 0.5)
	keyFrame.Parent = row

	local kCorner = Instance.new("UICorner", keyFrame)
	kCorner.CornerRadius = UDim.new(0, 4)

	local kStroke = Instance.new("UIStroke", keyFrame)
	kStroke.Color = Color3.fromRGB(80, 80, 80)
	kStroke.Thickness = 1

	local kLabel = Instance.new("TextLabel")
	kLabel.Size = UDim2.new(1, 0, 1, 0)
	kLabel.BackgroundTransparency = 1
	kLabel.Text = keyText
	kLabel.Font = Enum.Font.GothamBold
	kLabel.TextColor3 = Color3.fromRGB(255, 200, 80) -- Gold text for keys
	kLabel.TextSize = 12
	kLabel.Parent = keyFrame

	-- Action Text
	local aLabel = Instance.new("TextLabel")
	aLabel.Size = UDim2.new(1, -150, 1, 0)
	aLabel.Position = UDim2.new(0, 140, 0, 0)
	aLabel.BackgroundTransparency = 1
	aLabel.Text = actionText
	aLabel.Font = Enum.Font.GothamMedium
	aLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
	aLabel.TextSize = 13
	aLabel.TextXAlignment = Enum.TextXAlignment.Left
	aLabel.Parent = row

	return row
end

local function createSectionHeader(text, layoutOrder)
	local label = Instance.new("TextLabel")
	label.LayoutOrder = layoutOrder
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = Color3.fromRGB(150, 150, 160)
	label.TextSize = 11
	label.Parent = content
end

---------------------------------------------------------------------
-- 4. POPULATE CONTROLS
---------------------------------------------------------------------

-- Camera
createSectionHeader("- CAMERA -", 1)
createEntry("W, A, S, D", "Pan Camera Position", 2)
createEntry("Scroll Wheel", "Zoom In / Out", 3)
createEntry("MMB Press", "Rotate Camera Angle", 4)

-- Selection
createSectionHeader("- SELECTION -", 5)
createEntry("Left Click", "Select Unit / Interact", 6)
createEntry("LMB Drag", "Box Select Multiple Units", 7)
createEntry("Ctrl + LMB Drag", "Box Select Trees Only", 8)
createEntry("Double Click", "Select All Units of Type", 9)

-- Commands
createSectionHeader("- COMMANDS -", 9)
createEntry("Right Click", "Move / Attack / Work", 10)
createEntry("Shift + RMB", "Queue Multiple Orders", 11)
createEntry("RMB Drag", "Set Unit Facing Direction", 12)
createEntry("C Key", "Cancel Selection / Stop", 13)

-- Actions
createSectionHeader("- ACTIONS -", 14)
createEntry("F Key", "Mark Tree for Chopping", 15)
createEntry("Q / E", "Rotate Building Placement", 16)
-- Garrison
createSectionHeader("- GARRISON -", 17)
createEntry("E Key (on Archer Tower)", "Garrison Selected Archers (RMB Move pulls them out)", 18)



---------------------------------------------------------------------
-- 5. LOGIC
---------------------------------------------------------------------
local isOpen = false

local function toggle()
	isOpen = not isOpen
	mainFrame.Visible = isOpen

	if isOpen then
		-- Animation Pop In
		mainFrame.Size = UDim2.fromOffset(480, 600)
		mainFrame.BackgroundTransparency = 1
		for _, desc in ipairs(mainFrame:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				desc.TextTransparency = 1
			elseif desc:IsA("UIStroke") then
				desc.Transparency = 1
			end
		end

		local tInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(mainFrame, tInfo, {Size = UDim2.fromOffset(500, 620), BackgroundTransparency = 0}):Play()

		-- Fade in content
		task.wait(0.1)
		for _, desc in ipairs(mainFrame:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				TweenService:Create(desc, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
			elseif desc:IsA("UIStroke") then
				TweenService:Create(desc, TweenInfo.new(0.2), {Transparency = 0}):Play()
			end
		end
	end
end

toggleBtn.MouseButton1Click:Connect(toggle)
closeBtn.MouseButton1Click:Connect(toggle)