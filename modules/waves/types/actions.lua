---@meta actions

--- What waves' contribution adds to the mission context: the director, by pack.
---@class (partial) MissionContext
---@field StartWaves fun(request: table) what a pack's Begin composed
---@field StopWaves fun(pack: string)
---@field SetWaveIntensity fun(pack: string, intensity: number)
---@field SurgeWaves fun(pack: string)
---@field WaveStatus fun(pack: string): WaveStatus|nil

--- The mission kit derives its authoring surface from these types, so the
--- alias and class names here are load-bearing beyond the checker.

--- An ALIAS, not a bare number: the editor derives its slot names from
--- param types, and a `number` has nothing to call itself in a sentence.

---@alias WaveIntensity number

--- `name` doubles as the director's name and its savegame key.
---@class WavePackRef
---@field name string "<module>.<pack>", the running director's name
---@field module string the flavor module that can rebuild the spec
---@field pack string which builder inside it

--- It IS an effect, not merely effect-shaped: a Do takes the chain directly,
--- so every link returns something Do accepts and the statement reads as one
--- sentence however many dials it turns.
---@class MissionWavesChain : MissionEffect
---@field Against fun(team: MissionTeam): MissionWavesChain
---@field From fun(fx: number, fz: number): MissionWavesChain
---@field Intensity fun(intensity: WaveIntensity): MissionWavesChain

--- The pack is the subject: `pressure.Begin().Against(Team.Player)`, not
--- `Waves.Begin(pressure)`. A flavor module publishes its packs as this
--- class, and the verbs on it are the director's.
---@class MissionWavePack : WavePackRef
---@field Begin fun(): MissionWavesChain
---@field Intensify fun(intensity: WaveIntensity): MissionEffect
---@field Surge fun(): MissionEffect
---@field End fun(): MissionEffect
---@field Spawned fun(count: integer?): MissionCondition
---@field Cleared fun(count: integer?): MissionCondition
---@field BossDefeated fun(count: integer?): MissionCondition
