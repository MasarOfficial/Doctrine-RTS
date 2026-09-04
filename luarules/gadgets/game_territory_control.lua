-- =============================================================================
-- Territory Control Gadget (Doctrine RTS / BAR Codebase)
-- File: luarules/gadgets/game_territory_control.lua
-- =============================================================================
-- Manages grid-based territory ownership, Expansion Tokens (ET), protected starting
-- zones, unit-driven territory expansion, and map control synchronization.
--
-- Mechanical Rules:
-- 1. Logical Grid: 1 cell ("map pixel") = exactly 25 meters (25 elmos) in Spring world coords.
-- 2. Permanent Starting Zone: 100 protected cells centered around each faction's main HQ.
-- 3. Structure Data & ET: Expansion buildings store Expansion Tokens.
--    - Starting Tokens define fixed maxRadius in cells (maxRadius = Starting Tokens, NEVER shrinks).
-- 4. Unit-Driven Expansion: Moving units capture cells if within maxRadius of a friendly
--    building with remaining tokens (currentTokens > 0). Deducts 1 token per captured cell.
-- 5. Unclaimable Territory: Marked regions (#B4D2F3 / water / obstacles) cannot be captured.
-- =============================================================================

function gadget:GetInfo()
	return {
		name = "Territory Control",
		desc = "Grid-based territory expansion system driven by moving units and Expansion Tokens (ET)",
		author = "Doctrine RTS Team",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Grid & Map Constants
local CELL_SIZE = 25 -- 1 grid cell = 25 meters (25 Spring elmos)
local MAP_NAME = "Без імені – копія (2)"
local UPDATE_INTERVAL = 15 -- Throttle GameFrame checks (every 15 frames = 2x per sec at 30 fps)
local DEFAULT_STARTING_TOKENS = 30 -- Default ET pool for expansion structures
local PROTECTED_HQ_CELL_COUNT = 100 -- Exactly 100 protected cells per faction starting zone

-- Building-specific starting Expansion Tokens (ET)
local BUILDING_EXPANSION_TOKENS = {
	["barracks"] = 30,
	["tank_factory"] = 35,
	["radar"] = 40,
	["defense_turret"] = 25,
	["power_plant"] = 20,
	["metal_extractor_armada"] = 15,
	["metal_extractor_cortex"] = 15,
	["energy_storage"] = 20,
	["metal_storage"] = 20,
	["missile_launcher"] = 30,
}

-- Faction color definitions (RGB 0-1)
local COLOR_ARMADA = { 0.0196, 0.0, 0.5765, 1.0 }        -- #050093
local COLOR_CORTEX = { 0.2549, 0.4863, 0.3529, 1.0 }      -- #417C5A
local COLOR_NEUTRAL = { 0.2549, 0.4863, 0.3529, 0.4 }     -- #417C5A (neutral land tint)
local COLOR_UNCLAIMABLE = { 0.7059, 0.8235, 0.9529, 1.0 } -- #B4D2F3

--------------------------------------------------------------------------------
-- SYNCED CODE
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	-- Territory State Table
	local territory = {
		mapName = MAP_NAME,
		cellSize = CELL_SIZE,
		mapSizeX = (Game and Game.mapSizeX) or 9216,
		mapSizeZ = (Game and Game.mapSizeZ) or 6144,
		gridW = 0,
		gridH = 0,
		totalCells = 0,
		cells = {},            -- cellIndex -> ownerAllyTeamID (0 = Armada, 1 = Cortex, nil = neutral)
		isProtected = {},      -- cellIndex -> boolean (true if cell is in permanent protected HQ zone)
		protectedFaction = {}, -- cellIndex -> allyTeamID (which faction owns protected cell)
		unclaimable = {},      -- cellIndex -> boolean (true if water / unclaimable obstacle)
		buildings = {},        -- unitID -> buildingData
		hqPositions = {},      -- allyTeamID -> { gridX = gx, gridZ = gz, worldX = wx, worldZ = wz }
		stats = {
			armadaCells = 0,
			cortexCells = 0,
			neutralCells = 0,
			unclaimableCells = 0,
			protectedCells = 0,
		},
		version = 1,           -- Incremented when grid changes to optimize UI caching
	}

	-- Coordinate Conversion Helpers
	local function WorldToGrid(wx, wz)
		local gx = math.floor(wx / CELL_SIZE)
		local gz = math.floor(wz / CELL_SIZE)
		return gx, gz
	end

	local function GridToWorld(gx, gz)
		return (gx + 0.5) * CELL_SIZE, (gz + 0.5) * CELL_SIZE
	end

	local function CellIndex(gx, gz)
		if gx < 0 or gx >= territory.gridW or gz < 0 or gz >= territory.gridH then
			return nil
		end
		return gz * territory.gridW + gx
	end

	local function IndexToGrid(idx)
		local gz = math.floor(idx / territory.gridW)
		local gx = idx % territory.gridW
		return gx, gz
	end

	-- Forward declarations
	local UpdateTerritoryStats

	-- Initialize grid dimensions and empty state
	local function InitializeGrid()
		territory.mapSizeX = (Game and Game.mapSizeX) or 9216
		territory.mapSizeZ = (Game and Game.mapSizeZ) or 6144
		territory.gridW = math.ceil(territory.mapSizeX / CELL_SIZE)
		territory.gridH = math.ceil(territory.mapSizeZ / CELL_SIZE)
		territory.totalCells = territory.gridW * territory.gridH

		Spring.Echo(string.format("[Territory Control] Initializing 25m Grid: %dx%d (%d cells total) for Map: %s",
			territory.gridW, territory.gridH, territory.totalCells, MAP_NAME))

		for i = 0, territory.totalCells - 1 do
			territory.cells[i] = nil
			territory.isProtected[i] = false
			territory.protectedFaction[i] = nil
			territory.unclaimable[i] = false
		end
	end

	-- Initialize unclaimable territory (matching #B4D2F3 water/impassable areas from map)
	local function InitializeUnclaimableTerritory()
		local unclaimableIntervals = {
			{0, 52, 228}, {0, 230, 234}, {0, 236, 245}, {78, 100, 100}, {79, 99, 99},
			{79, 101, 103}, {80, 97, 98}, {80, 103, 104}, {81, 103, 104}, {82, 103, 103},
			{83, 95, 96}, {83, 103, 103}, {84, 95, 95}, {84, 102, 103}, {85, 95, 102},
			{134, 100, 100}, {135, 98, 98}, {135, 100, 102}, {136, 98, 98}, {136, 102, 104},
			{137, 104, 104}, {138, 98, 98}, {138, 104, 104}, {139, 98, 98}, {139, 105, 105},
			{140, 98, 98}, {140, 105, 105}, {141, 99, 99}, {141, 104, 104}, {142, 99, 100},
			{142, 104, 104}, {143, 99, 101}, {143, 103, 104}, {144, 101, 102}, {169, 104, 106},
			{170, 106, 108}, {171, 102, 102}, {171, 108, 108}, {172, 102, 102}, {172, 108, 108},
			{173, 101, 101}, {173, 108, 109}, {174, 101, 102}, {174, 108, 109}, {175, 102, 103},
			{175, 105, 108}, {176, 104, 104}, {176, 107, 108}, {194, 112, 114}, {195, 114, 114},
			{196, 111, 111}, {196, 114, 115}, {197, 111, 112}, {197, 115, 115}, {198, 115, 115},
			{199, 112, 113}, {199, 115, 116}, {200, 112, 112}, {200, 116, 116}, {201, 112, 112},
			{201, 116, 116}, {202, 112, 116}, {248, 129, 130}, {249, 128, 132}, {250, 132, 133},
			{251, 133, 133}, {252, 133, 133}, {253, 125, 125}, {253, 133, 134}, {254, 125, 125},
			{254, 132, 134}, {255, 125, 125}, {256, 125, 125}, {256, 132, 132}, {257, 126, 126},
			{257, 131, 132}, {258, 131, 131}, {259, 125, 125}, {259, 129, 131}, {260, 126, 129},
			{306, 134, 141}, {306, 143, 143}, {307, 136, 137}, {307, 141, 145}, {308, 145, 146},
			{309, 132, 132}, {309, 145, 145}, {310, 144, 145}, {311, 144, 144}, {312, 131, 131},
			{312, 143, 144}, {313, 143, 143}, {314, 131, 131}, {314, 141, 143}, {315, 131, 134},
			{315, 139, 140}, {316, 133, 139}, {317, 136, 137}
		}

		local count = 0
		for _, interval in ipairs(unclaimableIntervals) do
			local gx = interval[1]
			local gzStart = interval[2]
			local gzEnd = interval[3]
			for gz = gzStart, gzEnd do
				local idx = CellIndex(gx, gz)
				if idx then
					territory.unclaimable[idx] = true
					count = count + 1
				end
			end
		end

		if Spring.GetGroundHeight then
			for gz = 0, territory.gridH - 1 do
				local wz = (gz + 0.5) * CELL_SIZE
				for gx = 0, territory.gridW - 1 do
					local wx = (gx + 0.5) * CELL_SIZE
					local gh = Spring.GetGroundHeight(wx, wz)
					if gh and gh < -5 then
						local idx = CellIndex(gx, gz)
						if idx and not territory.unclaimable[idx] then
							territory.unclaimable[idx] = true
							count = count + 1
						end
					end
				end
			end
		end

		Spring.Echo(string.format("[Territory Control] Initialized %d unclaimable cells (#B4D2F3)", count))
	end

	-- Initialize permanent 100-cell protected starting zone for each faction centered on HQ
	local function InitializeHQZones()
		local hqCoords = {}

		local teams = Spring.GetTeamList and Spring.GetTeamList() or { 0, 1 }
		for _, tID in ipairs(teams) do
			if tID == 0 or tID == 1 then
				local sx, sy, sz = nil, nil, nil
				if Spring.GetTeamStartPosition then
					sx, sy, sz = Spring.GetTeamStartPosition(tID)
				end
				if sx and sz and sx > 0 and sz > 0 then
					hqCoords[tID] = { x = sx, z = sz }
				end
			end
		end

		if not hqCoords[0] then
			hqCoords[0] = { x = 1200, z = 1200 }
		end
		if not hqCoords[1] then
			hqCoords[1] = { x = territory.mapSizeX - 1200, z = territory.mapSizeZ - 1200 }
		end

		for allyID, pos in pairs(hqCoords) do
			local hqGx, hqGz = WorldToGrid(pos.x, pos.z)
			hqGx = math.max(5, math.min(territory.gridW - 5, hqGx))
			hqGz = math.max(5, math.min(territory.gridH - 5, hqGz))

			territory.hqPositions[allyID] = {
				gridX = hqGx,
				gridZ = hqGz,
				worldX = pos.x,
				worldZ = pos.z,
			}

			local protectedCount = 0
			-- 10x10 square: dx from -5 to 4, dz from -5 to 4 = exactly 100 cells
			for dz = -5, 4 do
				for dx = -5, 4 do
					local gx = hqGx + dx
					local gz = hqGz + dz
					local idx = CellIndex(gx, gz)
					if idx then
						territory.cells[idx] = allyID
						territory.isProtected[idx] = true
						territory.protectedFaction[idx] = allyID
						territory.unclaimable[idx] = false
						protectedCount = protectedCount + 1
					end
				end
			end

			Spring.Echo(string.format("[Territory Control] Ally %d HQ at Grid (%d, %d) initialized with %d protected cells",
				allyID, hqGx, hqGz, protectedCount))
		end

		UpdateTerritoryStats()
	end

	-- Update summary cell counts
	function UpdateTerritoryStats()
		local armada = 0
		local cortex = 0
		local unclaimable = 0
		local protected = 0
		local neutral = 0

		for i = 0, territory.totalCells - 1 do
			if territory.unclaimable[i] then
				unclaimable = unclaimable + 1
			elseif territory.cells[i] == 0 then
				armada = armada + 1
			elseif territory.cells[i] == 1 then
				cortex = cortex + 1
			else
				neutral = neutral + 1
			end

			if territory.isProtected[i] then
				protected = protected + 1
			end
		end

		territory.stats.armadaCells = armada
		territory.stats.cortexCells = cortex
		territory.stats.neutralCells = neutral
		territory.stats.unclaimableCells = unclaimable
		territory.stats.protectedCells = protected
		territory.version = territory.version + 1
	end

	-- Initialize Gadget
	function gadget:Initialize()
		Spring.Echo("[Territory Control] Gadget Initializing (Synced)...")
		InitializeGrid()
		InitializeUnclaimableTerritory()
		InitializeHQZones()

		_G.TerritoryControl = territory
		GG.TerritoryControl = territory
	end

	function gadget:GameStart()
		Spring.Echo("[Territory Control] Game Start - Recalibrating HQ Zones...")
		local commanders = {}
		if Spring.GetAllUnits then
			for _, uID in ipairs(Spring.GetAllUnits()) do
				local defID = Spring.GetUnitDefID(uID)
				local ud = defID and UnitDefs[defID]
				if ud and (ud.customParams and ud.customParams.is_commander or ud.name:find("commander")) then
					local tID = Spring.GetUnitTeam(uID)
					local aID = Spring.GetUnitAllyTeam(uID) or tID
					local ux, _, uz = Spring.GetUnitPosition(uID)
					commanders[aID] = { x = ux, z = uz }
				end
			end
		end

		for aID, pos in pairs(commanders) do
			local hqGx, hqGz = WorldToGrid(pos.x, pos.z)
			hqGx = math.max(5, math.min(territory.gridW - 5, hqGx))
			hqGz = math.max(5, math.min(territory.gridH - 5, hqGz))

			territory.hqPositions[aID] = {
				gridX = hqGx,
				gridZ = hqGz,
				worldX = pos.x,
				worldZ = pos.z,
			}

			for dz = -5, 4 do
				for dx = -5, 4 do
					local gx = hqGx + dx
					local gz = hqGz + dz
					local idx = CellIndex(gx, gz)
					if idx then
						territory.cells[idx] = aID
						territory.isProtected[idx] = true
						territory.protectedFaction[idx] = aID
						territory.unclaimable[idx] = false
					end
				end
			end
		end

		UpdateTerritoryStats()
	end

	-- Hook: When an expansion structure finishes building
	function gadget:UnitFinished(unitID, unitDefID, teamID)
		local ud = UnitDefs[unitDefID]
		if not ud then return end

		local isStructure = ud.isBuilding or ud.isImmobile or not ud.canMove or (ud.speed and ud.speed == 0)
		if not isStructure then return end

		local startingTokens = DEFAULT_STARTING_TOKENS
		if ud.customParams and ud.customParams.expansion_tokens then
			startingTokens = tonumber(ud.customParams.expansion_tokens) or DEFAULT_STARTING_TOKENS
		elseif BUILDING_EXPANSION_TOKENS[ud.name] then
			startingTokens = BUILDING_EXPANSION_TOKENS[ud.name]
		end

		local ux, uy, uz = Spring.GetUnitPosition(unitID)
		if not ux or not uz then return end

		local gx, gz = WorldToGrid(ux, uz)
		local allyID = Spring.GetUnitAllyTeam(unitID) or teamID

		-- Rule 2: Initial number of tokens permanently defines maxRadius in grid cells
		-- Radius in cells = Starting Tokens. This radius NEVER shrinks, even when tokens are spent.
		local maxRadius = startingTokens
		local maxRadiusSq = maxRadius * maxRadius

		territory.buildings[unitID] = {
			unitID = unitID,
			unitDefID = unitDefID,
			unitName = ud.name,
			teamID = teamID,
			allyID = allyID,
			gridX = gx,
			gridZ = gz,
			worldX = ux,
			worldZ = uz,
			startingTokens = startingTokens,
			maxRadius = maxRadius,     -- FIXED: Never shrinks
			maxRadiusSq = maxRadiusSq, -- Pre-computed squared radius
			currentTokens = startingTokens,
		}

		Spring.Echo(string.format("[Territory Control] Expansion Building Finished: %s (Unit %d) at Grid (%d, %d) | ET: %d | MaxRadius: %d cells",
			ud.name, unitID, gx, gz, startingTokens, maxRadius))
	end

	-- Hook: When building is destroyed
	function gadget:UnitDestroyed(unitID, unitDefID, teamID)
		if territory.buildings[unitID] then
			territory.buildings[unitID] = nil
		end
	end

	-- Hook: When building changes ownership
	function gadget:UnitGiven(unitID, unitDefID, newTeamID, oldTeamID)
		if territory.buildings[unitID] then
			territory.buildings[unitID].teamID = newTeamID
			territory.buildings[unitID].allyID = Spring.GetUnitAllyTeam(unitID) or newTeamID
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
		if territory.buildings[unitID] then
			territory.buildings[unitID].teamID = newTeamID
			territory.buildings[unitID].allyID = Spring.GetUnitAllyTeam(unitID) or newTeamID
		end
	end

	-- Rule 3: UNIT-DRIVEN EXPANSION LOGIC
	-- Throttled execution in GameFrame to prevent server lag
	function gadget:GameFrame(frameNum)
		if frameNum % UPDATE_INTERVAL ~= 0 then
			return
		end

		local allUnits = Spring.GetAllUnits and Spring.GetAllUnits() or {}
		local changedAny = false

		for _, unitID in ipairs(allUnits) do
			-- Check if unit is alive and mobile
			local defID = Spring.GetUnitDefID(unitID)
			local ud = defID and UnitDefs[defID]

			if ud and ud.canMove and not ud.isImmobile and not ud.isBuilding then
				local ux, uy, uz = Spring.GetUnitPosition(unitID)
				if ux and uz then
					local gx, gz = WorldToGrid(ux, uz)
					local idx = CellIndex(gx, gz)

					if idx then
						local unitAllyID = Spring.GetUnitAllyTeam(unitID) or Spring.GetUnitTeam(unitID)
						local currentOwner = territory.cells[idx]

						-- If unit steps onto a grid cell that does not belong to its faction/alliance
						if currentOwner ~= unitAllyID then
							-- Check Rule 1: Protected 100-cell HQ starting zones can NEVER be recaptured or erased by enemies
							local isCellProtected = territory.isProtected[idx]
							local isUnclaimable = territory.unclaimable[idx]

							if not isCellProtected and not isUnclaimable then
								-- Find the closest friendly expansion building with tokens remaining
								local closestBuilding = nil
								local closestDistSq = math.huge

								for _, bData in pairs(territory.buildings) do
									if bData.allyID == unitAllyID and bData.currentTokens > 0 then
										local dx = gx - bData.gridX
										local dz = gz - bData.gridZ
										-- Use squared distance (dx*dx + dz*dz) to avoid heavy math.sqrt operations
										local distSq = dx * dx + dz * dz

										-- Compare against fixed maxRadius * maxRadius
										if distSq <= bData.maxRadiusSq then
											if distSq < closestDistSq then
												closestDistSq = distSq
												closestBuilding = bData
											end
										end
									end
								end

								-- If within fixed maxRadius AND building has tokens left:
								if closestBuilding and closestBuilding.currentTokens > 0 then
									-- Change ownership of grid cell to unit's alliance
									territory.cells[idx] = unitAllyID
									-- Deduct exactly 1 token from building's currentTokens bank
									closestBuilding.currentTokens = closestBuilding.currentTokens - 1

									changedAny = true
								end
							end
						end
					end
				end
			end
		end

		if changedAny then
			UpdateTerritoryStats()
		end
	end

	-- Synced Territory API Methods
	function territory:GetOwner(x, z)
		local gx, gz = WorldToGrid(x, z)
		local idx = CellIndex(gx, gz)
		return idx and self.cells[idx] or nil
	end

	function territory:GetCellOwnerByIndex(idx)
		return self.cells[idx]
	end

	function territory:IsProtected(x, z)
		local gx, gz = WorldToGrid(x, z)
		local idx = CellIndex(gx, gz)
		return idx and self.isProtected[idx] or false
	end

	function territory:IsUnclaimable(x, z)
		local gx, gz = WorldToGrid(x, z)
		local idx = CellIndex(gx, gz)
		return idx and self.unclaimable[idx] or false
	end

	function territory:GetCellCount(allyID)
		local count = 0
		for i = 0, self.totalCells - 1 do
			if self.cells[i] == allyID then
				count = count + 1
			end
		end
		return count
	end

	function territory:ReplenishTokens(unitID, amount)
		if self.buildings[unitID] then
			self.buildings[unitID].currentTokens = math.min(
				self.buildings[unitID].maxRadius,
				self.buildings[unitID].currentTokens + amount
			)
			return true
		end
		return false
	end

	function territory:GetBuildingData(unitID)
		return self.buildings[unitID]
	end

	function territory:GetStats()
		return self.stats
	end

else
	--------------------------------------------------------------------------------
	-- UNSYNCED CODE (Minimap / World Visualization fallbacks)
	--------------------------------------------------------------------------------
	function gadget:Initialize()
		Spring.Echo("[Territory Control] Gadget Initializing (Unsynced)...")
	end
end

-- Registration
if gadgetHandler then
	gadgetHandler:Register(gadget)
else
	gadget:Initialize()
end
