--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CameraController
local Players=game:GetService("Players"); local RunService=game:GetService("RunService"); local RS=game:GetService("ReplicatedStorage")
local Shared=RS:WaitForChild("Shared")
local Config:any=require(Shared:WaitForChild("CharacterConfig"))
local LocalPlayer=Players.LocalPlayer :: Player
local C={}; C.__index=C
local lastHorizontalForward=Vector3.new(0,0,-1)
-- Keep camera offsets on the same definition of horizontal forward as the
-- first-person body controller: flattened LookVector first, camera RightVector
-- at vertical pitch, and the last camera-derived direction only as a last resort.
local function getHorizontalCameraForward(cameraCFrame:CFrame,fallback:Vector3):Vector3
	local look=cameraCFrame.LookVector
	local flatLook=Vector3.new(look.X,0,look.Z)
	if flatLook.Magnitude>Config.FirstPersonBody.HorizontalDirectionEpsilon then return flatLook.Unit end
	local right=cameraCFrame.RightVector
	local flatRight=Vector3.new(right.X,0,right.Z)
	if flatRight.Magnitude>Config.FirstPersonBody.HorizontalDirectionEpsilon then return Vector3.new(flatRight.Z,0,-flatRight.X).Unit end
	return fallback
end
function C.new():any return setmetatable({Mode="Gameplay",Owner=nil,Camera=nil,Connection=nil,BaseFov=Config.Camera.DefaultFov,TargetFov=Config.Camera.DefaultFov,ScriptCFrame=nil,Shake=Vector3.zero,BobClock=0},C) end
function C.Acquire(self:any,owner:string,mode:string):boolean if self.Owner and self.Owner~=owner then return false end; self.Owner=owner; self.Mode=mode; return true end
function C.Release(self:any,owner:string) if self.Owner~=owner then return end; self.Owner=nil; self:Restore() end
function C.SetScriptCFrame(self:any,owner:string,value:CFrame?) if self.Owner==owner then self.ScriptCFrame=value end end
function C.SetFov(self:any,owner:string,value:number) if not self.Owner or self.Owner==owner then self.TargetFov=math.clamp(value,30,100) end end
function C.AddShake(self:any,amount:Vector3) if Config.Camera.ShakeEnabled then self.Shake+=amount end end
function C.Restore(self:any) self.Mode="Gameplay"; self.ScriptCFrame=nil; self.TargetFov=self.BaseFov; local camera=workspace.CurrentCamera; if camera then camera.CameraType=Enum.CameraType.Custom; local character=LocalPlayer.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil; camera.CameraSubject=humanoid end end
function C._step(self:any,dt:number) local camera=workspace.CurrentCamera; if not camera then return end; self.Camera=camera; camera.FieldOfView+=(self.TargetFov-camera.FieldOfView)*math.min(1,dt*8); local scripted:CFrame?=self.ScriptCFrame; if scripted then camera.CameraType=Enum.CameraType.Scriptable; camera.CFrame=scripted*CFrame.Angles(self.Shake.X,self.Shake.Y,self.Shake.Z) elseif self.Mode=="Gameplay" then camera.CameraType=Enum.CameraType.Custom; if LocalPlayer:GetAttribute("FirstPersonEnabled")~=false then local character=LocalPlayer.Character; if Config.Camera.HeadBobEnabled then local h=if character then character:FindFirstChildOfClass("Humanoid") else nil; if h and h.MoveDirection.Magnitude>.1 and h.FloorMaterial~=Enum.Material.Air then self.BobClock+=dt*Config.Camera.HeadBobFrequency; camera.CFrame*=CFrame.new(0,math.sin(self.BobClock)*Config.Camera.HeadBobAmount,0) end end; local look=camera.CFrame.LookVector; lastHorizontalForward=getHorizontalCameraForward(camera.CFrame,lastHorizontalForward); local downward=math.max(0,-look.Y); local distance=Config.Camera.FirstPersonForwardOffset+Config.Camera.DownwardForwardBonus*downward; camera.CFrame+=lastHorizontalForward*distance+Vector3.new(0,Config.Camera.FirstPersonVerticalOffset,0) end end; self.Shake=(self.Shake :: Vector3):Lerp(Vector3.zero,math.min(1,dt*12)) end
function C.Start(self:any) LocalPlayer.CameraMode=Enum.CameraMode.LockFirstPerson; RunService:BindToRenderStep("CentralCamera",Enum.RenderPriority.Camera.Value+1,function(dt) self:_step(dt) end); LocalPlayer.CharacterAdded:Connect(function() self.Owner=nil; self:Restore() end); LocalPlayer.CharacterRemoving:Connect(function() self.Owner=nil; self.Mode="Death"; self.ScriptCFrame=nil end) end
function C.Destroy(self:any) RunService:UnbindFromRenderStep("CentralCamera"); self:Restore() end
return C
