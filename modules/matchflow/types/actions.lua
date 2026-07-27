---@meta actions

--- Each action is a class with a call overload, so a mode facet (a domain a grant is written
--- against) can be added to any of them without a second declaration elsewhere.

---@class MatchFlowStarted
---@overload fun(): MissionCondition

---@class MatchFlowVictory
---@overload fun(team: MissionTeam): MissionEffect

---@class MatchFlowDefeat
---@overload fun(team: MissionTeam): MissionEffect

---@class MatchFlowActions
---@field Started MatchFlowStarted
---@field Victory MatchFlowVictory
---@field Defeat MatchFlowDefeat

---@type MatchFlowActions
MatchFlow = {}
