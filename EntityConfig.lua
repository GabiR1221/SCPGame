--!strict
-- ModuleScript: ReplicatedStorage/Shared/EntityConfig
return table.freeze({
	Debug=table.freeze({
		-- Studio testing only. ForceSpawn still respects route availability and
		-- concurrency, while IgnoreLockerRequirement bypasses the locker gate.
		ForceSpawn=true,
		IgnoreMinimumTriggerRoom=true,
		IgnoreCooldown=true,
		IgnoreLockerRequirement=false,
		CreatePlaceholderTemplate=false,
		PrintDecisions=true,
	}),
	Entities=table.freeze({
		HallwayRush=table.freeze({
			Enabled=true,
			TemplateName="HallwayRush",
			MinimumTriggerRoom=7,
			SpawnChance=.12,
			CooldownRooms=8,
			MaximumConcurrent=1,
			SpawnBehindRooms=6,
			PassAheadRooms=2,
			WarningDuration=2.5,
			TravelSpeed=80,
			RequireAvailableLocker=true,
			MinimumAvailableLockers=1,
			WarningSoundId="rbxassetid://0",
			TravelSoundId="rbxassetid://0",
			Debug=false,
		}),
	}),
})
