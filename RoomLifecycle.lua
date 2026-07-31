--Modulescript in Services folder in ServerScriptService
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Constants=require(ReplicatedStorage.Shared.RoomConstants)
local Lifecycle={}; Lifecycle.__index=Lifecycle
type Callback = (any, any?) -> ()
function Lifecycle.new(): any return setmetatable({Listeners={} :: {[string]: {Callback}}},Lifecycle) end
function Lifecycle.Subscribe(self:any,eventName:string, callback:Callback):()->()
	local bucket: {Callback}=self.Listeners[eventName]
	if not bucket then bucket={}; self.Listeners[eventName]=bucket end
	table.insert(bucket,callback)
	return function() local i=table.find(bucket,callback); if i then table.remove(bucket,i) end end
end
function Lifecycle._emit(self:any,name:string, room:any, value:any?) local bucket: {Callback}?=self.Listeners[name]; if not bucket then return end; for _,callback: Callback in bucket do task.spawn(callback,room,value) end end
function Lifecycle.Load(self:any,room:any) assert(room.State==Constants.States.Generated,"room must be Generated"); self:_emit("Loaded",room) end
function Lifecycle.Activate(self:any,room:any) if room.State==Constants.States.Active then return end; assert(room.State==Constants.States.Generated or room.State==Constants.States.Completed,"invalid activation"); room.State=Constants.States.Active; room.Model:SetAttribute("RoomState",room.State); self:_emit("Activated",room) end
function Lifecycle.PlayerEntered(self:any,room:any, player:Player) room.Occupants[player]=true; self:_emit("PlayerEntered",room,player) end
function Lifecycle.PlayerExited(self:any,room:any, player:Player) room.Occupants[player]=nil; self:_emit("PlayerExited",room,player) end
function Lifecycle.Complete(self:any,room:any) if room.State~=Constants.States.Active then return end; room.State=Constants.States.Completed; room.Model:SetAttribute("RoomState",room.State); self:_emit("Completed",room) end
function Lifecycle.Deactivate(self:any,room:any) self:_emit("Deactivated",room) end
function Lifecycle.Unload(self:any,room:any) if room.State==Constants.States.Destroyed then return end; room.State=Constants.States.Unloading; self:_emit("Unloading",room) end
return Lifecycle
