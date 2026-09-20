--------------------------------------------------------------------------------
-- Phase Collision Toggle
--
-- Units marked customParams.phase_togglable get a toggle command in the
-- attack menu that turns their collision volume off (phased) and back on.
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Phase Collision Toggle",
		desc = "Attack-menu toggle that disables/re-enables a unit's collision",
	author = "Doctrine RTS",
		date = "2025",
	license = "GNU GPL, v2 or later",
		layer = 0,
	enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

	local spSetUnitCollisionVolumeData = Spring.SetUnitCollisionVolumeData
	local spSetUnitBlocking = Spring.SetUnitBlocking

	local CMD_PHASE = 32460 -- custom cmd id (must be unique, 32256..32767 allowed range)

	local phaseDefs = {} -- [unitDefID] = true
	for udefID, udef in pairs(UnitDefs) do
		if udef.customParams and udef.customParams.phase_togglable then
			phaseDefs[udefID] = true
		end
	end

	local phasedUnits = {} -- [unitID] = true when collision is OFF

	gadgetHandler:RegisterCMDID(CMD_PHASE)

	-- attack-menu toggle button (mode 0 = collide, 1 = phased/no collision)
	local phaseCmd = {
		id = CMD_PHASE,
		type = CMDTYPE.ICON_MODE,
		name = "Phase",
		cursor = "attack",
		action = "phase",
	tooltip = "Phase: toggle collision. When phased, projectiles and units pass through.",
		params = { 0, "collide", "phased" },
	}

	local function setPhased(unitID, unitDefID, phased)
		if phased then
			phasedUnits[unitID] = true
			-- disable collision volume entirely
			spSetUnitCollisionVolumeData(unitID, false, 0, 0, 0, 0, 0, 0, "", "")
			spSetUnitBlocking(unitID, false, false, false, false)
		else
			phasedUnits[unitID] = nil
			-- restore the def's collision volume (re-apply from unitdef)
			local ud = UnitDefs[unitDefID]
			spSetUnitCollisionVolumeData(
				unitID,
				true,
				0,
				0,
				0,
				(ud.collisionvolumescales and tonumber(ud.collisionvolumescales:match("([%-%d%.]+)"))) or 30,
				(ud.collisionvolumescales and tonumber(ud.collisionvolumescales:match("([%-%d%.]+)%s+([%-%d%.]+)"))) or 30,
				(ud.collisionvolumescales and tonumber(ud.collisionvolumescales:match("([%-%d%.]+)%s+[%-%d%.]+%s+([%-%d%.]+)"))) or 30,
				ud.collisionvolumetype or "Box",
				""
			)
			spSetUnitBlocking(unitID, true, true, true)
		end
	end

	function gadget:AllowCommand(
		unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua
	)
		if cmdID == CMD_PHASE then
			if phaseDefs[unitDefID] then
				setPhased(unitID, unitDefID, not phasedUnits[unitID])
			end
			return false -- command consumed, not queued
		end
		return true
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if phaseDefs[unitDefID] then
			-- make sure the toggle appears in the command menu with mode icons
			Spring.InsertUnitCmdDesc(unitID, phaseCmd)
			setPhased(unitID, unitDefID, false)
		end
	end

	function gadget:UnitDestroyed(unitID)
	phasedUnits[unitID] = nil
	end

	function gadget:Initialize()
		Spring.SetCustomCommandDrawData(CMD_PHASE, CMDTYPE.ICON_MODE, { 0.4, 0.7, 1, 0.8 }, true)
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end

end
