local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function setObjectiveHidden(objectiveID)
	GG['MissionAPI'].Modules.Objectives.HideObjective(objectiveID)
end

return {
	{
		type = 'SetObjectiveHidden',
		parameters = {
			{ name = 'objectiveID', required = true, type = ParameterTypes.ObjectiveID },
		},
		actionFunction = setObjectiveHidden,
	}
}
