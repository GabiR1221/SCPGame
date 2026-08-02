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
			TurnOffWhenUnequipped = true, GiveOnSpawnForTesting = true,
			LightPath = table.freeze({"Handle", "LightAttachment", "SpotLight"}),
		}),
	}),
})
