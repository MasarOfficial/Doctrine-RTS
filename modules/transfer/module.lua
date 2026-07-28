--- Units, resources and an empty team's assets move through one pipeline, so a
--- transfer is validated, priced and announced in one place.
---@type ModuleManifestFile
return {
	name = "transfer",
	description = "Allied transfer: units, resources, take, and the tax on what flows",
	requires = { "context", "tech", "construction", "economy" },
}
