-- StarterPlayerScripts / RTSController.lua
-- Modular bootstrap loader: loads modules in dependency order so they share the same state (Shared.lua)

local modules = script:WaitForChild("Modules")

-- Shared state (everything writes/reads from this table)
local S = require(modules:WaitForChild("Shared"))

-- Order matters:
-- UI must load before Selection so S.gui exists before highlights are created.
-- Helpers must load before modules that call utility functions exported on S.
require(modules:WaitForChild("UI"))
require(modules:WaitForChild("Helpers"))
require(modules:WaitForChild("FogOfWar"))
require(modules:WaitForChild("Selection"))
require(modules:WaitForChild("HealthBars"))
require(modules:WaitForChild("PathVisuals"))
require(modules:WaitForChild("Roster"))
require(modules:WaitForChild("Main"))

return S

--[[
Previous bootstrap order (kept for reference):
-- StarterPlayerScripts / RTSController.lua
-- Modular bootstrap loader: loads modules in dependency order so they share the same state (Shared.lua)

local modules = script:WaitForChild("Modules")

-- Shared state (everything writes/reads from this table)
local S = require(modules:WaitForChild("Shared"))

-- Order matters: modules below populate functions/state that later modules use.
require(modules:WaitForChild("Helpers"))
require(modules:WaitForChild("Selection"))
require(modules:WaitForChild("UI"))
require(modules:WaitForChild("HealthBars"))
require(modules:WaitForChild("PathVisuals"))
require(modules:WaitForChild("Roster"))
require(modules:WaitForChild("Main"))

return S

]]
