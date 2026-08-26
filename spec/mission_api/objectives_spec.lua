require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local Objectives = VFS.Include('luarules/mission_api/objectives.lua')

local States = Objectives.States

-- Stand-in trigger type IDs, as triggers_loader would assign them.
local TRIGGER_TYPES = { ObjectiveCompleted = 101, ObjectiveFailed = 102 }

local activatedTriggers = {}

-- Mirrors processTriggersOfType in api_missions_triggers.lua.
local function processTriggersOfType(triggerType, func)
	for triggerID, trigger in pairs(GG['MissionAPI'].Triggers) do
		if trigger.type == triggerType then
			func(trigger, triggerID)
		end
	end
end

local function activateTrigger(trigger)
	activatedTriggers[#activatedTriggers + 1] = trigger
end

Objectives.Init({ processTriggersOfType = processTriggersOfType, activateTrigger = activateTrigger })

describe("mission_api.objectives", function()
	local missionApi

	local function install(builder)
		missionApi = builder:WithTriggerDefinitions({ Types = TRIGGER_TYPES }):Install()
	end

	before_each(function()
		for i = #activatedTriggers, 1, -1 do activatedTriggers[i] = nil end
		install(Builders.MissionApi.new())
	end)

	describe("AddObjective", function()
		it("marks a dormant objective active", function()
			install(Builders.MissionApi.new():WithObjective('obj1', {}))
			Objectives.AddObjective('obj1', false)
			assert.are.equal(States.Active, missionApi.Objectives['obj1'].state)
			assert.is_false(missionApi.Objectives['obj1'].optional)
			assert.is_false(missionApi.Objectives['obj1'].hidden)
		end)

		it("adds an optional objective", function()
			install(Builders.MissionApi.new():WithObjective('obj1', {}))
			Objectives.AddObjective('obj1', true)
			assert.is_true(missionApi.Objectives['obj1'].optional)
		end)

		it("defaults optional to false", function()
			install(Builders.MissionApi.new():WithObjective('obj1', {}))
			Objectives.AddObjective('obj1', nil)
			assert.is_false(missionApi.Objectives['obj1'].optional)
		end)

		it("is a no-op on an already added objective", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Canceled, optional = true }))
			Objectives.AddObjective('obj1', false)
			assert.are.equal(States.Canceled, missionApi.Objectives['obj1'].state)
			assert.is_true(missionApi.Objectives['obj1'].optional)
		end)

		it("evaluates an already met count target on add", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { amount = 2, progress = 3 }))
			Objectives.AddObjective('obj1', false)
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("completes an amount = 0 objective with no accrued count on add", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { amount = 0 }))
			Objectives.AddObjective('obj1', false)
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("does not complete below the count target on add", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { amount = 5, progress = 3 }))
			Objectives.AddObjective('obj1', false)
			assert.are.equal(States.Active, missionApi.Objectives['obj1'].state)
		end)

		it("does not evaluate objectives without a count target", function()
			install(Builders.MissionApi.new():WithObjective('obj1', {}))
			Objectives.AddObjective('obj1', false)
			assert.are.equal(States.Active, missionApi.Objectives['obj1'].state)
		end)
	end)

	describe("setters", function()
		it("HideObjective sets the presentation flag only", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, hidden = false }))
			Objectives.HideObjective('obj1')
			assert.is_true(missionApi.Objectives['obj1'].hidden)
			assert.are.equal(States.Active, missionApi.Objectives['obj1'].state)
		end)

		it("ActivateObjective reveals a hidden objective", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, hidden = true }))
			Objectives.ActivateObjective('obj1')
			assert.is_false(missionApi.Objectives['obj1'].hidden)
			assert.are.equal(States.Active, missionApi.Objectives['obj1'].state)
		end)

		it("ActivateObjective resumes a canceled objective with progress kept", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Canceled, progress = 2, amount = 5 }))
			Objectives.ActivateObjective('obj1')
			assert.are.equal(States.Active, missionApi.Objectives['obj1'].state)
			assert.are.equal(2, missionApi.Objectives['obj1'].progress)
		end)

		it("ActivateObjective evaluates an already met target on resume", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Canceled, progress = 5, amount = 5 }))
			Objectives.ActivateObjective('obj1')
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("CancelObjective parks an active objective", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active }))
			Objectives.CancelObjective('obj1')
			assert.are.equal(States.Canceled, missionApi.Objectives['obj1'].state)
		end)

		it("FailObjective sets failed", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active }))
			Objectives.FailObjective('obj1')
			assert.are.equal(States.Failed, missionApi.Objectives['obj1'].state)
		end)

		it("CompleteObjective sets completed", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active }))
			Objectives.CompleteObjective('obj1')
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("setters warn and do nothing on a dormant objective", function()
			install(Builders.MissionApi.new():WithObjective('obj1', {}))
			Objectives.CancelObjective('obj1')
			assert.are.equal(States.Dormant, missionApi.Objectives['obj1'].state)
		end)

		it("terminal states are frozen", function()
			install(Builders.MissionApi.new()
				:WithObjective('obj1', { state = States.Completed })
				:WithObjective('obj2', { state = States.Failed }))
			Objectives.FailObjective('obj1')
			Objectives.ActivateObjective('obj2')
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
			assert.are.equal(States.Failed, missionApi.Objectives['obj2'].state)
		end)
	end)

	describe("ChangeStage", function()
		it("sets the current stage ID", function()
			Objectives.ChangeStage('stage2')
			assert.are.equal('stage2', missionApi.CurrentStageID)
		end)

		it("cancels active objectives the entered stage does not list", function()
			install(Builders.MissionApi.new()
				:WithStage('s2', { objectives = { 'obj2' } })
				:WithObjective('obj1', { state = States.Active })
				:WithObjective('obj2', { state = States.Active }))
			Objectives.ChangeStage('s2')
			assert.are.equal(States.Canceled, missionApi.Objectives['obj1'].state)
			assert.are.equal(States.Active, missionApi.Objectives['obj2'].state)
		end)

		it("cancels hidden objectives identically", function()
			install(Builders.MissionApi.new()
				:WithStage('s2', { objectives = {} })
				:WithObjective('obj1', { state = States.Active, hidden = true }))
			Objectives.ChangeStage('s2')
			assert.are.equal(States.Canceled, missionApi.Objectives['obj1'].state)
		end)

		it("does not touch terminal or canceled objectives", function()
			install(Builders.MissionApi.new()
				:WithStage('s2', { objectives = {} })
				:WithObjective('obj1', { state = States.Completed })
				:WithObjective('obj2', { state = States.Failed })
				:WithObjective('obj3', { state = States.Canceled }))
			Objectives.ChangeStage('s2')
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
			assert.are.equal(States.Failed, missionApi.Objectives['obj2'].state)
			assert.are.equal(States.Canceled, missionApi.Objectives['obj3'].state)
		end)

		it("does not add objectives the entered stage lists", function()
			install(Builders.MissionApi.new()
				:WithStage('s2', { objectives = { 'obj1' } })
				:WithObjective('obj1', {}))
			Objectives.ChangeStage('s2')
			assert.are.equal(States.Dormant, missionApi.Objectives['obj1'].state)
		end)
	end)

	describe("IncrementObjectiveProgress", function()
		it("adds one occurrence to an active objective", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, amount = 5 }))
			Objectives.IncrementObjectiveProgress('obj1')
			assert.are.equal(1, missionApi.Objectives['obj1'].progress)
		end)

		it("completes when the count reaches the amount", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, progress = 4, amount = 5 }))
			Objectives.IncrementObjectiveProgress('obj1')
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("completes on the first occurrence when amount is nil", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active }))
			Objectives.IncrementObjectiveProgress('obj1')
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("ignores objectives that are not active", function()
			install(Builders.MissionApi.new()
				:WithObjective('obj1', {})
				:WithObjective('obj2', { state = States.Canceled, progress = 1 }))
			Objectives.IncrementObjectiveProgress('obj1')
			Objectives.IncrementObjectiveProgress('obj2')
			assert.is_nil(missionApi.Objectives['obj1'].progress)
			assert.are.equal(1, missionApi.Objectives['obj2'].progress)
		end)
	end)

	describe("UpdateObjectiveProgress", function()
		it("ignores events for another team", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, amount = 1 }))
			local metadata = { parameters = { teamID = 0 } }
			Objectives.UpdateObjectiveProgress('obj1', 1, 'armwar', nil, 1, metadata)
			assert.is_nil(missionApi.Objectives['obj1'].progress)
		end)

		it("ignores events for another unitDefName", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, amount = 1 }))
			local metadata = { parameters = { teamID = 0, unitDefName = 'corak' } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', nil, 1, metadata)
			assert.is_nil(missionApi.Objectives['obj1'].progress)
		end)

		it("ignores events without a matching unitName", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, amount = 2 }))
			local metadata = { parameters = { teamID = 0, unitName = 'bots' } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', {}, 1, metadata)
			assert.is_nil(missionApi.Objectives['obj1'].progress)
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', { bots = true }, 1, metadata)
			assert.are.equal(1, missionApi.Objectives['obj1'].progress)
		end)

		it("accrues the count while dormant, without evaluating", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { amount = 1 }))
			local metadata = { parameters = { teamID = 0 } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', nil, 1, metadata)
			assert.are.equal(1, missionApi.Objectives['obj1'].progress)
			assert.are.equal(States.Dormant, missionApi.Objectives['obj1'].state)
		end)

		it("accrues while canceled without evaluating", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Canceled, amount = 1 }))
			local metadata = { parameters = { teamID = 0 } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', nil, 1, metadata)
			assert.are.equal(1, missionApi.Objectives['obj1'].progress)
			assert.are.equal(States.Canceled, missionApi.Objectives['obj1'].state)
		end)

		it("evaluates while active", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, amount = 1 }))
			local metadata = { parameters = { teamID = 0 } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', nil, 1, metadata)
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("completes an amount = 0 objective when the count returns to zero", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Active, amount = 0, progress = 1 }))
			local metadata = { parameters = { teamID = 0 } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', nil, -1, metadata)
			assert.are.equal(States.Completed, missionApi.Objectives['obj1'].state)
		end)

		it("freezes terminal objectives", function()
			install(Builders.MissionApi.new():WithObjective('obj1', { state = States.Completed, progress = 3, amount = 3 }))
			local metadata = { parameters = { teamID = 0 } }
			Objectives.UpdateObjectiveProgress('obj1', 0, 'armwar', nil, -1, metadata)
			assert.are.equal(3, missionApi.Objectives['obj1'].progress)
		end)
	end)

	describe("observer triggers", function()
		it("activates ObjectiveCompleted triggers when the last listed objective completes", function()
			install(Builders.MissionApi.new()
				:WithObjective('obj1', { state = States.Active })
				:WithObjective('obj2', { state = States.Active })
				:WithTrigger('observer', {
					type       = TRIGGER_TYPES.ObjectiveCompleted,
					parameters = { objectiveIDs = { 'obj1', 'obj2' } },
				}))
			Objectives.CompleteObjective('obj1')
			assert.are.equal(0, #activatedTriggers)
			Objectives.CompleteObjective('obj2')
			assert.are.equal(1, #activatedTriggers)
		end)

		it("does not activate ObjectiveCompleted triggers listing other objectives", function()
			install(Builders.MissionApi.new()
				:WithObjective('obj1', { state = States.Active })
				:WithObjective('obj2', { state = States.Active })
				:WithTrigger('observer', {
					type       = TRIGGER_TYPES.ObjectiveCompleted,
					parameters = { objectiveIDs = { 'obj2' } },
				}))
			Objectives.CompleteObjective('obj1')
			assert.are.equal(0, #activatedTriggers)
		end)

		it("activates ObjectiveCompleted triggers from progress-driven completion", function()
			install(Builders.MissionApi.new()
				:WithObjective('obj1', { state = States.Active, progress = 2, amount = 3 })
				:WithTrigger('observer', {
					type       = TRIGGER_TYPES.ObjectiveCompleted,
					parameters = { objectiveIDs = { 'obj1' } },
				}))
			Objectives.IncrementObjectiveProgress('obj1')
			assert.are.equal(1, #activatedTriggers)
		end)

		it("activates ObjectiveFailed triggers when any listed objective fails", function()
			install(Builders.MissionApi.new()
				:WithObjective('obj1', { state = States.Active })
				:WithObjective('obj3', { state = States.Active })
				:WithTrigger('observer', {
					type       = TRIGGER_TYPES.ObjectiveFailed,
					parameters = { objectiveIDs = { 'obj1', 'obj2' } },
				}))
			Objectives.FailObjective('obj3')
			assert.are.equal(0, #activatedTriggers)
			Objectives.FailObjective('obj1')
			assert.are.equal(1, #activatedTriggers)
		end)
	end)

end)
