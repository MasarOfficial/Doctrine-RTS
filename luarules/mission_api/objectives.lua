---
---

local function changeStage(stageID)
	GG['MissionAPI'].CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)
end

-- placeholder until UI widget exists
local function echoObjectiveUpdate(objectiveID, objective)
	Spring.Echo("Objective updated: " .. objectiveID
		.. " | " .. (objective.textKey or '')
		.. " | progress: " .. tostring(objective.progress)
		.. " | amount: " .. tostring(objective.amount)
		.. " | completed: " .. tostring(objective.completed))
end

--- Update objective progress for a managed (statistics-based) objective.
local function updateObjectiveProgress(objectiveID, eventTeamID, eventUnitDefName, eventUnitNames, direction, managedObjMetadata)
	if eventTeamID ~= managedObjMetadata.parameters.teamID then return end
	if managedObjMetadata.parameters.unitDefName and eventUnitDefName ~= managedObjMetadata.parameters.unitDefName then return end
	if managedObjMetadata.parameters.unitName and not (eventUnitNames or {})[managedObjMetadata.parameters.unitName] then return end

	local objective = GG['MissionAPI'].Objectives[objectiveID]
	if objective.completed then return end



end

return {
}
