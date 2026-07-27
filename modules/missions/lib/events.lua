--- The bus events the missions module raises. A module names its events
--- here, not in a string: a typo is a nil, not a trigger that never fires.
---@enum MissionEvents
local Events = {
	ObjectiveChanged = "mission.objective_changed",
	VariableChanged = "mission.variable_changed",
}

return Events
