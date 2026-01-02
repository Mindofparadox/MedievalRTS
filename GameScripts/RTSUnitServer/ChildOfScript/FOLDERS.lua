-- Modules/FOLDERS.lua
return function(S)
	-- Section: FOLDERS
	---------------------------------------------------------------------
	-- FOLDERS
	---------------------------------------------------------------------
	local unitsFolder = workspace:FindFirstChild("RTSUnits")
	if not unitsFolder then
		unitsFolder = Instance.new("Folder")
		unitsFolder.Name = "RTSUnits"
		unitsFolder.Parent = workspace
	end

	local linksFolder = workspace:FindFirstChild("RTS_PathLinks")
	if not linksFolder then
		linksFolder = Instance.new("Folder")
		linksFolder.Name = "RTS_PathLinks"
		linksFolder.Parent = workspace
	end

	local basesFolder = workspace:FindFirstChild("RTSBases")
	if not basesFolder then
		basesFolder = Instance.new("Folder")
		basesFolder.Name = "RTSBases"
		basesFolder.Parent = workspace
	end

	-- Export locals (final values)
	S.basesFolder = basesFolder
	S.linksFolder = linksFolder
	S.unitsFolder = unitsFolder
	return true
end