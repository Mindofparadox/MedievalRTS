-- RTSUnitServer / Modules / BUILDERAUTOSYSTEM.lua
-- Handles client requests to set builder auto states + max base distance.

return function(S)
	local SetBuilderAuto = S.SetBuilderAuto
	if not SetBuilderAuto then
		return true
	end

	-- IMPORTANT: Units folder is created by the FOLDERS module, so this module must load AFTER FOLDERS.
	-- Still keep a safe fallback if something changes later.
	local unitsFolder = S.unitsFolder or workspace:FindFirstChild("RTSUnits")
	if not unitsFolder then
		warn("[BUILDERAUTOSYSTEM] unitsFolder missing (expected workspace.RTSUnits). Auto-state remote will be ignored.")
		return true
	end
	S.unitsFolder = unitsFolder

	-- Prevent double-hooking if hot-reloaded
	if S.__BuilderAutoHooked then
		return true
	end
	S.__BuilderAutoHooked = true

	local function findUnitById(unitId)
		local want = tostring(unitId)
		for _, unit in ipairs(unitsFolder:GetChildren()) do
			if unit:IsA("Model") then
				local uid = unit:GetAttribute("UnitId")
				if uid ~= nil and tostring(uid) == want then
					return unit
				end
			end
		end
		return nil
	end

	local VALID_STATES = {
		Idle = true,
		Mining = true,
		Woodchopping = true,
		Wander = true,
		Auto = true, -- legacy fallback (marked resources only)
	}

	SetBuilderAuto.OnServerEvent:Connect(function(plr, unitIds, state, maxDist)
		if typeof(unitIds) ~= "table" then
			return
		end

		local md = tonumber(maxDist)
		if md ~= nil then
			md = math.clamp(md, 30, 600)
		end

		local stateOk = (state ~= nil and type(state) == "string" and VALID_STATES[state])

		for _, id in ipairs(unitIds) do
			local unit = findUnitById(id)
			if unit
				and unit:GetAttribute("OwnerUserId") == plr.UserId
				and unit:GetAttribute("UnitType") == "Builder"
			then
				if stateOk then
					unit:SetAttribute("AutoState", state)
				end
				if md ~= nil then
					unit:SetAttribute("AutoMaxDist", md)
				end
			end
		end
	end)

	return true
end
