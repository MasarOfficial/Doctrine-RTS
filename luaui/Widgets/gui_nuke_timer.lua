--------------------------------------------------------------------------------
-- Nuke Silo Timer
-- Draws a DD:HH:MM:SS countdown above nuclear missile silos,
-- showing time until the next stockpiled missile is ready.
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Nuke Silo Timer",
		desc = "Shows a DD:HH:MM:SS countdown above nuclear silos",
	author = "Doctrine RTS",
		date = "2025",
	license = "GPL v2 or later",
		layer = 5,
	enabled = true,
	}
end

--------------------------------------------------------------------------------
-- Speedups
--------------------------------------------------------------------------------
local spGetGameFrame = Spring.GetGameFrame
local spGetGameSeconds = Spring.GetGameSeconds
local spGetUnitStockpile = Spring.GetUnitStockpile
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
local spGetUnitIsDead = Spring.GetUnitIsDead

local glBillboard = gl.Billboard
local glColor = gl.Color
local glText = gl.Text
local glDepthTest = gl.DepthTest

local myAllyTeamID = spGetMyAllyTeamID()
local isSpec = spGetSpectatingState()

--------------------------------------------------------------------------------
-- Find nuclear silo unitdefs (units with a stockpile weapon flagged nuclear)
--------------------------------------------------------------------------------
local nukeUnits = {} -- [unitDefID] = weaponNumber (1-based)

for udefID, udef in pairs(UnitDefs) do
	if udef.weapons then
		for wnum = 1, #udef.weapons do
			local wd = udef.weapons[wnum] and WeaponDefs[udef.weapons[wnum].weaponDef]
			if wd and wd.stockpile and wd.customParams and wd.customParams.nuclear then
				nukeUnits[udefID] = wnum
				break
			end
		end
	end
end

-- stockpileTime is in seconds in the unitdef
local stockpileTime = {} -- [unitDefID] = seconds to stockpile one missile
for udefID, _ in pairs(nukeUnits) do
	local wdef = UnitDefs[udefID].weapons and UnitDefs[udefID].weapons[nukeUnits[udefID]]
	stockpileTime[udefID] = wdef and WeaponDefs[wdef.weaponDef].stockpileTime or 120
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local watchedUnits = {} -- [unitID] = unitDefID

local function canSee(unitID, unitAllyTeam)
	if isSpec then
		return true
	end
	return unitAllyTeam == myAllyTeamID
end

-- Format seconds as DD:HH:MM:SS
local function formatDDHHMMSS(seconds)
	if seconds < 0 then
	seconds = 0
	end
	local d = seconds // 86400
	local h = (seconds % 86400) // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	return string.format("%02d:%02d:%02d:%02d", d, h, m, s)
end

--------------------------------------------------------------------------------
-- Callins
--------------------------------------------------------------------------------
function widget:UnitCreated(unitID, unitDefID)
	if nukeUnits[unitDefID] then
		watchedUnits[unitID] = unitDefID
	end
end

function widget:UnitDestroyed(unitID)
	watchedUnits[unitID] = nil
end

function widget:UnitGiven(unitID, unitDefID)
	if nukeUnits[unitDefID] then
		watchedUnits[unitID] = unitDefID
	else
		watchedUnits[unitID] = nil
	end
end

function widget:PlayerChanged()
	myAllyTeamID = spGetMyAllyTeamID()
	isSpec = spGetSpectatingState()
end

-- Re-scan existing units on init / load game
function widget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		widget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end

function widget:Shutdown()
	watchedUnits = {}
end

--------------------------------------------------------------------------------
-- Draw
--------------------------------------------------------------------------------
local UPDATE_PERIOD = 10 -- frames between countdown recalcs
local nextText = {} -- [unitID] = cached text

function widget:Update()
	local frame = spGetGameFrame()
	if frame % UPDATE_PERIOD ~= 0 then
		return
	end

	for unitID, unitDefID in pairs(watchedUnits) do
		if spGetUnitIsDead(unitID) then
			watchedUnits[unitID] = nil
			nextText[unitID] = nil
		else
			local unitAllyTeam = spGetUnitAllyTeam(unitID)
			if not canSee(unitID, unitAllyTeam) then
				nextText[unitID] = nil
			else
				local numStockpiled, numQueued, buildPercent = spGetUnitStockpile(unitID)
				if numStockpiled == nil then
					nextText[unitID] = nil
				elseif numStockpiled > 0 or (numQueued or 0) == 0 then
					-- missile ready (or nothing being built)
					nextText[unitID] = (numStockpiled > 0) and "READY" or nil
				else					-- buildPercent is 0..1 progress of current missile
					local progress = buildPercent or 0
					local stunned = spGetUnitIsStunned(unitID)
					local remaining = (1 - progress) * stockpileTime[unitDefID]
					if stunned then
						nextText[unitID] = formatDDHHMMSS(remaining) .. " (stalled)"
					else
						nextText[unitID] = formatDDHHMMSS(remaining)
					end
				end
			end
		end
	end
end

function widget:DrawWorld()
	if not next(nextText) then
		return
	end

	glDepthTest(true)
	for unitID, text in pairs(nextText) do
		if text then
			local x, y, z = spGetUnitPosition(unitID)
			if x then
				-- place text above the silo (silos are tall; use fixed offset)
				glColor(1, 0.3, 0.2, 0.9)
				glBillboard(x, y + 70, z)
				glText(text, 0, 0, 14, "cno")
				glColor(1, 1, 1, 1)
			end
		end
	end
	glDepthTest(false)
end
