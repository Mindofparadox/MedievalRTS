local CharacterUtil = {}
local Players = game:GetService("Players")

function CharacterUtil.disableDefaultControls()
	local player = Players.LocalPlayer
	local ok, pm = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and pm and pm.GetControls then
		local controls = pm:GetControls()
		if controls and controls.Disable then
			controls:Disable()
		end
	end
end

function CharacterUtil.hideAndFreeze(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart")

	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.AutoRotate = false
		hum.PlatformStand = true
	end

	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end

	local function hideDesc(d)
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			d.CastShadow = false
			d.CanCollide = false
		elseif d:IsA("Decal") then
			d.Transparency = 1
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end

	for _, d in ipairs(char:GetDescendants()) do
		hideDesc(d)
	end

	-- Connect for new parts (armor, tools, etc.)
	char.DescendantAdded:Connect(hideDesc)
end

return CharacterUtil