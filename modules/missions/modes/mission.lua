local ModeDSL = VFS.Include("modules/missions/lib/mode_dsl.lua") ---@type MissionsModeDSL
local MatchFlow = VFS.Include("modules/matchflow/mode_dsl.lua") ---@type MatchflowModeDSL
local Mode, Match = ModeDSL.Mode, ModeDSL.Match

return Mode("Mission")
	.Desc(
		"The mission decides when it is won or lost, so losing your units does not end the match. Every unit is loaded, because a mission can use anything."
	)
	.Own(MatchFlow.End)
	.Loads(Match.EveryUnitDef)
	.Ranked(false)
	.Locked()
	.Choose(Match.Mission)
	.Unlocked()
	-- A mission needs an enemy TEAM to arm, not an enemy player. A skirmish AI in
	-- that seat shoots the scenery; NullAI holds the seat and does nothing.
	.Bot("NullAI")
