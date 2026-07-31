--!strict
return table.freeze({
	States = table.freeze({ Generated = "Generated", Active = "Active", Completed = "Completed", Unloading = "Unloading", Destroyed = "Destroyed" }),
	Tags = table.freeze({ "LootSpawn", "EntitySpawn", "HidingSpot", "RoomTrigger", "Door", "Interactable", "LightSource" }),
	ConnectorName = "Connector",
	EntranceName = "Entrance",
	ExitName = "Exit",
	BoundsName = "Bounds",
})
