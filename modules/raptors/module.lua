--- Only the lobby face of the flavor: the spawner still lives in luarules and reads raptor_* exactly as before.
--- When raptors migrates onto the wave director the roster and mechanics land beside these, the path scavengers took.
---@type ModuleManifestFile
return {
	name = "raptors",
	description = "Raptors: the options and the game mode; the spawner migrates onto waves later",
	requires = { "context", "waves" },
}
