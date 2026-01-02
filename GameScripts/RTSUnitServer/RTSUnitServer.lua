-- ServerScriptService / RTSUnitServer.lua (Modular Bootstrap)
local Modules = script:WaitForChild("Modules")
local S = require(Modules:WaitForChild("Shared"))

local ORDER = {
	"REMOTES",
	"RESOURCES",
	"FOLDERS",
	"BUILDERAUTOSYSTEM",
	"CONFIG",
	"UNITTEMPLATE",
	"TILECOLLECTION",
	"BASESYSTEM",
	"SPAWNTESTUNITS",
	"COMMANDMOVE",
	"BUILDINGCONSTRUCTIONSYSTEM",
	"COMMANDCANCEL",
	"UNITLOGICEXECUTION",
}

for _, name in ipairs(ORDER) do
	local mod = Modules:WaitForChild(name)
	local ok, err = pcall(function()
		require(mod)(S)
	end)
	if not ok then
		error(("RTSUnitServer failed loading module '%s': %s"):format(name, err))
	end
end

return true