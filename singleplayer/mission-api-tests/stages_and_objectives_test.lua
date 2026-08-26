local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

local initialStage = 'firstStage'
local stages = {
	firstStage = {
		objectives = { 'wait3secs', 'hurry', 'sneaky' }
	},
	secondStage = {
		objectives = { 'buildBots', 'sneaky' }
	},
	thirdStage = {
		objectives = { 'buildBots', 'destroyBots', 'noLosses', 'sneaky' }
	}
}

local objectives = {

	wait3secs = {
		textKey = "wait_3_seconds",
		trigger = {
			type = triggerTypes.TimeElapsed,
			parameters = {
				seconds = 3,
			},
		},
	},

	-- Not completable before the stage change.
	hurry = {
		textKey = "build_a_bot_quickly",
		trigger = {
			type = triggerTypes.ConstructionFinished,
			parameters = {
				unitDefName = 'corak',
				teamID = 0,
			},
		},
	},

	-- Hidden for the whole mission, so its managed count accrues in every stage.
	sneaky = {
		textKey = "secretly_kill_two",
		amount = 2,
		trigger = {
			type = triggerTypes.TotalUnitsKilled,
			parameters = {
				teamID = 0,
			},
		},
	},

	buildBots = {
		textKey = "build_3_bots",
		amount = 3,
		trigger = {
			type = triggerTypes.ConstructionFinished,
			parameters = {
				unitDefName = 'corak',
				teamID = 0,
			},
		},
	},

	destroyBots = {
		textKey = "destroy_all_bots",
		amount = 0,
		trigger = {
			type = triggerTypes.UnitsOwned,
			parameters = {
				unitName = 'bots',
				teamID = 0,
			},
		},
	},

	-- No inline trigger: failed by the failOnLoss trigger below.
	noLosses = {
		textKey = "lose_no_units",
	},
}

local triggers = {

	startObjectives = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 0,
		},
		actions = { 'addWait3secs', 'addHurry', 'addSneaky', 'hideSneaky' },
	},

	advanceOnWait = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = {
			objectiveIDs = { 'wait3secs' },
		},
		actions = { 'changeToSecondStage', 'addBuildBots' },
	},

	spawnBots = {
		type = triggerTypes.TimeElapsed,
		settings = {
			repeating = true,
			stages = { 'secondStage', 'thirdStage' },
			maxRepeats = 5,
		},
		parameters = {
			seconds = 0,
			interval = 2,
		},
		actions = { 'spawnBot' },
	},

	changeStage3 = {
		type = triggerTypes.TimeElapsed,
		parameters = {
			seconds = 7,
		},
		actions = { 'changeToThirdStage', 'addDestroyBots', 'addNoLosses', 'spawnBotDestroyer' },
	},

	failOnLoss = {
		type = triggerTypes.TotalUnitsLost,
		settings = {
			stages = { 'thirdStage' },
		},
		parameters = {
			teamID = 0,
			quantity = 1,
		},
		actions = { 'failNoLosses' },
	},

	reportFailure = {
		type = triggerTypes.ObjectiveFailed,
		parameters = {
			objectiveIDs = { 'noLosses' },
		},
		actions = { 'announceLoss' },
	},

	winOnObjectives = {
		type = triggerTypes.ObjectiveCompleted,
		parameters = {
			objectiveIDs = { 'buildBots', 'destroyBots' },
		},
		actions = { 'victory' },
	},
}

local actions = {

	addWait3secs = {
		type = actionTypes.AddObjective,
		parameters = {
			objectiveID = 'wait3secs',
		},
	},

	addHurry = {
		type = actionTypes.AddObjective,
		parameters = {
			objectiveID = 'hurry',
			optional = true,
		},
	},

	addSneaky = {
		type = actionTypes.AddObjective,
		parameters = {
			objectiveID = 'sneaky',
			optional = true,
		},
	},

	hideSneaky = {
		type = actionTypes.SetObjectiveHidden,
		parameters = {
			objectiveID = 'sneaky',
		},
	},

	addBuildBots = {
		type = actionTypes.AddObjective,
		parameters = {
			objectiveID = 'buildBots',
		},
	},

	addDestroyBots = {
		type = actionTypes.AddObjective,
		parameters = {
			objectiveID = 'destroyBots',
		},
	},

	addNoLosses = {
		type = actionTypes.AddObjective,
		parameters = {
			objectiveID = 'noLosses',
			optional = true,
		},
	},

	failNoLosses = {
		type = actionTypes.SetObjectiveFailed,
		parameters = {
			objectiveID = 'noLosses',
		},
	},

	announceLoss = {
		type = actionTypes.SendMessage,
		parameters = {
			message = "A unit was lost. Optional objective failed.",
		},
	},

	victory = {
		type = actionTypes.Victory,
		parameters = {
			allyTeamIDs = { 0 },
		},
	},

	changeToSecondStage = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'secondStage',
		},
	},

	spawnBot = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'corak', x = 1800, z = 1800, team = 0, unitName = 'bots' },
			},
		},
	},

	changeToThirdStage = {
		type = actionTypes.ChangeStage,
		parameters = {
			stageID = 'thirdStage',
		},
	},

	spawnBotDestroyer = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armllt', x = 1800, z = 2200, team = 1, quantity = 2 },
			},
		},
	},
}

return {
	InitialStage = initialStage,
	Stages = stages,
	Objectives = objectives,
	Triggers = triggers,
	Actions = actions,
}
