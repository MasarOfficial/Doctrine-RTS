local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when any of the listed objectives is marked failed.
-- Declares no callins; the objectives module dispatches it (see objectives.lua).

return {
	type = 'ObjectiveFailed',
	parameters = {
		{ name = 'objectiveIDs', required = true, type = ParameterTypes.ObjectiveIDs },
	},
}
