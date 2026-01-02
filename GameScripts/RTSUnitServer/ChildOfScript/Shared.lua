-- Modules/Shared.lua
local S = {}

-- Core services (shared across modules)
S.Players = game:GetService("Players")
S.ReplicatedStorage = game:GetService("ReplicatedStorage")
S.PathfindingService = game:GetService("PathfindingService")
S.CollectionService = game:GetService("CollectionService")
S.RunService = game:GetService("RunService")
S.TweenService = game:GetService("TweenService")

return S