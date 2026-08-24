---@type ModuleManifestFile
return {
	name = "missions",
	description = "Mission runtime: trigger engine, authoring DSL, mission loader",
	-- The requires list IS the vocabulary whitelist: what a mission file may say
	-- is exactly what these modules contribute.
	requires = { "matchflow", "combat", "transfer", "waves", "scavengers", "placement" },
}
