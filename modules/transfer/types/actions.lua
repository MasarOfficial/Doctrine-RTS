---@meta actions

--- What transfer's contribution adds to the mission context.
---@class (partial) MissionContext
---@field TransferGroup fun(groupName: string, teamID: integer, fiat: boolean|nil) a roster group changes hands; fiat skips the mode's say

--- One declaration read by both grammars: an action cannot mean one thing to a
--- mode file and another to a trigger file.

--- Not callable: a mission performs the action, not a slice of it.
---@class TransferGrant
---@field domain string
---@field category string|nil
---@field tier integer|nil

---@class TransferUnits : TransferGrant
---@field AtT2 TransferGrant
---@field AtT3 TransferGrant
---@field Constructors TransferGrant
---@field Resource TransferGrant
---@overload fun(group: MissionUnitGroup|MissionGroupRef, team: MissionTeam): MissionEffect

---@class TransferResources : TransferGrant
---@field Metal TransferGrant
---@field Energy TransferGrant
---@field AtT2 TransferGrant
---@field AtT3 TransferGrant

--- Fiat: performable, and deliberately not grantable — a mode has no say, so
--- there is no domain for a grant to be written against.
---@class TransferGive
---@overload fun(group: MissionUnitGroup|MissionGroupRef, team: MissionTeam): MissionEffect

---@class TransferActions
---@field Units TransferUnits
---@field Resources TransferResources
---@field Give TransferGive

---@type TransferActions
Transfer = {}

---@type TransferGrant
Take = {}

---@type TransferGrant
Tech = {}
