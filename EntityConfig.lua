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
		Hert=table.freeze({
			Director="RoomCreature",
			Enabled=true,ForceSpawn=true,Debug=true,TemplateName="Hert",SpawnChance=.25,MaxHealth=100,Damage=25,
			DetectionRange=35,HitRadius=3,JumpDuration=.55,JumpHeight=6,
			MinimumAttackCooldown=3,MaximumAttackCooldown=5,RequireLineOfSight=true,
			IdleAnimation="HertIdle",AttackAnimation="HertAttack",DeathAnimation="HertDeath",
			Animations=table.freeze({
				HertIdle=table.freeze({Id="rbxassetid://0",Looped=true}),
				HertAttack=table.freeze({Id="rbxassetid://0",Looped=false}),
				HertDeath=table.freeze({Id="rbxassetid://0",Looped=false}),
			}),
		}),
		HallwayRush=table.freeze({
			Director="Hallway",
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
