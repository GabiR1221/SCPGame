--!strict
-- Script: ServerScriptService/Main
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
local function remote(name:string):RemoteEvent
	local existing=remotes:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"),`ReplicatedStorage.Remotes.{name} must be a RemoteEvent`)
		return existing :: RemoteEvent
	end
	local value=Instance.new("RemoteEvent"); value.Name=name; value.Parent=remotes; return value
end
local function unreliableRemote(name:string):UnreliableRemoteEvent
	local existing=remotes:FindFirstChild(name)
	if existing then
		if existing:IsA("UnreliableRemoteEvent") then return existing end
		error(`ReplicatedStorage.Remotes.{name} must be an UnreliableRemoteEvent`)
	end
	local value=Instance.new("UnreliableRemoteEvent"); value.Name=name; value.Parent=remotes; return value
end
local doorRemote=remotes:FindFirstChild("DoorStateChanged")::RemoteEvent?
if not doorRemote then doorRemote=Instance.new("RemoteEvent"); doorRemote.Name="DoorStateChanged"; doorRemote.Parent=remotes end

-- Player framework services are constructed once and share only narrow service APIs.
local characterStateRemote=remote("CharacterStateChanged")
local interactionRequest=remote("InteractionRequest")
local interactionStateRemote=remote("InteractionStateChanged")
local cutsceneRemote=remote("CutsceneEvent")
local crouchRequest=remote("CrouchRequest")
local lookPoseUpdate=unreliableRemote("LookPoseUpdate")
local toolActionRequest=remote("ToolActionRequest")
local toolStateChanged=remote("ToolStateChanged")
local hidingRequest=remote("HidingRequest")
local hidingStateChanged=remote("HidingStateChanged")
local entityEvent=remote("EntityEvent")
local PlayerStateService: any=require(Services.PlayerStateService).new(characterStateRemote)
local NoiseService: any=require(Services.NoiseService).new(Tracker)
local InteractionService: any=require(Services.InteractionService).new(PlayerStateService,NoiseService,interactionStateRemote)
local CutsceneService: any=require(Services.CutsceneService).new(PlayerStateService,cutsceneRemote)
local CharacterService: any=require(Services.CharacterService).new(PlayerStateService,characterStateRemote,function(player:Player,reason:string)
	InteractionService:CancelPlayer(player,reason); CutsceneService:CancelPlayer(player,reason)
end)
local CrouchService:any=require(Services.CrouchService).new(PlayerStateService)
local LookPoseService=require(Services.LookPoseService)
-- Resolve optional/new services dynamically so Studio's analyzer does not require
-- a stale, statically inferred child list for the Services Folder.
local toolServiceModule=Services:WaitForChild("ToolService")
assert(toolServiceModule:IsA("ModuleScript"),"ServerScriptService.Services.ToolService must be a ModuleScript")
local ToolService:any=require(toolServiceModule).new(PlayerStateService,toolActionRequest,toolStateChanged)
local objectAnimationModule=ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ObjectAnimationUtil")
assert(objectAnimationModule:IsA("ModuleScript"),"ReplicatedStorage.Shared.ObjectAnimationUtil must be a ModuleScript")
local ObjectAnimation:any=require(objectAnimationModule)
local HidingService:any=require(Services:WaitForChild("HidingService")).new(PlayerStateService,Tracker,hidingStateChanged,ObjectAnimation)
local LootService:any=require(Services:WaitForChild("LootService")).new(ToolService,HidingService)
local drawerServiceModule=Services:WaitForChild("DrawerService")
assert(drawerServiceModule:IsA("ModuleScript"),"ServerScriptService.Services.DrawerService must be a ModuleScript")
local DrawerService:any=require(drawerServiceModule).new(LootService,ObjectAnimation)
local collisionServiceModule=Services:WaitForChild("CharacterCollisionService")
assert(collisionServiceModule:IsA("ModuleScript"),"ServerScriptService.Services.CharacterCollisionService must be a ModuleScript")
local CharacterCollisionService:any=require(collisionServiceModule).new()
require(Services.PlayerFrameworkRoomBridge).Connect(Lifecycle,InteractionService,CutsceneService)

-- Safe starter handlers. Replace attribute mutations with calls into your item/door
-- domain services; the client can never select these callbacks or their rewards.
InteractionService:RegisterHandler("OpenDrawer",function(player:Player,target:Instance) DrawerService:Toggle(player,target) end)
InteractionService:RegisterHandler("CloseDrawer",function(player:Player,target:Instance) DrawerService:Toggle(player,target) end)
InteractionService:RegisterSpecialHandler("Locker",function(player:Player,target:Instance) HidingService:Enter(player,target) end)
InteractionService:RegisterHandler("PickupTool",function(player:Player,target:Instance) LootService:Collect(player,target) end)
InteractionService:RegisterHandler("PullLever",function(_player:Player,target:Instance) target:SetAttribute("Pulled",true) end)
InteractionService:RegisterHandler("PressButton",function(_player:Player,target:Instance) target:SetAttribute("PressedAt",workspace:GetServerTimeNow()) end)
PlayerStateService:Start(); NoiseService:Start(); InteractionService:Start(interactionRequest); CutsceneService:Start(); CharacterService:Start(); CharacterCollisionService:Start(); CrouchService:Start(crouchRequest); LookPoseService.Start(lookPoseUpdate); ToolService:Start(); HidingService:Start(hidingRequest); LootService:Start()

local valid: boolean,errors: {string}=Registry:Scan()
if not valid then error(`[Main] Room template validation failed with {#errors} error(s); correct every warning above`) end
local Selector: any=require(Services.RoomSelector).new(Registry,Pacing,Config)
local Generator: any=require(Services.RoomGenerator).new(Selector,Lifecycle,Pacing,Config,generated)
local Retention:any=require(Services:WaitForChild("RoomRetentionService")).new()
local RunManager: any=require(Services.RunManager).new(Config,Registry,Generator,Lifecycle,Cleanup,Tracker,Pacing,Retention)
local EntityDirector:any=require(Services.EntityDirector).new(Lifecycle,RunManager,Tracker,HidingService,Retention,entityEvent)
local DoorService: any=require(Services.DoorService).new(RunManager,Tracker,doorRemote :: RemoteEvent,generated)
Lifecycle:Subscribe("Loaded",function(room) HidingService:RegisterRoom(room); DrawerService:RegisterRoom(room); LootService:RegisterRoom(room) end)
Lifecycle:Subscribe("Unloading",function(room) DrawerService:CleanupRoom(room); LootService:UnregisterRoom(room); HidingService:UnregisterRoom(room) end)
Tracker:Start(); DoorService:Start(); EntityDirector:Start()

-- Replace nil with a fixed integer during deterministic Studio tests.
RunManager:StartRun(nil)
