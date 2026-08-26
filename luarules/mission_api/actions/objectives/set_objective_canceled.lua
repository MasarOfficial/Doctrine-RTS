local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setObjectiveCanceled(objectiveID)
	GG['MissionAPI'].Modules.Objectives.CancelObjective(objectiveID)
end

return {
	{
		type = 'SetObjectiveCanceled',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = setObjectiveCanceled,
	}
}
