local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

-- Fires when the last of the listed objectives is completed.
-- Declares no callins; the objectives module dispatches it (see objectives.lua).

return {
	type = 'ObjectiveCompleted',
	parameters = {
		{ name = 'objectiveIDs', required = true, type = ParameterTypes.ObjectiveIDs },
	},
}
