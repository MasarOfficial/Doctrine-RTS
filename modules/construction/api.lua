--- Transfer applies the build delay (it knows a unit changed hands); construction serves it,
--- because whether a build step is allowed is construction's question and the engine asks it here.

local Debuff = VFS.Include("modules/construction/lib/build_debuff.lua")

return {
	---@param unitID integer
	---@param seconds number
	DelayBuilder = function(unitID, seconds)
		Debuff.Apply(unitID, seconds)
	end,

	---@param unitID integer
	---@return boolean
	IsBuilderDelayed = function(unitID)
		return Debuff.IsDelayed(unitID)
	end,
}
