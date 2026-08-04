--- The bus events the director raises for a mission: the counters a mission
--- condition reads (waves.lib.mission_verbs) and the names the director
--- publishes under (wave_director).
---@enum WavesEvents
local Events = {
	WaveSpawned = "waves.wave_spawned",
	WaveCleared = "waves.wave_cleared",
	BossSpawned = "waves.boss_spawned",
	BossDefeated = "waves.boss_defeated",
}

return Events
