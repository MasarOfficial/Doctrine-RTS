--- Which options sit on the ladder is each scheme's business (policies/); the tax rate that reads a tier lives with transfer, which owns what a transfer costs.
local TechTier = {}

---@param opts table modoptions
---@param baseKey string
---@param techLevel number
function TechTier.resolveByTechLevel(opts, baseKey, techLevel)
	if techLevel >= 3 then
		local v = opts[baseKey .. "_at_t3"]
		if v ~= nil and v ~= "" then
			return v
		end
	end
	if techLevel >= 2 then
		local v = opts[baseKey .. "_at_t2"]
		if v ~= nil and v ~= "" then
			return v
		end
	end
	return opts[baseKey]
end

return TechTier
