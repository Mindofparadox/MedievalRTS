local InputController = {}
local UserInputService = game:GetService("UserInputService")

-- Public State
InputController.keysDown = { W=false, A=false, S=false, D=false, Shift=false }
InputController.rotating = false

-- Events (Callbacks that Main script will define)
InputController.OnZoom = nil   -- function(delta)
InputController.OnRotate = nil -- function(dx, dy)

function InputController.start()
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end

		if input.KeyCode == Enum.KeyCode.W then InputController.keysDown.W = true end
		if input.KeyCode == Enum.KeyCode.A then InputController.keysDown.A = true end
		if input.KeyCode == Enum.KeyCode.S then InputController.keysDown.S = true end
		if input.KeyCode == Enum.KeyCode.D then InputController.keysDown.D = true end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			InputController.keysDown.Shift = true
		end

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			InputController.rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gp)
		if input.KeyCode == Enum.KeyCode.W then InputController.keysDown.W = false end
		if input.KeyCode == Enum.KeyCode.A then InputController.keysDown.A = false end
		if input.KeyCode == Enum.KeyCode.S then InputController.keysDown.S = false end
		if input.KeyCode == Enum.KeyCode.D then InputController.keysDown.D = false end

		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			InputController.keysDown.Shift = false
		end

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			if InputController.rotating then
				InputController.rotating = false
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input, gp)
		if gp then return end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			if InputController.OnZoom then
				InputController.OnZoom(input.Position.Z)
			end
		end

		if InputController.rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
			if InputController.OnRotate then
				InputController.OnRotate(input.Delta.X, input.Delta.Y)
			end
		end
	end)
end

return InputController