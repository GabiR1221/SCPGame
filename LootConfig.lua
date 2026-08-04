--!strict
-- ModuleScript: ReplicatedStorage/Shared/LootConfig
return table.freeze({
	DrawerLoot=table.freeze({
		Enabled=true,
		BaseSpawnChance=.15,
		MaximumToolSpawnsPerRoom=2,
		MinimumRoom=1,
		MaximumRoom=100,
		AllowDuplicateOwnedTools=false,
		AutoEquipOnPickup=false,
		MaxBackpackTools=5,
		PoolId="DrawerToolsV1",
		Debug=table.freeze({
			-- Studio testing only. Set true to make every eligible drawer pass
			-- its spawn-chance roll; MaximumToolSpawnsPerRoom still applies.
			ForceSpawn=true,
			PrintRolls=true,
		}),
		Pool=table.freeze({
			table.freeze({ToolId="Flashlight",PickupTemplate="FlashlightPickup",Weight=10,MinimumRoom=1,MaximumRoom=100}),
		}),
	}),
})
