--!strict
-- ModuleScript: ServerScriptService/Services/CutsceneService
local Players=game:GetService("Players"); local RS=game:GetService("ReplicatedStorage"); local Config:any=require(RS:WaitForChild("Shared"):WaitForChild("CutsceneConfig"))
local S={}; S.__index=S
function S.new(states:any,remote:RemoteEvent):any return setmetatable({States=states,Remote=remote,Active={},Played={},Rooms={}},S) end
function S.RegisterRoom(self:any,room:any) self.Rooms[room.Index]={Model=room.Model,Active=room.State=="Active"} end
function S.SetRoomActive(self:any,index:number,value:boolean) if self.Rooms[index] then self.Rooms[index].Active=value end; if not value then self:CancelRoom(index,"RoomInactive") end end
function S.UnregisterRoom(self:any,index:number) self:CancelRoom(index,"RoomUnloaded"); self.Rooms[index]=nil end
function S.Play(self:any,players:{Player},id:string,roomIndex:number?):boolean local def=Config.Definitions[id]; if not def then return false end; local room=roomIndex and self.Rooms[roomIndex]; if def.RoomScoped and (not room or not room.Active) then return false end; local start=workspace:GetServerTimeNow()+.35; for _,p in players do if self.Active[p] or (def.OneShot and self.Played[p] and self.Played[p][id]) then continue end; local token=self.States:Acquire(p,"Cutscene",def.Locks); if not token then continue end; self.Active[p]={token=token,id=id,room=roomIndex}; self.Played[p]=self.Played[p] or {}; self.Played[p][id]=true; self.Remote:FireClient(p,{kind="Start",id=id,roomIndex=roomIndex,room=room and room.Model,startTime=start}); task.delay(def.Duration+.35,function() self:_finish(p,token,"Complete") end) end; return true end
function S.PlayAll(self:any,id:string,roomIndex:number?) return self:Play(Players:GetPlayers(),id,roomIndex) end
function S._finish(self:any,p:Player,token:string,kind:string) local a=self.Active[p]; if not a or a.token~=token then return end; self.Active[p]=nil; self.States:Release(p,token); self.Remote:FireClient(p,{kind=kind,id=a.id}) end
function S.CancelPlayer(self:any,p:Player,reason:string) local a=self.Active[p]; if a then self:_finish(p,a.token,"Cancel"); self.Remote:FireClient(p,{kind="Cancel",reason=reason}) end end
function S.CancelRoom(self:any,i:number,r:string) for p,a in self.Active do if a.room==i then self:CancelPlayer(p,r) end end end
function S.Start(self:any) Players.PlayerRemoving:Connect(function(p) self:CancelPlayer(p,"Leaving"); self.Played[p]=nil end) end
return S
