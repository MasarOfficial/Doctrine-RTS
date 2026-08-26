local parameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')
local schemaUtils = VFS.Include('luarules/mission_api/schema_utils.lua')

--[[
	objectiveID = {
		textKey = "complete_objective",
		amount = 3,
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 3,
			},
		},
		coop = true,
	},
]]

local function processRawObjectives(rawObjectives, rawTriggers, rawActions)
	local objectives = rawObjectives or {}

	local actionTypes = GG['MissionAPI'].ActionDefinitions.Types
	local triggerTypesWithQuantity = schemaUtils.GetTypesWithParameterType(GG['MissionAPI'].TriggerDefinitions.Parameters, parameterTypes.Types.Quantity)

	local States = GG['MissionAPI'].Modules.Objectives.States
	for _, objective in pairs(objectives) do
		if type(objective) == 'table' then
			objective.state = States.Dormant
		end
	end

	for objectiveID, objective in pairs(objectives) do
		if type(objectiveID) == 'string' and type(objective) == 'table' and type(objective.trigger) == 'table' then
			local amount = objective.amount
			local triggerType = objective.trigger.type
			local triggerParameters = type(objective.trigger.parameters) == 'table' and objective.trigger.parameters or {}

			if triggerTypesWithQuantity[triggerType] then
				-- Managed objective: register metadata for lookaside lookup; no trigger or action synthesis.
				table.ensureTable(GG['MissionAPI'].ManagedObjectives, triggerType)
				table.insert(GG['MissionAPI'].ManagedObjectives[triggerType], {
					objectiveID = objectiveID,
					parameters = triggerParameters,
				})
			else
				-- Non-managed objective: synthesize trigger + action as usual.
				local isRepeating = amount ~= nil
				local triggerID = '__objective_' .. objectiveID
				local actionID  = '__updateObjective_' .. objectiveID

				rawTriggers[triggerID] = {
					type       = triggerType,
					parameters = triggerParameters,
					settings   = {
						repeating = isRepeating,
					},
					actions = { actionID },
				}

				rawActions[actionID] = {
					type       = actionTypes.UpdateObjective,
					parameters = {
						objectiveID = objectiveID,
					},
				}
			end
		end
	end


	return objectives
end

return {
	ProcessRawObjectives = processRawObjectives,
}
