local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setObjectiveCompleted(objectiveID)
	GG['MissionAPI'].Modules.Objectives.CompleteObjective(objectiveID)
end

return {
	{
		type = 'SetObjectiveCompleted',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = setObjectiveCompleted,
	}
}
