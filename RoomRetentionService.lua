--!strict
-- ModuleScript: ServerScriptService/Services/RoomRetentionService
local S={}; S.__index=S
function S.new():any return setmetatable({Pins={} :: {[number]:number},Behind=0},S) end
function S.SetBehind(self:any,count:number) self.Behind=math.max(self.Behind,math.max(0,math.floor(count))) end
function S.GetBehind(self:any):number return self.Behind end
function S.Pin(self:any,index:number) self.Pins[index]=(self.Pins[index] or 0)+1 end
function S.Release(self:any,index:number) local count=self.Pins[index]; if count==nil then return end; if count<=1 then self.Pins[index]=nil else self.Pins[index]=count-1 end end
function S.IsPinned(self:any,index:number):boolean return (self.Pins[index] or 0)>0 end
function S.Clear(self:any) table.clear(self.Pins) end
return S
