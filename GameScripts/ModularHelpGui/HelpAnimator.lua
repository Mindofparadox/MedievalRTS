local HelpAnimator = {}
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.HelpConfig)

function HelpAnimator.toggle(frame, isOpen)
	frame.Visible = isOpen

	if isOpen then
		-- Reset state for animation
		frame.Size = UDim2.fromOffset(480, 600)
		frame.BackgroundTransparency = 1

		for _, desc in ipairs(frame:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				desc.TextTransparency = 1
			elseif desc:IsA("UIStroke") then
				desc.Transparency = 1
			end
		end

		-- Animate Frame Pop
		local tInfo = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(frame, tInfo, {
			Size = Config.SIZES.WindowSize, 
			BackgroundTransparency = 0
		}):Play()

		-- Fade In Content
		task.wait(0.1)
		for _, desc in ipairs(frame:GetDescendants()) do
			if desc:IsA("TextLabel") or desc:IsA("TextButton") then
				TweenService:Create(desc, TweenInfo.new(0.2), {TextTransparency = 0}):Play()
			elseif desc:IsA("UIStroke") then
				TweenService:Create(desc, TweenInfo.new(0.2), {Transparency = 0}):Play()
			end
		end
	end
end

return HelpAnimator