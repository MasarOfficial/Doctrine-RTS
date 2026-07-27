--- Owned here because the engine asks construction whether a build step is allowed, and
--- that answer cannot live in a module above this one. Transfer writes through the module API; nothing else does.

local PolicyEvents = VFS.Include("modules/context/policy_events.lua")

local delayed = {} ---@type table<integer, integer> unitID -> expire frame

local Debuff = {}

---@param unitID integer
---@param seconds number
function Debuff.Apply(unitID, seconds)
	local startFrame = Spring.GetGameFrame()
	local expireFrame = startFrame + (seconds * Game.gameSpeed)
	delayed[unitID] = expireFrame
	PolicyEvents.NotifyBuildDelay(unitID, startFrame, expireFrame)
end

---@param unitID integer
---@return boolean
function Debuff.IsDelayed(unitID)
	return delayed[unitID] ~= nil
end

---@param unitID integer
---@return boolean released
function Debuff.Release(unitID)
	if delayed[unitID] == nil then
		return false
	end
	delayed[unitID] = nil
	PolicyEvents.NotifyBuildDelayEnd(unitID)
	return true
end

---@param frame integer
function Debuff.Expire(frame)
	for unitID, expireFrame in pairs(delayed) do
		if frame >= expireFrame then
			Debuff.Release(unitID)
		end
	end
end

return Debuff
