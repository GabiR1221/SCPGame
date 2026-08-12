--!strict
-- ModuleScript: ReplicatedStorage/Shared/ToolConfig
return table.freeze({
	RemoteRateLimit = table.freeze({Window = 1, MaximumRequests = 8}),
	Tools = table.freeze({
		Flashlight = table.freeze({
			TemplateName = "Flashlight",
			EquipAnimation = "FlashlightEquip", UnequipAnimation = "FlashlightUnequip",
			IdleAnimation = "FlashlightIdle", PrimaryAnimation = "FlashlightToggle",
			EquipFallbackDuration = .35, PrimaryFallbackDuration = .4,
			PrimaryCooldown = .45, PrimaryCommitTime = .18,
			-- Keep this false when testing drawer pickups, otherwise duplicate
			-- protection correctly refuses a second Flashlight from loot.
			TurnOffWhenUnequipped = true, GiveOnSpawnForTesting = true,
			LightPath = table.freeze({"Handle", "LightAttachment", "SpotLight"}),
			LightDefaults = table.freeze({Face=Enum.NormalId.Front,Brightness=4,Range=45,Angle=55,Shadows=true,Color=Color3.fromRGB(235,245,255)}),
			Viewmodel = table.freeze({
				Enabled=false, TemplateName="Flashlight", RootName="Root",
				-- Root acts like an invisible UpperTorso for the cloned R15 right-arm joints.
				Offset=CFrame.new(-.75,-1.45,-2.2), LightOriginOffset=CFrame.new(.15,-.35,-.65), SwayEnabled=false,
				SwayStrength=.015, SwaySmoothSpeed=16,
				HideWorldRightArm=true, HideWorldTool=true,
				CopyCharacterArmColors=true, CopyClassicShirt=true,
				BuildArmsFromCharacter=false, CloneWorldHandle=false,
				LightPath=table.freeze({"AimRoot","LightAttachment","SpotLight"}), AimRootName="AimRoot",
				EquipAnimation="FlashlightViewmodelEquip", IdleAnimation="FlashlightViewmodelIdle",
				PrimaryAnimation="FlashlightViewmodelToggle", UnequipAnimation="FlashlightViewmodelUnequip",
			}),
			FlashlightAim = table.freeze({Enabled=true,MaximumDistance=120,MinimumConvergenceDistance=5,UseCrosshairHitPosition=true,ExpectedFace=Enum.NormalId.Front,AimOrientationCorrection=CFrame.identity,Debug=false}),
		}),
	}),
})
