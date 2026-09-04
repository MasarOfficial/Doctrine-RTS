-- =============================================================================
-- Anti-Cheat Gadget: Sans Boss Fight Enforcement (Doctrine RTS / BAR Codebase)
-- File: luarules/gadgets/game_sans_anticheat.lua
-- =============================================================================
-- Detects unauthorized cheat activations or anomalies. Upon detection, it triggers
-- the native standalone Sans Boss Fight application ("c2-sans-fight-main") without
-- opening any web browser.
-- =============================================================================

function gadget:GetInfo()
	return {
		name = "Sans Anti-Cheat",
		desc = "Launches the standalone Sans Boss Fight penalty window on cheat detection",
		author = "Doctrine RTS Team",
		date = "2025",
		license = "GNU GPL, v2 or later",
		layer = 99999,
		enabled = true,
	}
end

local isTriggered = false
local launcherPath = "c2-sans-fight-main\\launch_sans_anticheat.py"

local function TriggerSansFight(reason, playerName)
	if isTriggered then return end
	isTriggered = true

	local alertMsg = string.format("⚠️ [ANTI-CHEAT DETECTED] %s - CHEATER DETECTED: %s! PREPARE TO HAVE A BAD TIME!",
		(playerName or "PLAYER"), (reason or "Unauthorized Cheats Enabled"))
	
	Spring.Echo(alertMsg)
	Spring.SendMessage(alertMsg)

	-- Launch the native desktop window via Python launcher (No Web Browser)
	local pythonCmd = 'start /b python "' .. launcherPath .. '"'
	if os.execute then
		os.execute(pythonCmd)
	elseif io and io.popen then
		local handle = io.popen(pythonCmd)
		if handle then handle:close() end
	end
end

--------------------------------------------------------------------------------
-- SYNCED CODE
--------------------------------------------------------------------------------
if gadgetHandler:IsSyncedCode() then

	function gadget:Initialize()
		Spring.Echo("[Sans Anti-Cheat] Initialized and monitoring game state...")
	end

	function gadget:GameFrame(n)
		-- Check every 30 frames (1s) if engine cheats were forcefully enabled
		if n % 30 == 0 then
			if Spring.IsCheatingEnabled and Spring.IsCheatingEnabled() then
				TriggerSansFight("Spring Engine Cheats Enabled (/cheat)", "Player")
			end
		end
	end

	function gadget:GotChatMsg(msg, playerID)
		if not msg then return end
		local lowerMsg = msg:lower()

		-- Chat trigger commands for testing or manual moderation
		if lowerMsg == "/sans" or lowerMsg == "!sans" or lowerMsg == "/testanticheat" or lowerMsg:find("cheat") == 1 then
			local name = Spring.GetPlayerInfo(playerID) or "Player"
			TriggerSansFight("Cheat Triggered via Console: " .. msg, name)
			return true
		end
	end

else
	--------------------------------------------------------------------------------
	-- UNSYNCED CODE
	--------------------------------------------------------------------------------
	function gadget:GotChatMsg(msg, playerID)
		if not msg then return end
		local lowerMsg = msg:lower()
		if lowerMsg == "/sans" or lowerMsg == "!sans" or lowerMsg == "/testanticheat" then
			TriggerSansFight("Manual Anticheat Test", "LocalPlayer")
		end
	end
end

if gadgetHandler then
	gadgetHandler:Register(gadget)
else
	gadget:Initialize()
end
