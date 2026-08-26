local ParameterTypes = GG['MissionAPI'].Modules.ParameterTypes.Types

local function updateObjective(objectiveID, textKey)
	local objectives = GG["MissionAPI"].Modules.Objectives
	local objective = GG["MissionAPI"].Objectives[objectiveID]

	local state = objective.state
	if state ~= objectives.States.Active and state ~= objectives.States.Canceled then
		return
	end

	if textKey then
		objective.textKey = textKey
		objectives.EchoObjectiveUpdate(objectiveID, objective)
	else
		objectives.IncrementObjectiveProgress(objectiveID)
	end
end

return {
	{
		type = 'UpdateObjective',
		parameters = {
			{ name = 'objectiveID', required = true,  type = ParameterTypes.ObjectiveID },
			{ name = 'textKey',     required = false, type = ParameterTypes.String },
		},
		actionFunction = updateObjective,
	}
}
