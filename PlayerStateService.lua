--!strict
-- ModuleScript: ServerScriptService/Services/PlayerStateService
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local Service={}; Service.__index=Service
type Record={State:string,Humanoid:Humanoid,Locks:{[string]:{[string]:boolean}},Tokens:{[string]:{string}}}
function Service.new(remote:RemoteEvent):any return setmetatable({Remote=remote,Records={} :: {[Player]:Record}},Service) end
function Service._publish(self:any,player:Player) local r:Record?=self.Records[player]; if not r then return end; local locks:{string}={}; for category,bucket in r.Locks do if next(bucket) then table.insert(locks,category) end end; self.Remote:FireClient(player,r.State,locks) end
function Service.Register(self:any,player:Player,humanoid:Humanoid) self:Clear(player); self.Records[player]={State="Normal",Humanoid=humanoid,Locks={},Tokens={}}; self:_publish(player) end
function Service.IsAlive(self:any,player:Player):boolean local r:Record?=self.Records[player]; return r~=nil and r.State~="Dead" and r.Humanoid.Health>0 end
function Service.CanBegin(self:any,player:Player):boolean local r:Record?=self.Records[player]; return r~=nil and r.State=="Normal" and not self:IsLocked(player,"Interaction") end
function Service.CanUseTools(self:any,player:Player):boolean local r:Record?=self.Records[player]; if r==nil then return false end; return r.State=="Normal" and self:IsAlive(player) and not self:IsLocked(player,"Tool") and not self:IsLocked(player,"Inventory") end
function Service.IsLocked(self:any,player:Player,category:string):boolean local r:Record?=self.Records[player]; local bucket=if r then r.Locks[category] else nil; return bucket~=nil and next(bucket)~=nil end
function Service.Acquire(self:any,player:Player,state:string,categories:{string}):(string?,string?) local r:Record?=self.Records[player]; if not r or r.State~="Normal" then return nil,"Busy" end; local token=HttpService:GenerateGUID(false); r.State=state; r.Tokens[token]=categories; for _,category in categories do local bucket=r.Locks[category] or {}; r.Locks[category]=bucket; bucket[token]=true end; self:_apply(r); self:_publish(player); return token,nil end
function Service._apply(_self:any,r:Record) local h=r.Humanoid; if not h.Parent then return end; h.WalkSpeed=next(r.Locks.Movement or {}) and 0 or (h:GetAttribute("ConfiguredWalkSpeed") :: number?) or 10; h.JumpPower=next(r.Locks.Jump or {}) and 0 or (h:GetAttribute("ConfiguredJumpPower") :: number?) or 42; h.AutoRotate=next(r.Locks.Rotation or {})==nil end
function Service.Release(self:any,player:Player,token:string) local r:Record?=self.Records[player]; if not r then return end; local cats=r.Tokens[token]; if not cats then return end; for _,c in cats do local bucket=r.Locks[c]; if bucket then bucket[token]=nil end end; r.Tokens[token]=nil; if next(r.Tokens)==nil and r.State~="Dead" then r.State="Normal" end; self:_apply(r); self:_publish(player) end
function Service.CancelAll(self:any,player:Player,state:string?) local r:Record?=self.Records[player]; if not r then return end; table.clear(r.Locks); table.clear(r.Tokens); r.State=state or "Normal"; self:_apply(r); self:_publish(player) end
function Service.Refresh(self:any,player:Player) local r:Record?=self.Records[player]; if r then self:_apply(r); self:_publish(player) end end
function Service.MarkDead(self:any,player:Player) self:CancelAll(player,"Dead") end
function Service.Clear(self:any,player:Player) self.Records[player]=nil end
function Service.Start(self:any) Players.PlayerRemoving:Connect(function(p) self:Clear(p) end) end
return Service
