--- In multiplayer any player can send a synced chat action, so arming or
--- reloading a mission must not be an open verb.

local ChatGuard = {}

---@param isSinglePlayer boolean
---@param cheatsEnabled boolean
---@return boolean
function ChatGuard.IsAllowed(isSinglePlayer, cheatsEnabled)
	return isSinglePlayer == true or cheatsEnabled == true
end

return ChatGuard
