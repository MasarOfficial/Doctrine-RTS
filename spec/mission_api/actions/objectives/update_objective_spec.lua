require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions  = VFS.Include('luarules/mission_api/actions/objectives/update_objective.lua')
local action   = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG['MissionAPI']

local function resetObjective(id, data)
    Builders.MissionApi.new():WithObjective(id, data):Install()
end

describe("mission_api.actions.update_objective", function()

    before_each(function()
        Builders.MissionApi.new():Install()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type        = 'UpdateObjective',
            objectiveID = 'ObjectiveID!',
            textKey     = 'String',
        }, summarizeSchema(action))
    end)

    describe("actionFunction", function()
        it("is a no-op when the objective is not added", function()
            resetObjective('obj1', {})
            action.actionFunction('obj1', nil)
            assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
            assert.are.equal(0, #missionApi.calls.echoObjectiveUpdate)
        end)

        it("is a no-op on terminal objectives", function()
            resetObjective('obj1', { state = 'completed' })
            action.actionFunction('obj1', 'newKey')
            assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
            assert.are.equal(0, #missionApi.calls.echoObjectiveUpdate)
            resetObjective('obj2', { state = 'failed' })
            action.actionFunction('obj2', nil)
            assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
        end)

        it("updates the textKey and echoes without progressing", function()
            resetObjective('obj1', { state = 'active' })
            action.actionFunction('obj1', 'ui.objective.updated')
            assert.are.equal('ui.objective.updated', missionApi.Objectives['obj1'].textKey)
            assert.are.equal(1, #missionApi.calls.echoObjectiveUpdate)
            assert.are.equal('obj1', missionApi.calls.echoObjectiveUpdate[1].objectiveID)
            assert.are.equal(0, #missionApi.calls.incrementObjectiveProgress)
        end)

        it("delegates to IncrementObjectiveProgress when no textKey is given", function()
            resetObjective('obj1', { state = 'active', progress = 2, amount = 5 })
            action.actionFunction('obj1', nil)
            assert.are.equal(1, #missionApi.calls.incrementObjectiveProgress)
            assert.are.equal('obj1', missionApi.calls.incrementObjectiveProgress[1].objectiveID)
        end)
    end)

end)
