--- Matchflow is the one owner of the verdict, so the noun for "how the match ends" and the
--- deathmode serializer live HERE; a grammar that lets a mode own the end imports both.

--- Serializers ride on the same table for GRAMMARS to merge; a preset has no
--- business with them, so the class leaves them undeclared.
---@class MatchflowModeDSL
---@field End MatchflowModeNoun how the match ends; a mode that owns it scripts the verdict

local M = {}
---@cast M MatchflowModeDSL

M.End = { domain = "end" }

M.Serializers = {
	-- triggers own the verdict: engine elimination never ends the match
	["end.scripted"] = function(_p, lock)
		return { deathmode = { value = "neverend", locked = lock.structure } }
	end,
}

return M
