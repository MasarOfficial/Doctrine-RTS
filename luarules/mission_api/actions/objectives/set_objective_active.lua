local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setObjectiveActive(objectiveID)
	GG['MissionAPI'].Modules.Objectives.ActivateObjective(objectiveID)
end

return {
	{
		type = 'SetObjectiveActive',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = setObjectiveActive,
	}
}
