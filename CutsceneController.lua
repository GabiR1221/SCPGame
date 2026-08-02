--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CutsceneController
local RS=game:GetService("ReplicatedStorage"); local RunService=game:GetService("RunService"); local Players=game:GetService("Players"); local Config:any=require(RS:WaitForChild("Shared"):WaitForChild("CutsceneConfig"))
local LocalPlayer=Players.LocalPlayer :: Player
local CutsceneEvent=RS:WaitForChild("Remotes"):WaitForChild("CutsceneEvent") :: RemoteEvent
local C={}; C.__index=C
function C.new(camera:any,animation:any):any return setmetatable({Camera=camera,Animation=animation,Active=nil,Connection=nil,Gui=nil},C) end
function C._stop(self:any) if self.Connection then self.Connection:Disconnect(); self.Connection=nil end; self.Active=nil; self.Camera:Release("Cutscene"); if self.Gui then self.Gui.Enabled=false end end
function C._start(self:any,msg:any)
	self:_stop(); local def=Config.Definitions[msg.id]; if not def or not self.Camera:Acquire("Cutscene","Cutscene") then return end
	local roomValue:any=msg.room
	if typeof(roomValue)~="Instance" then self.Camera:Release("Cutscene"); return end
	local room:Instance=roomValue :: Instance
	-- Method calls happen only after the explicit Instance narrowing above.
	if def.RoomScoped and not room:IsDescendantOf(workspace) then self.Camera:Release("Cutscene"); return end
	local folder=room:WaitForChild("CutscenePoints",Config.ResolveTimeout); if not folder then self.Camera:Release("Cutscene"); return end; local points={}; local deadline=os.clock()+Config.ResolveTimeout; for _,k in def.Camera do local p=folder:FindFirstChild(k.Point,true); while not p and os.clock()<deadline do task.wait(.05); p=folder:FindFirstChild(k.Point,true) end; if not p or not p:IsA("Attachment") then self.Camera:Release("Cutscene"); return end; points[k.Point]=p end; self.Active=msg.id; if def.CharacterAnimationKey then self.Animation:PlayAction(def.CharacterAnimationKey) end; self.Gui.Enabled=true; self.Connection=RunService.RenderStepped:Connect(function() if not room.Parent then self:_stop(); return end; local elapsed=workspace:GetServerTimeNow()-msg.startTime; if elapsed<0 then return end; local a,b=def.Camera[1],def.Camera[#def.Camera]; for i=1,#def.Camera-1 do if elapsed>=def.Camera[i].Time and elapsed<=def.Camera[i+1].Time then a,b=def.Camera[i],def.Camera[i+1]; break end end; local alpha=if b.Time==a.Time then 1 else math.clamp((elapsed-a.Time)/(b.Time-a.Time),0,1); self.Camera:SetScriptCFrame("Cutscene",points[a.Point].WorldCFrame:Lerp(points[b.Point].WorldCFrame,alpha)); self.Camera:SetFov("Cutscene",a.Fov+(b.Fov-a.Fov)*alpha) end)
end
function C.Start(self:any) local gui=Instance.new("ScreenGui"); gui.Name="CutsceneGui"; gui.IgnoreGuiInset=true; gui.ResetOnSpawn=false; gui.Enabled=false; gui.Parent=LocalPlayer:WaitForChild("PlayerGui"); for _,y in {0,.9} do local bar=Instance.new("Frame"); bar.BorderSizePixel=0; bar.BackgroundColor3=Color3.new(); bar.Position=UDim2.fromScale(0,y); bar.Size=UDim2.fromScale(1,.1); bar.Parent=gui end; self.Gui=gui; CutsceneEvent.OnClientEvent:Connect(function(msg) if msg.kind=="Start" then self:_start(msg) else self:_stop() end end); LocalPlayer.CharacterRemoving:Connect(function() self:_stop() end) end
return C
