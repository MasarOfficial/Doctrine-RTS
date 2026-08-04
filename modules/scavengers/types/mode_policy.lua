---@meta policy mode

--- A mode preset checks against the mode surface of its OWN module: the trigger vocabulary in
--- actions.lua is a different language for a different kind of file, and the two never mix.

--- Every dial takes a pack, because a module can run more than one director.
---@class ScavengersPackNoun

--- The lock modifiers apply to the option the preceding verb wrote, which is how Difficulty
--- and Endless are left open for the lobby while everything else is pinned.
---@class ScavengersModeChain
---@field Desc fun(desc: string): ScavengersModeChain
---@field Ranked fun(enabled: boolean?): ScavengersModeChain permission is a flag; Ranked(false) pins ranked_game off, lockable like any policy
---@field RetainValues fun(): ScavengersModeChain
---@field Hidden fun(): ScavengersModeChain
---@field Unlocked fun(): ScavengersModeChain
---@field Locked fun(): ScavengersModeChain
---@field Difficulty fun(pack: ScavengersPackNoun, difficulty: string): ScavengersModeChain
---@field Boss fun(pack: ScavengersPackNoun, count: integer, timeMultiplier: number?): ScavengersModeChain
---@field Grace fun(pack: ScavengersPackNoun, multiplier: number): ScavengersModeChain
---@field Pace fun(pack: ScavengersPackNoun, timeMultiplier: number, countMultiplier: number): ScavengersModeChain
---@field Placement fun(pack: ScavengersPackNoun, placement: WaveBurrowPlacement): ScavengersModeChain
---@field Endless fun(pack: ScavengersPackNoun, endless: boolean): ScavengersModeChain
--- The one thing the modoptions cannot express: scavengers are activated by a scavengers AI
--- being present, not by an option, which is what keeps every existing lobby working.
---@field Bot fun(aiName: string): ScavengersModeChain

---The category is not a parameter: the grammar binds every chain from this module to "game".
---@param name string
---@return ScavengersModeChain
function Mode(name) end

---@type { Skirmish: ScavengersPackNoun, Assault: ScavengersPackNoun, Horde: ScavengersPackNoun }
Scavengers = {}
