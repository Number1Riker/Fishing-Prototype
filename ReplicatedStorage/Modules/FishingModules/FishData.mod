
local FishData = {}

export type FishEntry = {
	Name: string,
	Difficulty: number,
	BaseRarity: number,
	SizeRange: NumberRange,
	Model: string,
	SpeedMult: number,
	CatchType: string,
	RarityMult: number,
}

FishData.Fish = {} :: {[string]: FishEntry}

FishData.Fish.ClownFish = {
	Name = "Clownfish",
	Difficulty = 1.5,
	BaseRarity = 75,
	SizeRange = NumberRange.new(3, 6),
	Model = "ClownFish",
	SpeedMult = 1.0,
	CatchType = "Fish",
	Icon = "rbxassetid://1159999520",
	Color = Color3.fromRGB(255, 137, 69),
	
	Minigame = {
		Behavior = "RelocateZonesOnHit",
		CursorSpeed = 1.2,
		ValueStart = 25,
		ValueDecay = 11,
		HitGain = 24,
		MissPenalty = 9,

		ZoneCount = 1,
		ZoneWidth = 0.22,
		MoveRange = { Min = 0.15, Max = 0.85 },
		OnHit = "MoveHitZone",
	}

}

FishData.Fish.Starfish = {
	Name = "Starfish",
	Difficulty = 0.5,
	BaseRarity = 30,
	SizeRange = NumberRange.new(3, 24),
	Model = "Starfish",
	SpeedMult = 0.8,
	CatchType = "Fish",
	Icon = "rbxassetid://82360819470061",
	Color = Color3.fromRGB(255, 170, 190),
	
	Minigame = {
		Behavior = "ConsumableZones",

		CursorSpeed = 0.9,
		ValueStart = 25,
		ValueDecay = 7,
		HitGain = 15,
		MissPenalty = 8,

		ZoneCount = 5,
		ZoneWidth = 0.11,
		NonIntersectPadding = 0.02,

		ZoneMoveAnim = "Swap",
	}
}

FishData.Fish.Crab = {
	Name = "Crab",
	Difficulty = 2,
	BaseRarity = 25,
	SizeRange = NumberRange.new(6, 18),
	Model = "Crab",
	SpeedMult = 1.0,
	CatchType = "Fish",
	Icon = "rbxassetid://128976165103312",
	Color = Color3.fromRGB(145, 50, 38),

	Minigame = {
		Behavior = "RelocateZonesOnHit",
		
		ValueStart = 50,
		ValueDecay = 3,
		HitGain = 15,
		
		ZoneCount = 2,
		ZoneWidth = 0.14,
		ReverseOnHit = true,
		MoveRange = { Min = 0.12, Max = 0.88 },
		NonIntersectPadding = 0.02,
	}
}

FishData.Fish.Roach = {
	Name = "Common Roach",
	Difficulty = 1,
	BaseRarity = 100,
	SizeRange = NumberRange.new(6, 16),
	Model = "Roach",
	SpeedMult = 1.0,
	CatchType = "Fish",
	Icon = "rbxassetid://5246846179",
	Color = Color3.fromRGB(72, 56, 17),
	
	Minigame = {
		Behavior = "StaticCenter",
		CursorSpeed = 1.25,
		ZoneWidth = 0.28,
		ValueStart = 25,
		ValueDecay = 10,
		HitGain = 20,
		MissPenalty = 6,
	},
}

FishData.Fish.FishBones = {
	Name = "FishBones",
	Difficulty = 3,
	BaseRarity = 10,
	SizeRange = NumberRange.new(4, 34),
	Model = "EvilFish",
	SpeedMult = 1.4,
	CatchType = "Fish",
	Icon = "rbxassetid://100061177701955",
	Color = Color3.fromRGB(255, 66, 66),
	
	Minigame = {
		Behavior = "RelocateZonesOnHit",
		CursorSpeed = 0.8,

		ZoneCount = 4,
		ZoneWidth = 0.09,
		MoveRange = { Min = 0.05, Max = 0.95 },
		OnHit = "MoveHitZone",
		NonIntersectPadding = 0.02,
		
		ValueDecay = 12,
		
		HitGain = 10,
	}

}

FishData.Fish.FlyingFish = {
	Name = "Flying Fish",
	Difficulty = 4,
	BaseRarity = 15,
	SizeRange = NumberRange.new(8, 22),
	Model = "FlyingFish",
	SpeedMult = 1.2,
	CatchType = "Fish",
	Icon = "rbxassetid://1159996453",
	Color = Color3.fromRGB(120, 200, 255),

	Minigame = {
		Behavior = "PassingZone",
		ZoneMoveAnim = "Direct",

		CursorSpeed = 1,
		ZoneWidth = 0.14,

		PassSpeed = .75,
		PassDelay = 0.3,

		ValueStart = 45,
		ValueDecay = 10,
		HitGain = 19,
		MissPenalty = 7,
	}
}

FishData.Fish.Dolphin = {
	Name = "Dolphin",
	Difficulty = 5,
	BaseRarity = 8,
	SizeRange = NumberRange.new(72, 156),
	Model = "Dolphin",
	SpeedMult = 1.5,
	CatchType = "Fish",
	Icon = "rbxassetid://1160001992",
	Color = Color3.fromRGB(197, 241, 255),
	
	Minigame = {
		Behavior = "MovingZone",
		CursorSpeed = 1.25,
		ZoneSpeed = 1.05,
		ZoneWidth = 0.2,
		ValueStart = 45,
		ValueDecay = 13.5,
		HitGain = 25,
		MissPenalty = 11,
		
		ZonePeriod = 3,
		ZoneEaseStyle = "Sine", -- Sine, Quad, Cubic, Quart, Quint, Expo, Back
		ZoneEaseDirection = "InOut",

		ZoneMoveAnim = "Direct",
	}
}

FishData.Fish.Whale = {
	Name = "Whale",
	Difficulty = 12,
	BaseRarity = 2,
	SizeRange = NumberRange.new(420, 780),
	Model = "Whale",
	SpeedMult = 0.7,
	CatchType = "Fish",
	Icon = "rbxassetid://101615196008105",
	Color = Color3.fromRGB(21, 32, 99),

	Minigame = {
		Behavior = "WhaleBoss",
		ZoneMoveAnim = "Direct",

		CursorSpeed = 0.9,
		ZoneWidth = 0.26,

		PassSpeed = 0.45,
		FakeoutSpeed = 0.75,
		PassDelay = 0.4,
		FakeoutChance = 0.5,
		FakeoutDepth = 0.18,

		ValueStart = 25,
		ValueDecay = 5,
		HitGain = 5,
		MissPenalty = 10,

		AssistHitMult = 0.75,
	},
}

return FishData
