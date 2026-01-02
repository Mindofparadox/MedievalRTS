local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.AdminServerConfig)
local Logic = require(script.Parent.AdminServerLogic)

-- Setup Remote
local Remotes = ReplicatedStorage:FindFirstChild("RTSRemotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "RTSRemotes"
	Remotes.Parent = ReplicatedStorage
end

local AdminRemote = Remotes:FindFirstChild(Config.REMOTE_NAME)
if not AdminRemote then
	AdminRemote = Instance.new("RemoteEvent")
	AdminRemote.Name = Config.REMOTE_NAME
	AdminRemote.Parent = Remotes
end

-- Listener
AdminRemote.OnServerEvent:Connect(function(plr, action, data)
	if plr.UserId ~= Config.OWNER_ID then return end -- Security

	if action == "SpawnUnit" then
		local owner = data.Enemy and -1 or plr.UserId
		Logic.spawnUnit(plr, data.Type, data.Pos, owner)

	elseif action == "Resources" then
		for k, v in pairs(data) do
			if k ~= "Delta" then
				local current = plr:GetAttribute(k) or 0
				plr:SetAttribute(k, current + v)
			end
		end

	elseif action == "Population" then
		local cur = plr:GetAttribute("MaxPopulation") or 10
		local delta = data.Delta or 0
		plr:SetAttribute("MaxPopulation", math.max(0, cur + delta))

	elseif action == "Tile" then
		Logic.paintTile(data.Target, data.TileName)

	elseif action == "Building" then
		Logic.forceBuild(plr, data.Name, data.Pos)

	elseif action == "Destroy" then
		if data.Target and data.Target.Parent then
			data.Target:Destroy()
		end
	end
end)