local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.HelpComponents)
local Animator = require(script.Parent.HelpAnimator)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 1. Setup UI
local gui = Components.createScreenGui()
gui.Parent = playerGui

local toggleBtn = Components.createToggleButton(gui)
local mainFrame, uiScale = Components.createMainFrame(gui)
local closeBtn = Components.createHeader(mainFrame)
Components.populateList(mainFrame)

-- 2. Responsive Logic
local function updateScale()
	local vp = Workspace.CurrentCamera.ViewportSize
	if vp.Y < 650 then
		uiScale.Scale = vp.Y / 700
	else
		uiScale.Scale = 1
	end
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- 3. Interaction Logic
local isOpen = false

local function toggle()
	isOpen = not isOpen
	Animator.toggle(mainFrame, isOpen)
end

toggleBtn.MouseButton1Click:Connect(toggle)
closeBtn.MouseButton1Click:Connect(toggle)