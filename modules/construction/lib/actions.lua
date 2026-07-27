--- None of these move anything between teams (that is transfer's domain), which is why they live here.
--- No Perform on any of them yet: nothing performs a construction action from a trigger.

local Actions = {}

Actions.Construction = {
	Assist = { domain = "assist" },
	Reclaim = { domain = "reclaim" },
	Resurrect = { domain = "resurrect" },
	--- The delay a mode sets is served on the builder, here.
	Build = { domain = "build" },
}

return Actions
