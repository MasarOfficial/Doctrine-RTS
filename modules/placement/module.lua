--- Deterministic by construction: no random sampling, the search walks outward in a fixed order, so the same request gives the same answer on every client, in a replay, and in a spec asserting exact coordinates.
--- Before this each spawner answered placement separately or not at all: the wave spawner had a cascade, the roster none, the move action teleported blind.
---@type ModuleManifestFile
return {
	name = "placement",
	description = "Where a unit can legally stand: deterministic nearest-valid ground",
	requires = {},
}
