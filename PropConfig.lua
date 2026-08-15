--!strict
-- ModuleScript: ReplicatedStorage/Shared/PropConfig
-- All selection weights and variety rules live here; PropService contains no prop-specific weights.
-- AnchoringMode is a string attribute on each PropTemplate Model (not on its
-- PrimaryPart or PropPlacement): All, Root, or Preserve.
return table.freeze({
	RoomFurnishing = table.freeze({
		Enabled = true,
		DefaultPoolId = "HotelDefault",
		DefaultZonePoolId = "HotelDecor",
		MaximumPropsPerRoom = 8,
		RepetitionPenalty = 0.6,
		PreventExactDuplicates = false,
		Debug = false,
		DebugVisuals = false,
	}),
	Safety = table.freeze({
		Enabled = true,
		PlayerCountScaling = true,
		MinimumHidingSpotsPerPlayer = 1,
		-- Set this true if only templates marked EntityCapableProps=true should guarantee lockers.
		OnlyGuaranteeInEntityRooms = false,
		SafetyPoolId = "SafetyLockers",
	}),
	PropPools = table.freeze({
		HotelDefault = table.freeze({
			EmptyWeight = 20,
			Entries = table.freeze({
				table.freeze({ PropId = "Drawer01", Weight = 25, MaximumCopies = 2 }),
				table.freeze({ PropId = "Locker01", Weight = 10, MaximumCopies = 2 }),
				table.freeze({ PropId = "Shelf01", Weight = 30, MaximumCopies = 3 }),
				
			}),
		}),
		HotelWall = table.freeze({
			EmptyWeight = 20,
			Entries = table.freeze({
				table.freeze({ PropId = "Drawer01", Weight = 25, MaximumCopies = 2 }),
				table.freeze({ PropId = "Locker01", Weight = 10, MaximumCopies = 2 }),
				table.freeze({ PropId = "Shelf01", Weight = 30, MaximumCopies = 3 }),
				table.freeze({ PropId = "MiniLocker01", Weight = 25, MaximumCopies = 2 }),
				table.freeze({ PropId = "Seats012", Weight = 20, MaximumCopies = 2 }),
				table.freeze({ PropId = "Shelf02", Weight = 20, MaximumCopies = 2 }),
				table.freeze({ PropId = "Speaker01", Weight = 100, MaximumCopies = 2 }),
				
			}),
		}),
		HotelDecor = table.freeze({
			EmptyWeight = 35,
			Entries = table.freeze({
				table.freeze({ PropId = "Waitingforthingsuchaspapersonflooretc..", Weight = 20, MaximumCopies = 2 }),
			}),
		}),
		SafetyLockers = table.freeze({
			EmptyWeight = 0,
			Entries = table.freeze({ table.freeze({ PropId = "Locker01", Weight = 1 }) }),
		}),
	}),
})
