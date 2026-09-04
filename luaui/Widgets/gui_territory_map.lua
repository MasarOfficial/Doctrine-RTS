include("keysym.h.lua")

-- =============================================================================
-- Territory Map UI Widget (Doctrine RTS / BAR Codebase)
-- File: luaui/Widgets/gui_territory_map.lua
-- =============================================================================
-- Displays full-screen/canvas strategic territory overlay when pressing 'M'.
-- Checks every single elmo on map "Без імені – копія (2)" and renders control
-- with exact faction hex colors, ET banks, HQ zones, and live statistics.
--
-- Hex Color Standards:
-- - Armada / Blue:          050093  (5, 0, 147)
-- - Cortex / Green:         417C5A  (65, 124, 90)
-- - Neutral:                417C5A  (65, 124, 90, subtle tint)
-- - Unclaimable Territory:  B4D2F3  (180, 210, 243)
-- =============================================================================

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Territory Map Overlay",
		desc = "Strategic Territory Canvas - Press M to open/close map of elmoses for 'Без імені – копія (2)'",
		author = "Doctrine RTS Team",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 50,
		enabled = true,
	}
end

-- Exact Color Definitions
local COLOR_ARMADA = { 0.0196, 0.0, 0.5765, 1.0 }        -- #050093 (Armada Blue)
local COLOR_CORTEX = { 0.2549, 0.4863, 0.3529, 1.0 }      -- #417C5A (Cortex Green)
local COLOR_NEUTRAL = { 0.2549, 0.4863, 0.3529, 0.30 }    -- #417C5A (Neutral Land Tint)
local COLOR_UNCLAIMABLE = { 0.7059, 0.8235, 0.9529, 0.95 } -- #B4D2F3 (Unclaimable Water/Obstacles)
local COLOR_PROTECTED_BORDER = { 1.0, 0.84, 0.0, 1.0 }    -- Gold for permanent HQ zones
local COLOR_BUILDING_RADIUS = { 0.2, 0.8, 1.0, 0.35 }     -- Expansion Building operational range

-- Widget State
local showMap = false
local mapName = "Без імені – копія (2)"
local cachedDisplayList = nil
local lastGridVersion = -1
local lastRebuildTime = 0

-- Localized Engine Call-ins for Performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetMouseState = Spring.GetMouseState
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam

-- OpenGL Call-ins
local glColor = gl.Color
local glRect = gl.Rect
local glPushMatrix = gl.PushMatrix
local glPopMatrix = gl.PopMatrix
local glLineWidth = gl.LineWidth
local glText = gl.Text
local glBeginEnd = gl.BeginEnd
local glVertex = gl.Vertex
local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local function GetTerritoryData()
	return (SYNCED and SYNCED.TerritoryControl) or GG.TerritoryControl or _G.TerritoryControl
end

-- Draw Circle Helper (Safe GL line loop)
local function DrawCircle(cx, cy, r, segments)
	segments = segments or 32
	local lineLoopMode = (GL and GL.LINE_LOOP) or 2
	glBeginEnd(lineLoopMode, function()
		for i = 0, segments - 1 do
			local theta = 2.0 * math.pi * (i / segments)
			local x = r * math.cos(theta)
			local y = r * math.sin(theta)
			glVertex(cx + x, cy + y)
		end
	end)
end

-- Rebuild the complete map display list (checks EVERY SINGLE ELMO / cell)
local function RebuildMapDisplayList(tc, canvasX, canvasY, canvasW, canvasH)
	if cachedDisplayList then
		glDeleteList(cachedDisplayList)
		cachedDisplayList = nil
	end

	if not tc or not tc.gridW or tc.gridW == 0 or not tc.gridH or tc.gridH == 0 then
		return
	end

	local gridW = tc.gridW
	local gridH = tc.gridH
	local cellW = canvasW / gridW
	local cellH = canvasH / gridH
	local quadsMode = (GL and GL.QUADS) or 7
	local linesMode = (GL and GL.LINES) or 1

	cachedDisplayList = glCreateList(function()
		-- 1. Batch Neutral & Land Background
		glColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3], COLOR_NEUTRAL[4])
		glRect(canvasX, canvasY, canvasX + canvasW, canvasY + canvasH)

		-- 2. Draw Every Single Elmo / Cell across the map
		-- Batch Armada cells (#050093)
		glColor(COLOR_ARMADA[1], COLOR_ARMADA[2], COLOR_ARMADA[3], COLOR_ARMADA[4])
		glBeginEnd(quadsMode, function()
			for gz = 0, gridH - 1 do
				local y1 = canvasY + (gridH - 1 - gz) * cellH
				local y2 = y1 + cellH
				for gx = 0, gridW - 1 do
					local idx = gz * gridW + gx
					if not tc.unclaimable[idx] and tc.cells[idx] == 0 then
						local x1 = canvasX + gx * cellW
						local x2 = x1 + cellW
						glVertex(x1, y1)
						glVertex(x2, y1)
						glVertex(x2, y2)
						glVertex(x1, y2)
					end
				end
			end
		end)

		-- Batch Cortex cells (#417C5A)
		glColor(COLOR_CORTEX[1], COLOR_CORTEX[2], COLOR_CORTEX[3], COLOR_CORTEX[4])
		glBeginEnd(quadsMode, function()
			for gz = 0, gridH - 1 do
				local y1 = canvasY + (gridH - 1 - gz) * cellH
				local y2 = y1 + cellH
				for gx = 0, gridW - 1 do
					local idx = gz * gridW + gx
					if not tc.unclaimable[idx] and tc.cells[idx] == 1 then
						local x1 = canvasX + gx * cellW
						local x2 = x1 + cellW
						glVertex(x1, y1)
						glVertex(x2, y1)
						glVertex(x2, y2)
						glVertex(x1, y2)
					end
				end
			end
		end)

		-- Batch Unclaimable cells (#B4D2F3)
		glColor(COLOR_UNCLAIMABLE[1], COLOR_UNCLAIMABLE[2], COLOR_UNCLAIMABLE[3], COLOR_UNCLAIMABLE[4])
		glBeginEnd(quadsMode, function()
			for gz = 0, gridH - 1 do
				local y1 = canvasY + (gridH - 1 - gz) * cellH
				local y2 = y1 + cellH
				for gx = 0, gridW - 1 do
					local idx = gz * gridW + gx
					if tc.unclaimable[idx] then
						local x1 = canvasX + gx * cellW
						local x2 = x1 + cellW
						glVertex(x1, y1)
						glVertex(x2, y1)
						glVertex(x2, y2)
						glVertex(x1, y2)
					end
				end
			end
		end)

		-- 3. Draw Protected HQ Starting Zones (100 cells per faction)
		for gz = 0, gridH - 1 do
			local y1 = canvasY + (gridH - 1 - gz) * cellH
			local y2 = y1 + cellH
			for gx = 0, gridW - 1 do
				local idx = gz * gridW + gx
				if tc.isProtected[idx] then
					local x1 = canvasX + gx * cellW
					local x2 = x1 + cellW
					glColor(COLOR_PROTECTED_BORDER[1], COLOR_PROTECTED_BORDER[2], COLOR_PROTECTED_BORDER[3], 0.6)
					glLineWidth(1)
					glRect(x1 + 0.5, y1 + 0.5, x2 - 0.5, y2 - 0.5)
				end
			end
		end

		-- 4. Subtle Grid Lines
		glColor(0.1, 0.15, 0.2, 0.15)
		glLineWidth(1)
		glBeginEnd(linesMode, function()
			for gx = 0, gridW, 10 do
				local x = canvasX + gx * cellW
				glVertex(x, canvasY)
				glVertex(x, canvasY + canvasH)
			end
			for gz = 0, gridH, 10 do
				local y = canvasY + gz * cellH
				glVertex(canvasX, y)
				glVertex(canvasX + canvasW, y)
			end
		end)
	end)

	lastGridVersion = tc.version or 1
end

function widget:Initialize()
	Spring.Echo("[Territory Map UI] Initialized - Press M to toggle strategic territory canvas")
end

function widget:Shutdown()
	if cachedDisplayList then
		glDeleteList(cachedDisplayList)
		cachedDisplayList = nil
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if isRepeat then return false end

	-- Check for 'M' key (SDL keysym 109 / 77 / KEYSYMS.m)
	if key == 109 or key == 77 or (KEYSYMS and (key == KEYSYMS.m or key == KEYSYMS.M))
		or (Spring.GetKeyCode and key == Spring.GetKeyCode("m")) then
		showMap = not showMap
		if showMap then
			lastGridVersion = -1 -- Force refresh of map data
		end
		return true
	end

	-- Escape key closes map if open
	if showMap and (key == 27 or (KEYSYMS and key == KEYSYMS.escape)) then
		showMap = false
		return true
	end

	return false
end

-- Main DrawScreen call-in
function widget:DrawScreen()
	if not showMap then return end

	local tc = GetTerritoryData()
	if not tc then
		-- Draw waiting screen if gadget not loaded yet
		local vsx, vsy = spGetViewGeometry()
		glColor(0, 0, 0, 0.7)
		glRect(0, 0, vsx, vsy)
		glColor(1, 1, 1, 1)
		glText("Territory Control System Initializing... (Press M to close)", vsx / 2 - 150, vsy / 2, 16, "o")
		return
	end

	local vsx, vsy = spGetViewGeometry()

	-- Window Layout Calculations
	local winW = math.min(vsx * 0.94, 1500)
	local winH = math.min(vsy * 0.90, 950)
	local winX = (vsx - winW) / 2
	local winY = (vsy - winH) / 2

	-- Canvas (Map) Layout: maintain aspect ratio (9216 / 6144 = 1.5)
	local maxCanvasW = winW - 320 -- Leave room for right sidebar
	local maxCanvasH = winH - 110 -- Leave room for header and footer
	local aspect = (tc.mapSizeX or 9216) / (tc.mapSizeZ or 6144)

	local canvasW = maxCanvasW
	local canvasH = canvasW / aspect
	if canvasH > maxCanvasH then
		canvasH = maxCanvasH
		canvasW = canvasH * aspect
	end

	local canvasX = winX + 20
	local canvasY = winY + 45 + (maxCanvasH - canvasH) / 2
	local sidebarX = canvasX + canvasW + 20
	local sidebarW = winX + winW - sidebarX - 20

	-- 1. Fullscreen Dimmer Backdrop
	glColor(0.02, 0.03, 0.05, 0.88)
	glRect(0, 0, vsx, vsy)

	-- 2. Canvas Modal Window
	glColor(0.08, 0.10, 0.14, 0.96)
	glRect(winX, winY, winX + winW, winY + winH)

	-- Window Header Bar
	glColor(0.12, 0.16, 0.22, 1.0)
	glRect(winX, winY + winH - 45, winX + winW, winY + winH)

	-- Header Border
	glColor(0.25, 0.35, 0.50, 1.0)
	glLineWidth(2)
	glRect(winX, winY, winX + winW, winY + winH)
	glLineWidth(1)

	-- Title
	glColor(1.0, 1.0, 1.0, 1.0)
	glText(string.format("STRATEGIC TERRITORY OVERLAY - MAP: %s", mapName), winX + 20, winY + winH - 30, 16, "o")

	glColor(0.65, 0.75, 0.85, 0.9)
	glText(string.format("Grid: 25m/Cell (%dx%d) | %d Total Cells | Map Size: %dx%d Elmos",
		tc.gridW, tc.gridH, tc.totalCells, tc.mapSizeX or 9216, tc.mapSizeZ or 6144),
		winX + 20, winY + winH - 42, 10, "o")

	-- Close Button [X]
	local closeBtnX = winX + winW - 35
	local closeBtnY = winY + winH - 35
	local mx, my = spGetMouseState()
	local isHoverClose = (mx >= closeBtnX - 5 and mx <= closeBtnX + 25 and my >= closeBtnY - 5 and my <= closeBtnY + 25)
	if isHoverClose then
		glColor(0.9, 0.2, 0.2, 1.0)
		glRect(closeBtnX - 5, closeBtnY - 5, closeBtnX + 25, closeBtnY + 25)
		glColor(1, 1, 1, 1)
	else
		glColor(0.8, 0.8, 0.8, 0.8)
	end
	glText("[X]", closeBtnX, closeBtnY, 14, "o")

	-- 3. Draw Territory Map Canvas (Compiled DisplayList of Every Single Elmo/Cell)
	if not cachedDisplayList or (tc.version and tc.version ~= lastGridVersion) then
		RebuildMapDisplayList(tc, canvasX, canvasY, canvasW, canvasH)
	end

	if cachedDisplayList then
		glCallList(cachedDisplayList)
	end

	-- Canvas Outer Border
	glColor(0.4, 0.5, 0.6, 0.8)
	glLineWidth(2)
	glRect(canvasX, canvasY, canvasX + canvasW, canvasY + canvasH)
	glLineWidth(1)

	-- 4. Dynamic Building Overlays (Radius Rings & ET status)
	local cellW = canvasW / tc.gridW
	local cellH = canvasH / tc.gridH

	if tc.buildings then
		for unitID, bData in pairs(tc.buildings) do
			local bx = canvasX + (bData.gridX + 0.5) * cellW
			local by = canvasY + (tc.gridH - 1 - bData.gridZ + 0.5) * cellH
			local radiusPx = bData.maxRadius * cellW

			-- Color by faction
			if bData.allyID == 0 then
				glColor(COLOR_ARMADA[1], COLOR_ARMADA[2], COLOR_ARMADA[3], 0.4)
			else
				glColor(COLOR_CORTEX[1], COLOR_CORTEX[2], COLOR_CORTEX[3], 0.4)
			end

			-- Operational Max Radius Circle (fixed, never shrinks)
			glLineWidth(1.5)
			DrawCircle(bx, by, radiusPx, 32)
			glLineWidth(1)

			-- Building Center Marker
			if bData.currentTokens > 0 then
				glColor(0.2, 1.0, 0.4, 0.9)
			else
				glColor(1.0, 0.2, 0.2, 0.9) -- Frozen (0 tokens)
			end
			glRect(bx - 3, by - 3, bx + 3, by + 3)

			-- ET Bank Text
			glColor(1, 1, 1, 0.9)
			glText(string.format("ET:%d/%d", bData.currentTokens, bData.maxRadius), bx - 16, by + 5, 8, "o")
		end
	end

	-- 5. Mobile Unit Positions
	local allUnits = spGetAllUnits and spGetAllUnits() or {}
	for _, uID in ipairs(allUnits) do
		local defID = spGetUnitDefID(uID)
		local ud = defID and UnitDefs[defID]
		if ud and ud.canMove and not ud.isImmobile and not ud.isBuilding then
			local ux, _, uz = spGetUnitPosition(uID)
			if ux and uz then
				local gx = math.floor(ux / CELL_SIZE)
				local gz = math.floor(uz / CELL_SIZE)
				local px = canvasX + (gx + 0.5) * cellW
				local py = canvasY + (tc.gridH - 1 - gz + 0.5) * cellH
				local aID = spGetUnitAllyTeam(uID) or spGetUnitTeam(uID)

				if aID == 0 then
					glColor(0.3, 0.6, 1.0, 1.0)
				else
					glColor(0.6, 1.0, 0.4, 1.0)
				end
				glRect(px - 2, py - 2, px + 2, py + 2)
			end
		end
	end

	-- 6. Right Sidebar: Statistics & Territory Dominance
	glColor(0.10, 0.13, 0.18, 0.95)
	glRect(sidebarX, winY + 45, winX + winW - 20, winY + winH - 60)
	glColor(0.25, 0.35, 0.45, 0.7)
	glLineWidth(1)
	glRect(sidebarX, winY + 45, winX + winW - 20, winY + winH - 60)

	local curY = winY + winH - 80
	glColor(1, 1, 1, 1)
	glText("TERRITORIAL CONTROL", sidebarX + 15, curY, 13, "o")
	curY = curY - 25

	local stats = tc.stats or {}
	local total = math.max(1, tc.totalCells or 1)
	local armadaPct = (stats.armadaCells or 0) / total * 100
	local cortexPct = (stats.cortexCells or 0) / total * 100
	local unclaimPct = (stats.unclaimableCells or 0) / total * 100
	local neutralPct = math.max(0, 100 - armadaPct - cortexPct - unclaimPct)

	-- Dominance Bar
	local barW = sidebarW - 30
	local barH = 16
	local barX = sidebarX + 15
	local bx1 = barX
	local bwArmada = barW * (armadaPct / 100)
	local bwCortex = barW * (cortexPct / 100)
	local bwUnclaim = barW * (unclaimPct / 100)
	local bwNeutral = barW - bwArmada - bwCortex - bwUnclaim

	-- Draw Dominance Bar Segments
	glColor(COLOR_ARMADA[1], COLOR_ARMADA[2], COLOR_ARMADA[3], 1)
	glRect(bx1, curY, bx1 + bwArmada, curY + barH)
	bx1 = bx1 + bwArmada

	glColor(COLOR_CORTEX[1], COLOR_CORTEX[2], COLOR_CORTEX[3], 1)
	glRect(bx1, curY, bx1 + bwCortex, curY + barH)
	bx1 = bx1 + bwCortex

	glColor(COLOR_UNCLAIMABLE[1], COLOR_UNCLAIMABLE[2], COLOR_UNCLAIMABLE[3], 1)
	glRect(bx1, curY, bx1 + bwUnclaim, curY + barH)
	bx1 = bx1 + bwUnclaim

	glColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3], 1)
	glRect(bx1, curY, bx1 + bwNeutral, curY + barH)

	glColor(0.5, 0.6, 0.7, 0.8)
	glLineWidth(1)
	glRect(barX, curY, barX + barW, curY + barH)
	curY = curY - 30

	-- Stats Breakdown
	-- Armada
	glColor(COLOR_ARMADA[1], COLOR_ARMADA[2], COLOR_ARMADA[3], 1)
	glRect(sidebarX + 15, curY - 2, sidebarX + 27, curY + 10)
	glColor(0.8, 0.9, 1.0, 1)
	glText(string.format("Armada (Blue): %d cells (%.1f%%)", stats.armadaCells or 0, armadaPct),
		sidebarX + 35, curY, 11, "o")
	curY = curY - 22

	-- Cortex
	glColor(COLOR_CORTEX[1], COLOR_CORTEX[2], COLOR_CORTEX[3], 1)
	glRect(sidebarX + 15, curY - 2, sidebarX + 27, curY + 10)
	glColor(0.8, 1.0, 0.8, 1)
	glText(string.format("Cortex (Green): %d cells (%.1f%%)", stats.cortexCells or 0, cortexPct),
		sidebarX + 35, curY, 11, "o")
	curY = curY - 22

	-- Neutral
	glColor(COLOR_NEUTRAL[1], COLOR_NEUTRAL[2], COLOR_NEUTRAL[3], 1)
	glRect(sidebarX + 15, curY - 2, sidebarX + 27, curY + 10)
	glColor(0.75, 0.85, 0.80, 1)
	glText(string.format("Neutral Land: %d cells (%.1f%%)", stats.neutralCells or 0, neutralPct),
		sidebarX + 35, curY, 11, "o")
	curY = curY - 22

	-- Unclaimable
	glColor(COLOR_UNCLAIMABLE[1], COLOR_UNCLAIMABLE[2], COLOR_UNCLAIMABLE[3], 1)
	glRect(sidebarX + 15, curY - 2, sidebarX + 27, curY + 10)
	glColor(0.7, 0.85, 1.0, 1)
	glText(string.format("Unclaimable: %d cells (%.1f%%)", stats.unclaimableCells or 0, unclaimPct),
		sidebarX + 35, curY, 11, "o")
	curY = curY - 30

	-- Protected Zones Info
	glColor(COLOR_PROTECTED_BORDER[1], COLOR_PROTECTED_BORDER[2], COLOR_PROTECTED_BORDER[3], 1)
	glRect(sidebarX + 15, curY - 2, sidebarX + 27, curY + 10)
	glColor(1, 0.95, 0.7, 1)
	glText("HQ Protected Zones: 100 cells/faction", sidebarX + 35, curY, 10, "o")
	curY = curY - 16
	glColor(0.7, 0.7, 0.7, 0.9)
	glText("(Enemies can NEVER recapture HQ cells)", sidebarX + 35, curY, 9, "o")
	curY = curY - 30

	-- Expansion Token (ET) System Status
	glColor(1, 1, 1, 1)
	glText("EXPANSION BASES (ET)", sidebarX + 15, curY, 12, "o")
	curY = curY - 18

	local bCount = 0
	local totalET = 0
	if tc.buildings then
		for _, bData in pairs(tc.buildings) do
			bCount = bCount + 1
			totalET = totalET + bData.currentTokens
		end
	end

	glColor(0.8, 0.9, 1.0, 0.9)
	glText(string.format("Active Military Bases: %d", bCount), sidebarX + 15, curY, 10, "o")
	curY = curY - 16
	glText(string.format("Total Remaining ET Pool: %d", totalET), sidebarX + 15, curY, 10, "o")
	curY = curY - 16
	glColor(0.65, 0.75, 0.85, 0.8)
	glText("Expansion Cost: 1 ET per grid cell", sidebarX + 15, curY, 9, "o")
	curY = curY - 14
	glText("Operational Range: Starting ET in cells", sidebarX + 15, curY, 9, "o")
	curY = curY - 30

	-- 7. Mouse Hover Inspector
	if mx >= canvasX and mx <= canvasX + canvasW and my >= canvasY and my <= canvasY + canvasH then
		local hGx = math.floor((mx - canvasX) / cellW)
		local hGz = tc.gridH - 1 - math.floor((my - canvasY) / cellH)

		if hGx >= 0 and hGx < tc.gridW and hGz >= 0 and hGz < tc.gridH then
			local hIdx = hGz * tc.gridW + hGx
			local hOwner = tc.cells[hIdx]
			local hIsProt = tc.isProtected[hIdx]
			local hUnclaim = tc.unclaimable[hIdx]
			local worldX = (hGx + 0.5) * CELL_SIZE
			local worldZ = (hGz + 0.5) * CELL_SIZE

			-- Draw Hover Box on Map
			local hx1 = canvasX + hGx * cellW
			local hy1 = canvasY + (tc.gridH - 1 - hGz) * cellH
			glColor(1, 1, 1, 0.7)
			glLineWidth(2)
			glRect(hx1, hy1, hx1 + cellW, hy1 + cellH)
			glLineWidth(1)

			-- Hover Info Panel
			glColor(1, 1, 0.3, 1)
			glText("HOVER INSPECTION", sidebarX + 15, curY, 11, "o")
			curY = curY - 16
			glColor(0.9, 0.9, 0.9, 1)
			glText(string.format("Elmo Pos: (%d, %d)", math.floor(worldX), math.floor(worldZ)), sidebarX + 15, curY, 9, "o")
			curY = curY - 14
			glText(string.format("Grid Cell: (%d, %d) [#%d]", hGx, hGz, hIdx), sidebarX + 15, curY, 9, "o")
			curY = curY - 14

			local ownerText = "Neutral / Unclaimed"
			if hUnclaim then
				ownerText = "Unclaimable (#B4D2F3)"
			elseif hOwner == 0 then
				ownerText = "Armada (#050093)"
			elseif hOwner == 1 then
				ownerText = "Cortex (#417C5A)"
			end
			glText(string.format("Status: %s", ownerText), sidebarX + 15, curY, 9, "o")
			curY = curY - 14

			if hIsProt then
				glColor(1, 0.8, 0, 1)
				glText("HQ Protected: YES (Permanent)", sidebarX + 15, curY, 9, "o")
			end
		end
	end

	-- 8. Footer Bar
	glColor(0.65, 0.75, 0.85, 0.8)
	glText("CONTROLS: Press [M] or [ESC] to Close Strategic Territory Overlay", winX + 20, winY + 15, 11, "o")
end

-- Mouse Click Handler to close when clicking [X] or outside window
function widget:MousePress(mx, my, button)
	if not showMap then return false end

	local vsx, vsy = spGetViewGeometry()
	local winW = math.min(vsx * 0.94, 1500)
	local winH = math.min(vsy * 0.90, 950)
	local winX = (vsx - winW) / 2
	local winY = (vsy - winH) / 2

	-- Close Button check
	local closeBtnX = winX + winW - 35
	local closeBtnY = winY + winH - 35
	if mx >= closeBtnX - 10 and mx <= closeBtnX + 30 and my >= closeBtnY - 10 and my <= closeBtnY + 30 then
		showMap = false
		return true
	end

	-- Click outside window closes it
	if mx < winX or mx > winX + winW or my < winY or my > winY + winH then
		showMap = false
		return true
	end

	return true -- Consume click while overlay is open
end
