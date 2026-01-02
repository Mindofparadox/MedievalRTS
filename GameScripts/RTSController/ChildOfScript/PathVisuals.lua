--// RTSController Modular Split
--// Path visuals (Beam segments)
--// Generated from RTSControllerBACKUP.lua (Tre'On)

local S = require(script.Parent.Shared)

local PathUpdate = S.PathUpdate

---------------------------------------------------------------------
-- Path visuals (Beam segments) [Resume rest of script...]

---------------------------------------------------------------------
-- Path visuals (Beam segments)
---------------------------------------------------------------------
local PathVis = {} 
local function makeAttachmentPoint(parent, pos)
	local p = Instance.new("Part")
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.Transparency = 1; p.Size = Vector3.new(0.2, 0.2, 0.2); p.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)); p.Parent = parent
	local a = Instance.new("Attachment"); a.Parent = p
	return p, a
end
local NextPathVis = {} 
local function destroyNextPath(unitId)
	local vis = NextPathVis[unitId]; if not vis then return end
	if vis.folder and vis.folder.Parent then vis.folder:Destroy() end; NextPathVis[unitId] = nil
end
local function buildNextPath(unitId, points)
	destroyNextPath(unitId); if not points or #points < 2 then return end
	local folder = Instance.new("Folder"); folder.Name = "NextPath_" .. unitId; folder.Parent = workspace
	local attachments, parts, beams = {}, {}, {}
	for i, pos in ipairs(points) do local part, att = makeAttachmentPoint(folder, pos); parts[i] = part; attachments[i] = att end
	for i = 1, #attachments - 1 do
		local beam = Instance.new("Beam"); beam.Attachment0 = attachments[i]; beam.Attachment1 = attachments[i + 1]; beam.Width0 = 0.16; beam.Width1 = 0.16; beam.FaceCamera = true; beam.Transparency = NumberSequence.new(0.6); beam.Parent = folder; beams[i] = beam
	end
	NextPathVis[unitId] = { folder = folder, parts = parts, attachments = attachments, beams = beams }
end
local function destroyPath(unitId)
	local vis = PathVis[unitId]; if not vis then return end
	if vis.folder and vis.folder.Parent then vis.folder:Destroy() end; PathVis[unitId] = nil
end
local function buildPath(unitId, points)
	destroyPath(unitId); if not points or #points < 2 then return end
	local folder = Instance.new("Folder"); folder.Name = "Path_" .. unitId; folder.Parent = workspace
	local attachments, parts, beams = {}, {}, {}
	for i, pos in ipairs(points) do local part, att = makeAttachmentPoint(folder, pos); parts[i] = part; attachments[i] = att end
	for i = 1, #attachments - 1 do
		local beam = Instance.new("Beam"); beam.Attachment0 = attachments[i]; beam.Attachment1 = attachments[i + 1]; beam.Width0 = 0.22; beam.Width1 = 0.22; beam.FaceCamera = true; beam.Parent = folder; beams[i] = beam
	end
	PathVis[unitId] = { folder = folder, parts = parts, attachments = attachments, beams = beams }
end
local function shrinkPath(unitId, currentIndex)
	local vis = PathVis[unitId]; if not vis then return end
	for i = 1, math.max(0, currentIndex - 1) do
		if vis.parts[i] then vis.parts[i]:Destroy(); vis.parts[i] = nil end
		if vis.beams[i] then vis.beams[i]:Destroy(); vis.beams[i] = nil end
	end
end
PathUpdate.OnClientEvent:Connect(function(mode, unitId, points, index)
	if mode == "NEW" then if typeof(points) == "table" then buildPath(unitId, points) end
	elseif mode == "PROGRESS" then shrinkPath(unitId, index)
	elseif mode == "DONE" then destroyPath(unitId)
	elseif mode == "NEXT" then if typeof(points) == "table" then buildNextPath(unitId, points) else destroyNextPath(unitId) end
	elseif mode == "NEXT_CLEAR" then destroyNextPath(unitId) end
end)



S.PathVis = PathVis
S.NextPathVis = NextPathVis
S.destroyPath = destroyPath
S.buildPath = buildPath
S.destroyNextPath = destroyNextPath
S.buildNextPath = buildNextPath

return true
