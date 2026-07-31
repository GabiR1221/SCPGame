--!strict
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Workspace=game:GetService("Workspace")
local Services=script.Parent.Services
local Config: any=require(ReplicatedStorage.Shared.SharedConfig)
local Registry: any=require(Services.RoomRegistry).new(Config)
local Pacing: any=require(Services.PacingDirector).new(Config)
local Lifecycle: any=require(Services.RoomLifecycle).new()
local Cleanup: any=require(Services.RoomCleanupService).new(Lifecycle,Config)
local Tracker: any=require(Services.PlayerRoomTracker).new(Lifecycle,Config)

local function folder(parent:Instance,name:string):Folder
	local existing=parent:FindFirstChild(name)
	if existing then assert(existing:IsA("Folder"),`{existing:GetFullName()} must be a Folder`); return existing end
	local value=Instance.new("Folder"); value.Name=name; value.Parent=parent; return value
end
folder(ServerStorage,"RoomTemplates")
local generated=folder(Workspace,"GeneratedRooms"); folder(Workspace,"RuntimeEntities")
local remotes=folder(ReplicatedStorage,"Remotes")
local doorRemote=remotes:FindFirstChild("DoorStateChanged")::RemoteEvent?
if not doorRemote then doorRemote=Instance.new("RemoteEvent"); doorRemote.Name="DoorStateChanged"; doorRemote.Parent=remotes end

local valid: boolean,errors: {string}=Registry:Scan()
if not valid then error(`[Main] Room template validation failed with {#errors} error(s); correct every warning above`) end
local Selector: any=require(Services.RoomSelector).new(Registry,Pacing,Config)
local Generator: any=require(Services.RoomGenerator).new(Selector,Lifecycle,Pacing,Config,generated)
local RunManager: any=require(Services.RunManager).new(Config,Registry,Generator,Lifecycle,Cleanup,Tracker,Pacing)
local DoorService: any=require(Services.DoorService).new(RunManager,Tracker,doorRemote :: RemoteEvent,generated)
Tracker:Start(); DoorService:Start()

-- Replace nil with a fixed integer during deterministic Studio tests.
RunManager:StartRun(nil)
