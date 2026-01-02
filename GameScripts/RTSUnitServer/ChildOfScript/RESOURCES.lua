-- Modules/RESOURCES.lua
return function(S)
	-- Section: RESOURCES
	-- Aliases from shared state
	local CollectionService = S.CollectionService

	---------------------------------------------------------------------
	-- RESOURCES
	---------------------------------------------------------------------
	local addWood
	addWood = function(plr, amount)
		plr:SetAttribute("Wood", (plr:GetAttribute("Wood") or 0) + (amount or 0))
	end
	S.addWood = addWood



	local addStone
	addStone = function(plr, amount)
		plr:SetAttribute("Stone", (plr:GetAttribute("Stone") or 0) + (amount or 0))
	end
	S.addStone = addStone


	---------------------------------------------------------------------
	-- TREE HARVESTING (builders)
	---------------------------------------------------------------------
	local TREE_TAG = "RTSTree"
	local TreeClaims = {} 

	local ProductionQueues = {} 
	local QueueRunning = {}     

	local isValidTreeModel
	isValidTreeModel = function(treeModel)
		if typeof(treeModel) ~= "Instance" then return false end
		if not treeModel:IsA("Model") then return false end
		if not treeModel:IsDescendantOf(workspace) then return false end
		if treeModel:GetAttribute("IsRTSTree") == true then
			return true
		end
		if CollectionService:HasTag(treeModel, TREE_TAG) then
			return true
		end
		return false
	end
	S.isValidTreeModel = isValidTreeModel


	local claimTree
	claimTree = function(treeModel, unit)
		local current = TreeClaims[treeModel]
		if current and current ~= unit then
			return false
		end
		TreeClaims[treeModel] = unit
		return true
	end
	S.claimTree = claimTree


	local releaseTree
	releaseTree = function(treeModel, unit)
		if TreeClaims[treeModel] == unit then
			TreeClaims[treeModel] = nil
		end
	end
	S.releaseTree = releaseTree


	local clearTreeClaim
	clearTreeClaim = function(treeModel)
		TreeClaims[treeModel] = nil
	end
	S.clearTreeClaim = clearTreeClaim



	-- Export locals (final values)
	S.ProductionQueues = ProductionQueues
	S.QueueRunning = QueueRunning
	S.TREE_TAG = TREE_TAG
	S.TreeClaims = TreeClaims

	---------------------------------------------------------------------
	-- STONE HARVESTING (builders)
	---------------------------------------------------------------------
	local STONE_TAG = "RTSStone"
	local StoneClaims = {}

	-- Normalize a clicked/hovered stone (may be an inner child model/part) to the top-level Rock_ node.
	local function normalizeStoneModel(stoneModel)
		if typeof(stoneModel) ~= "Instance" then return nil end
		local model = stoneModel
		if not model:IsA("Model") then
			model = stoneModel:FindFirstAncestorOfClass("Model")
		end
		if not model then return nil end

		local resFolder = workspace:FindFirstChild("ResourceNodes")
		local cur = model
		while cur do
			if cur:GetAttribute("IsRTSStone") == true or CollectionService:HasTag(cur, STONE_TAG) then
				return cur
			end
			if resFolder and cur:IsDescendantOf(resFolder) and string.match(cur.Name, "^Rock_") then
				return cur
			end
			local p = cur.Parent
			while p and not p:IsA("Model") do p = p.Parent end
			cur = p
		end
		return nil
	end
	S.normalizeStoneModel = normalizeStoneModel

	local isValidStoneModel
	isValidStoneModel = function(stoneModel)
		stoneModel = normalizeStoneModel(stoneModel) or stoneModel
		if typeof(stoneModel) ~= "Instance" then return false end
		if not stoneModel:IsA("Model") then return false end
		if not stoneModel:IsDescendantOf(workspace) then return false end
		if stoneModel:GetAttribute("IsRTSStone") == true then
			return true
		end
		if CollectionService:HasTag(stoneModel, STONE_TAG) then
			return true
		end
		local resFolder = workspace:FindFirstChild("ResourceNodes")
		if resFolder and stoneModel:IsDescendantOf(resFolder) and string.match(stoneModel.Name, "^Rock_") then
			return true
		end

		return false
	end
	S.isValidStoneModel = isValidStoneModel

	local claimStone
	claimStone = function(stoneModel, unit)
		stoneModel = normalizeStoneModel(stoneModel) or stoneModel
		local current = StoneClaims[stoneModel]
		if current and current ~= unit then
			return false
		end
		StoneClaims[stoneModel] = unit
		return true
	end
	S.claimStone = claimStone

	local releaseStone
	releaseStone = function(stoneModel, unit)
		stoneModel = normalizeStoneModel(stoneModel) or stoneModel
		if StoneClaims[stoneModel] == unit then
			StoneClaims[stoneModel] = nil
		end
	end
	S.releaseStone = releaseStone

	local clearStoneClaim
	clearStoneClaim = function(stoneModel)
		stoneModel = normalizeStoneModel(stoneModel) or stoneModel
		StoneClaims[stoneModel] = nil
	end
	S.clearStoneClaim = clearStoneClaim

	S.STONE_TAG = STONE_TAG
	S.StoneClaims = StoneClaims

	return true

end

