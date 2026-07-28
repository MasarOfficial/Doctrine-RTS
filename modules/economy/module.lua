--- Waterfill is not about allies (given a pool, claimants and capacities, how much does each get),
--- so it sits under the modules with a reason to ask; anything splitting a pool uses this solver rather than growing its own.
---@type ModuleManifestFile
return {
	name = "economy",
	description = "Resource pool distribution: the waterfill solver",
}
