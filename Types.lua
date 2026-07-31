--Modulescript in Shared folder in replicatedstorage
--!strict
export type RoomTemplate = {
	Id: string, Model: Model, Theme: string, Category: string, Weight: number,
	MinDepth: number, MaxDepth: number, Difficulty: number, CooldownRooms: number,
	MaxConsecutive: number, EntranceType: string, ExitType: string, IsUnique: boolean,
	IsSpecial: boolean, CanBeDark: boolean, AllowsEntities: boolean, Attributes: {[string]: any},
}
export type RoomData = {
	Index: number, Id: string, TemplateId: string, Model: Model, Entrance: BasePart,
	Exit: BasePart, Bounds: BasePart, State: string, Seed: number,
	Connections: {RBXScriptConnection}, CleanupCallbacks: {() -> ()},
	TemporaryInstances: {Instance}, Occupants: {[Player]: boolean},
}
export type ScheduledSpecial = { Kind: string, RoomId: string?, Category: string?, Requires: string?, Grants: string? }
export type PacingRuntime = { Name: string, RoomsInState: number, TargetDuration: number, ConsecutiveDark: number }
export type RunState = {
	Seed: number, Random: Random, CurrentRoomIndex: number, GeneratedUntilIndex: number,
	RoomHistory: {string}, UsedUniqueRooms: {[string]: boolean}, ScheduledSpecialRooms: {[number]: ScheduledSpecial},
	CurrentPacingState: PacingRuntime, ActiveRooms: {[number]: RoomData}, Prerequisites: {[string]: boolean}, Theme: string,
}
return {}
