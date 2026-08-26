require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local summarizeSchema = require("mission_api.schema_spec_helper")

local sets = {
    { file = 'set_objective_hidden',    type = 'SetObjectiveHidden',    call = 'hideObjective' },
    { file = 'set_objective_active',    type = 'SetObjectiveActive',    call = 'activateObjective' },
    { file = 'set_objective_canceled',  type = 'SetObjectiveCanceled',  call = 'cancelObjective' },
    { file = 'set_objective_failed',    type = 'SetObjectiveFailed',    call = 'failObjective' },
    { file = 'set_objective_completed', type = 'SetObjectiveCompleted', call = 'completeObjective' },
}

for _, set in ipairs(sets) do
    set.action = VFS.Include('luarules/mission_api/actions/objectives/' .. set.file .. '.lua')[1]
end

local missionApi = GG['MissionAPI']

describe("mission_api.actions.set_objective", function()

    before_each(function()
        Builders.MissionApi.new():Install()
    end)

    it("declares types and parameters", function()
        for _, set in ipairs(sets) do
            assert.are.same({
                type        = set.type,
                objectiveID = 'ObjectiveID!',
            }, summarizeSchema(set.action))
        end
    end)

    for _, set in ipairs(sets) do
        it("delegates " .. set.type .. " to the objectives module", function()
            set.action.actionFunction('obj1')
            assert.are.equal(1, #missionApi.calls[set.call])
            assert.are.equal('obj1', missionApi.calls[set.call][1].objectiveID)
        end)
    end

end)
