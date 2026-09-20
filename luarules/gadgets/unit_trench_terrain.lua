--------------------------------------------------------------------------------
-- Trench Terrain Deformation
--
-- Trench buildings (customParams.trench) dig the ground down under their
-- footprint when finished and restore the original terrain when destroyed
-- or reclaimed.
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Trench Terrain",
		desc = "Trench buildings dig into the terrain and restore it when removed",
	author = "Doctrine RTS",
		date = "2025",
	license = "GNU GPL, v2 or later",
		layer = 0,
	enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local mathFloor = math.floor
	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetGroundHeight = Spring.GetGroundHeight
	local spLevelHeightMap = Spring.LevelHeightMap
	local spRevertHeightMap = Spring.RevertHeightMap
	local spRebuildSmoothMesh = Spring.RebuildSmoothMesh

	-- [unitDefID] = { depth/height, footprintx, footprintz, isBridge }
	local trenchDefs = {}
	local bridgeDefs = {}
	for udefID, udef in pairs(UnitDefs) do
		local cp = udef.customParams
		if cp and cp.trench then
			trenchDefs[udefID] = {
				depth = tonumber(cp.trench_depth) or 30,
				footprintx = udef.footprintx or 3,
				footprintz = udef.footprintz or 3,
			}
		elseif cp and cp.bridge then
			bridgeDefs[udefID] = {
				deckHeight = tonumber(cp.bridge_height) or 5,
				footprintx = udef.footprintx or 2,
				footprintz = udef.footprintz or 8,
			}
		end
	end

	local function getFootprintRect(unitID, fp)
		local x, _, z = spGetUnitPosition(unitID)
		if not x then
			return nil
		end
		local hw = fp.footprintx * 4 -- elmos per footprint square
		local hz = fp.footprintz * 4
		return mathFloor(x - hw), mathFloor(z - hz), mathFloor(x + hw), mathFloor(z + hz)
	end

	local function digTrench(unitID, unitDefID)
		local fp = trenchDefs[unitDefID]
		local x1, z1, x2, z2 = getFootprintRect(unitID, fp)
		if not x1 then
			return
		end
		local floorY = spGetGroundHeight((x1 + x2) / 2, (z1 + z2) / 2) - fp.depth
		spLevelHeightMap(x1, z1, x2, z2, floorY)
		spRebuildSmoothMesh(x1, z1, x2, z2)
	end

-- Bridges: raise terrain to a walkable deck height and make the
-- building itself intangible (no collision, not blocking)
	local function buildBridge(unitID, unitDefID)
		local fp = bridgeDefs[unitDefID]
		local x1, z1, x2, z2 = getFootprintRect(unitID, fp)
		if not x1 then
			return
		end
		local deckY = fp.deckHeight
		spLevelHeightMap(x1, z1, x2, z2, deckY)
		spRebuildSmoothMesh(x1, z1, x2, z2)
		-- no collision: units pass through the bridge structure itself
		Spring.SetUnitCollisionVolumeData(unitID, false, 0, 0, 0, 0, 0, 0, "", "")
		Spring.SetUnitBlocking(unitID, false, false, false, false)
	end

	local function removeBridge(unitID, unitDefID)
		local fp = bridgeDefs[unitDefID]
		local x1, z1, x2, z2 = getFootprintRect(unitID, fp)
		if not x1 then
			return
		end
		spRevertHeightMap(x1, z1, x2, z2, 1)
		spRebuildSmoothMesh(x1, z1, x2, z2)
	end

	local function fillTrench(unitID, unitDefID)
		local fp = trenchDefs[unitDefID]
		local x1, z1, x2, z2 = getFootprintRect(unitID, fp)
		if not x1 then
			return
		end
	-- revert to the original map height
		spRevertHeightMap(x1, z1, x2, z2, 1)
		spRebuildSmoothMesh(x1, z1, x2, z2)
	end

	function gadget:UnitFinished(unitID, unitDefID)
		if trenchDefs[unitDefID] then
			digTrench(unitID, unitDefID)
		elseif bridgeDefs[unitDefID] then
			buildBridge(unitID, unitDefID)
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID)
		if trenchDefs[unitDefID] then
			fillTrench(unitID, unitDefID)
		elseif bridgeDefs[unitDefID] then
			removeBridge(unitID, unitDefID)
		end
	end

	function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage)
	-- trenches and bridges are terrain: immune to weapon damage,
	-- removed by reclaiming instead
		if trenchDefs[unitDefID] or bridgeDefs[unitDefID] then
			return 0, 0
		end
		return damage, 1
	end

end
