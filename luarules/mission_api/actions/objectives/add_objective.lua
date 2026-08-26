local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function addObjective(objectiveID, optional)
	GG['MissionAPI'].Modules.Objectives.AddObjective(objectiveID, optional)
end

return {
	{
		type = 'AddObjective',
		parameters = {
			{ name = 'objectiveID', required = true,  type = ParameterTypes.ObjectiveID },
			{ name = 'optional',    required = false, type = ParameterTypes.Boolean },
		},
		actionFunction = addObjective,
	}
}
