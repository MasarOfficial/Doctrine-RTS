--- Waves contributes no words of its own: the verbs ride the pack handle a flavor module
--- hands out (WavesVerbs.Pack), so the vocabulary a mission may say is exactly the set of
--- packs the modules its manifest requires publish. What it does contribute is the
--- context those verbs act through, and the events the director raises.

local Events = VFS.Include("modules/waves/lib/events.lua")
local ModuleHandler = VFS.Include("modules/module_handler.lua")

return {
	-- No Finalize: waves arms nothing at load, so a file that fails to parse
	-- leaves no director behind.
	---@param file MissionDslFile
	ForFile = function(file)
		return { env = {} }
	end,
	Events = Events,
	---@param runtime MissionRuntime
	Context = function(runtime)
		return {
			---@param request table what a pack's Begin composed
			StartWaves = function(request)
				local flavor = ModuleHandler.Get(request.module)
				if flavor == nil or flavor.Start == nil then
					runtime.Log(
						LOG.ERROR,
						tostring(request.pack) .. ".Begin: module " .. tostring(request.module) .. " cannot start waves"
					)
					return
				end
				flavor.Start(request)
			end,
			StopWaves = function(pack)
				ModuleHandler.Get("waves").Stop(pack)
			end,
			SetWaveIntensity = function(pack, intensity)
				ModuleHandler.Get("waves").SetIntensity(pack, intensity)
			end,
			SurgeWaves = function(pack)
				ModuleHandler.Get("waves").Surge(pack)
			end,
			WaveStatus = function(pack)
				return ModuleHandler.Get("waves").Status(pack)
			end,
		}
	end,
}
