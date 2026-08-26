---
--- Shared helpers for objective progress/completion and stage changes.
---

-- Activating and iterating triggers is handled through the triggers gadget.
local processTriggersOfType, activateTrigger

local function init(dependencies)
	processTriggersOfType = dependencies.processTriggersOfType
	activateTrigger       = dependencies.activateTrigger
end

-- Objectives are authored by the mission script, begin as dormant objectives,
-- are activated by the add action, and terminated via completion or failure.
-- The canceled state reflects an unterminated objective after a stage change.
local States = {
	Dormant   = 'dormant',
	Active    = 'active',
	Canceled  = 'canceled',
	Failed    = 'failed',
	Completed = 'completed',
}

local function isTerminal(objective)
	return objective.state == States.Completed
		or objective.state == States.Failed
end

-- placeholder until UI widget exists
local function warn(message)
	Spring.Log('objectives.lua', LOG.WARNING, "[Mission API] " .. message)
end

-- placeholder until UI widget exists
local function echoObjectiveUpdate(objectiveID, objective)
	Spring.Echo("Objective updated: " .. objectiveID
		.. " | " .. (objective.textKey or '')
		.. (objective.optional and " (optional)" or "")
		.. (objective.hidden and " (hidden)" or "")
		.. " | progress: " .. tostring(objective.progress)
		.. " | amount: " .. tostring(objective.amount)
		.. " | state: " .. tostring(objective.state))
end

local function changeStage(stageID)
	local missionAPI = GG['MissionAPI']
	local stageObjectiveIDs = (missionAPI.Stages[stageID] or {}).objectives or {}

	for objectiveID, objective in pairs(missionAPI.Objectives) do
		if objective.state == States.Active and not table.contains(stageObjectiveIDs, objectiveID) then
			objective.state = States.Canceled
			echoObjectiveUpdate(objectiveID, objective)
		end
	end

	missionAPI.CurrentStageID = stageID
	Spring.Echo("Stage set to: " .. stageID)
end

---@param amount integer? `nil` completes on any progress event, `0` only when exactly zero
local function isCompleteAtAmount(progress, amount)
	if amount == nil then
		return true
	elseif amount == 0 then
		return progress == 0
	end
	return progress >= amount
end

---Triggers of type `ObjectiveCompleted` that list an objective are activated
---only once all of the objectives they list notify them as being completed.
local function notifyObjectiveCompleted(completedObjectiveID)
	if not processTriggersOfType then
		return
	end

	local triggerTypes = (GG['MissionAPI'].TriggerDefinitions or {}).Types
	if not triggerTypes then
		return
	end

	local objectives = GG['MissionAPI'].Objectives
	processTriggersOfType(triggerTypes.ObjectiveCompleted, function(trigger)
		local objectiveIDs = trigger.parameters.objectiveIDs
		if not table.contains(objectiveIDs, completedObjectiveID) then
			return
		end
		for _, objectiveID in ipairs(objectiveIDs) do
			if objectives[objectiveID].state ~= States.Completed then
				return
			end
		end
		activateTrigger(trigger)
	end)
end

---Triggers of type `ObjectiveFailed` activate when notified of any failure.
local function notifyObjectiveFailed(failedObjectiveID)
	if not processTriggersOfType then return end

	local triggerTypes = (GG['MissionAPI'].TriggerDefinitions or {}).Types
	if not triggerTypes then return end

	processTriggersOfType(triggerTypes.ObjectiveFailed, function(trigger)
		if table.contains(trigger.parameters.objectiveIDs, failedObjectiveID) then
			activateTrigger(trigger)
		end
	end)
end

local function evaluateObjective(objectiveID, objective)
	if isCompleteAtAmount(objective.progress, objective.amount) then
		objective.state = States.Completed
		notifyObjectiveCompleted(objectiveID)
	end
	echoObjectiveUpdate(objectiveID, objective)
end

local function addObjective(objectiveID, optional)
	local objective = GG['MissionAPI'].Objectives[objectiveID]
	if objective.state ~= States.Dormant then
		warn("Objective is already added. Objective: " .. objectiveID)
		return
	end

	objective.optional = optional or false
	objective.state = States.Active
	objective.hidden = false

	-- Managed counts accrue at all times; objectives can complete instantly.
	if objective.amount ~= nil then
		objective.progress = objective.progress or 0
		evaluateObjective(objectiveID, objective)
	else
		echoObjectiveUpdate(objectiveID, objective)
	end
end

---Require that all setters choose an active or canceled objective.
local function getSettableObjective(objectiveID)
	local objective = GG['MissionAPI'].Objectives[objectiveID]
	if objective.state == States.Dormant then
		warn("Objective is still dormant. Objective: " .. objectiveID)
		return nil
	end
	if isTerminal(objective) then
		warn("Objective is already " .. objective.state .. ". Objective: " .. objectiveID)
		return nil
	end
	return objective
end

local function hideObjective(objectiveID)
	local objective = getSettableObjective(objectiveID)
	if not objective then
		return
	end

	objective.hidden = true
	echoObjectiveUpdate(objectiveID, objective)
end

local function activateObjective(objectiveID)
	local objective = getSettableObjective(objectiveID)
	if not objective then
		return
	end

	objective.state = States.Active
	objective.hidden = false

	if objective.amount ~= nil then
		objective.progress = objective.progress or 0
		evaluateObjective(objectiveID, objective)
	else
		echoObjectiveUpdate(objectiveID, objective)
	end
end

local function cancelObjective(objectiveID)
	local objective = getSettableObjective(objectiveID)
	if not objective then
		return
	end

	objective.state = States.Canceled
	echoObjectiveUpdate(objectiveID, objective)
end

local function completeObjective(objectiveID)
	local objective = getSettableObjective(objectiveID)
	if not objective then
		return
	end

	objective.state = States.Completed
	notifyObjectiveCompleted(objectiveID)
	echoObjectiveUpdate(objectiveID, objective)
end

local function failObjective(objectiveID)
	local objective = getSettableObjective(objectiveID)
	if not objective then
		return
	end

	objective.state = States.Failed
	notifyObjectiveFailed(objectiveID)
	echoObjectiveUpdate(objectiveID, objective)
end

local function incrementObjective(objectiveID)
	local objective = GG['MissionAPI'].Objectives[objectiveID]
	if objective.state ~= States.Active then
		return
	end

	objective.progress = (objective.progress or 0) + 1
	evaluateObjective(objectiveID, objective)
end

---Update objective progress for a managed (statistics-based) objective.
---Called when the trigger's event fires with updated counts. The count
---accrues in any state except terminated; completion requires active.
local function updateObjectiveProgress(objectiveID, eventTeamID, eventUnitDefName, eventUnitNames, direction, managedObjMetadata)
	if eventTeamID ~= managedObjMetadata.parameters.teamID then return end
	if managedObjMetadata.parameters.unitDefName and eventUnitDefName ~= managedObjMetadata.parameters.unitDefName then return end
	if managedObjMetadata.parameters.unitName and not (eventUnitNames or {})[managedObjMetadata.parameters.unitName] then return end

	local objective = GG['MissionAPI'].Objectives[objectiveID]
	if isTerminal(objective) then
		return
	end

	objective.progress = (objective.progress or 0) + direction

	if objective.state ~= States.Active then
		return
	end

	evaluateObjective(objectiveID, objective)
end

return {
	Init                       = init,
	States                     = States,
	ChangeStage                = changeStage,
	AddObjective               = addObjective,
	HideObjective              = hideObjective,
	ActivateObjective          = activateObjective,
	CancelObjective            = cancelObjective,
	FailObjective              = failObjective,
	CompleteObjective          = completeObjective,
	IncrementObjectiveProgress = incrementObjective,
	UpdateObjectiveProgress    = updateObjectiveProgress,
	EchoObjectiveUpdate        = echoObjectiveUpdate,
}
