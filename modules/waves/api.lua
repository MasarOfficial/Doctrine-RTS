---@param name string
---@return table
local function gadgetSurface(name)
	local surface = GG.Waves
	assert(surface ~= nil, "Waves." .. name .. " called before the wave_director gadget initialized")
	return surface
end

return {
	---The spec is resolved once; the director never reads modoptions and
	---never mutates what it was handed.
	---@param spec WaveSpec
	---@return boolean started
	Start = function(spec)
		return gadgetSurface("Start").Start(spec)
	end,

	---@param name string
	---@return boolean stopped
	Stop = function(name)
		return gadgetSurface("Stop").Stop(name)
	end,

	---@param name string
	---@return boolean
	IsActive = function(name)
		return gadgetSurface("IsActive").IsActive(name)
	end,

	---Monotonic counters: they only ever climb inside a cycle, which is what
	---makes a mission condition written against them latched for free.
	---@param name string
	---@return WaveStatus|nil
	Status = function(name)
		return gadgetSurface("Status").Status(name)
	end,

	---The mission dial. 1.0 is the spec's own pace; below that is background
	---pressure, above it a siege. State, so it serializes.
	---@param name string
	---@param intensity number
	SetIntensity = function(name, intensity)
		gadgetSurface("SetIntensity").SetIntensity(name, intensity)
	end,

	---@param name string
	---@param overrides table|nil
	Surge = function(name, overrides)
		gadgetSurface("Surge").Surge(name, overrides)
	end,

	---@return string[]
	Names = function()
		return gadgetSurface("Names").Names()
	end,
}
