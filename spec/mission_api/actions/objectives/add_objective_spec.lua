require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include('luarules/mission_api/actions/objectives/add_objective.lua')
local action  = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

local missionApi = GG['MissionAPI']

describe("mission_api.actions.add_objective", function()

    before_each(function()
        Builders.MissionApi.new():Install()
    end)

    it("declares its type and parameters", function()
        assert.are.same({
            type        = 'AddObjective',
            objectiveID = 'ObjectiveID!',
            optional    = 'Boolean',
        }, summarizeSchema(action))
    end)

    it("adds an objective as primary by default", function()
        action.actionFunction('obj1', nil)
        assert.are.equal(1, #missionApi.calls.addObjective)
        assert.are.equal('obj1', missionApi.calls.addObjective[1].objectiveID)
        assert.is_nil(missionApi.calls.addObjective[1].optional)
    end)

    it("adds an optional objective", function()
        action.actionFunction('obj2', true)
        assert.are.equal(1, #missionApi.calls.addObjective)
        assert.are.equal('obj2', missionApi.calls.addObjective[1].objectiveID)
        assert.is_true(missionApi.calls.addObjective[1].optional)
    end)

end)
