local FishZones = {}

export type OverrideEntry = {
	SizeRange: NumberRange?,
	SpeedMult: number?,
	Difficulty: number?,
	BaseRarity: number?,
	RarityMult: number?,
}

export type ZoneEntry = {
	BiteTime: {Min: number, Max: number},
	Fish: {[string]: number | boolean},
	Overrides: {[string]: OverrideEntry}?,
}

FishZones.List = {} :: {[string]: ZoneEntry}

FishZones.List.OrangeDocks = {
	BiteTime = {Min = 2, Max = 5},
	Fish = {
		ClownFish = true,
		Starfish = true,
		Crab = true,

		Whale = 1,
	},
	Overrides = {

	},
}

FishZones.List.Beach = {
	BiteTime = {Min = 2, Max = 5},
	Fish = {
		Roach = true,
		ClownFish = true,
		Starfish = true,
		Crab = true,

		FlyingFish = 15,
	},
}

FishZones.List.Airport = {
	BiteTime = {Min = 2, Max = 4},
	Fish = {
		FlyingFish = 120,
		Dolphin = 20,

		Whale = 3,
	},
}

--Players come here to wait around with the goal of going for the whale. Close Proximity allows for players
-- to easily see when one gets something and provides easy access to each other.
FishZones.List.OpenOcean = {
	BiteTime = {Min = 3, Max = 6},
	Fish = {
		ClownFish = true,
		Starfish = true,

		Dolphin = 40,
		FlyingFish = 25,

		Whale = 20,
	},
}

-- Kinda just like hardmode, has a variety of funky guys. The two layer environment allows for easy layering of players
FishZones.List.DarkAeroClub = {
	BiteTime = {Min = 4, Max = 7},
	Fish = {
		FlyingFish = 40,
		Dolphin = 35,

		Crab = 25,

		FishBones = 20,
		Whale = 1,
	},
}

FishZones.List.EvilArea = {
	BiteTime = {Min = 7, Max = 11},
	Fish = {
		FishBones = 150,

		Whale = 1, 
	},
}

return FishZones