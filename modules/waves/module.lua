---@type ModuleManifestFile
return {
	name = "waves",
	description = "PvE wave director: anger clocks, wave composition, burrow/boss lifecycle, squad AI",
	-- placement, because the director asks it where a burrow can stand. The
	-- requires list is the dependency graph the loader and the editor read, so
	-- an undeclared include is a lie about what this module needs.
	requires = { "context", "placement" },
}
