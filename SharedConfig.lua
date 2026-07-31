--Modulescript in Shared folder in replicatedstorage
--!strict
return table.freeze({
	Generation = table.freeze({ RoomsAhead = 5, RoomsBehind = 2, MaximumActiveRooms = 12, MaximumGenerationRetries = 8, GenerationDelay = 0.02, CheckBoundsOverlap = true }),
	FallbackRoomId = "HotelStraight",
	FallbackEnabled = true,
	Debug = table.freeze({ Enabled = false, Visuals = false, CandidateWeights = false, Cleanup = false, Players = false }),
	DefaultRoomWeight = 10,
	ImmediateRepeatMultiplier = 0,
	DarkRoomWeightMultiplier = 0.65,
	MaximumConsecutiveDarkRooms = 2,
	Difficulty = table.freeze({ PerDepth = 0.06, Tolerance = 2.5 }),
	ConnectorCompatibility = table.freeze({ Standard = table.freeze({ Standard = true, Wide = true }), Wide = table.freeze({ Standard = true, Wide = true }), Vent = table.freeze({ Vent = true }) }),
	ThemeProgression = table.freeze({ { MinDepth = 0, MaxDepth = 49, Theme = "Hotel" }, { MinDepth = 50, MaxDepth = math.huge, Theme = "Basement" } }),
	PacingStates = table.freeze({
		Calm = table.freeze({ Allowed = { Normal = true, Recovery = true }, Preferred = { Normal = 1.2 }, MinDuration = 2, MaxDuration = 5, AllowsEntities = false, Next = "BuildUp" }),
		BuildUp = table.freeze({ Allowed = { Normal = true, Tension = true }, Preferred = { Tension = 1.6 }, MinDuration = 2, MaxDuration = 4, AllowsEntities = true, Next = "Danger" }),
		Danger = table.freeze({ Allowed = { Danger = true, Chase = true, Normal = true }, Preferred = { Danger = 2, Chase = 2.5 }, MinDuration = 1, MaxDuration = 2, AllowsEntities = true, Next = "Recovery" }),
		Recovery = table.freeze({ Allowed = { Recovery = true, Normal = true }, Preferred = { Recovery = 2 }, MinDuration = 1, MaxDuration = 3, AllowsEntities = false, Next = "Calm" }),
	}),
	SpecialRoomRanges = table.freeze({
		{ Kind = "Key", Category = "Key", Min = 8, Max = 12, Grants = "Key" },
		{ Kind = "Locked", Category = "Locked", Min = 14, Max = 18, Requires = "Key" },
		{ Kind = "Shop", Category = "Shop", Min = 20, Max = 26 },
		{ Kind = "Chase", Category = "Chase", Min = 32, Max = 38 },
	}),
	MandatoryRooms = table.freeze({ [0] = "HotelStart" }),
})
