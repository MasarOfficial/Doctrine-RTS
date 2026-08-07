local ModeDSL = VFS.Include("modules/raptors/mode_dsl.lua") ---@type RaptorsModeDSL
local Mode, Raptors = ModeDSL.Mode, ModeDSL.Raptors

-- Every value here is the default a fresh lobby already shows: the mode names the shape and fields the bot, not retunes the game.
-- Difficulty and endless stay open; the first-waves boost is claimed because the panel is a whitelist, and an unclaimed dial is an invisible one.
return Mode("Raptors")
	.Desc("Hold out against the raptor swarm, then kill the queen.")
	.Bot("RaptorsAI")
	.Ranked(false)
	.Locked()
	.Difficulty(Raptors.Swarm, "normal")
	.Unlocked()
	.Boss(Raptors.Swarm, 1)
	.Grace(Raptors.Swarm, 1.0)
	.Pace(Raptors.Swarm, 1.0, 1.0)
	.Placement(Raptors.Swarm, "initialbox")
	.Endless(Raptors.Swarm, false)
	.Unlocked()
	.Boost(Raptors.Swarm, 1)
