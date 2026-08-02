--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/FirstPersonController
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterConfig"))
local LocalPlayer=Players.LocalPlayer :: Player

local Controller={}; Controller.__index=Controller
-- There is exactly one local player/controller. Keeping the part cache in module
-- scope prevents a stale render callback from ever observing a replaced or
-- partially initialized controller table during respawn/hot reload.
local visibleParts:{[BasePart]:boolean}={}
local characterConnections:{RBXScriptConnection}={}
local waist:Motor6D?=nil; local neck:Motor6D?=nil
local rootMotor:Motor6D?=nil
local smoothedPitch=0
local desiredBodyOffset=0
local lastHorizontalForward=Vector3.new(0,0,-1)
local poseConnections:{RBXScriptConnection}={}
local function findMotor(character:Model,name:string):Motor6D?
	for _,descendant in character:GetDescendants() do if descendant:IsA("Motor6D") and descendant.Name==name then return descendant end end
	return nil
end
function Controller.new():any return setmetatable({Enabled=true},Controller) end

function Controller.SetEnabled(self:any,enabled:boolean)
	self.Enabled=enabled
	LocalPlayer:SetAttribute("FirstPersonEnabled",enabled)
	LocalPlayer.CameraMode=if enabled then Enum.CameraMode.LockFirstPerson else Enum.CameraMode.Classic
	if not enabled then LocalPlayer.CameraMinZoomDistance=0.5; LocalPlayer.CameraMaxZoomDistance=18; smoothedPitch=0; desiredBodyOffset=0 end
end

function Controller.ToggleForTesting(self:any)
	if Config.TestingAllowFirstPersonToggle then self:SetEnabled(not self.Enabled) end
end

function Controller._updateBody(self:any,dt:number)
	for part:BasePart in visibleParts do
		if part.Parent then local hideInFirstPerson=part.Name=="Head" or part:FindFirstAncestorOfClass("Accessory")~=nil; part.LocalTransparencyModifier=if self.Enabled and hideInFirstPerson then 1 else 0 else visibleParts[part]=nil end
	end
	if self.Enabled then local camera=workspace.CurrentCamera; local character=LocalPlayer.Character; if camera then local pitch=math.clamp(math.asin(camera.CFrame.LookVector.Y),-Config.LookBend.MaximumPitch,Config.LookBend.MaximumPitch); smoothedPitch+=(pitch-smoothedPitch)*math.min(1,Config.LookBend.SmoothSpeed*dt); local downward=math.max(0,-camera.CFrame.LookVector.Y); desiredBodyOffset=(Config.FirstPersonBody.ForwardOffset+Config.FirstPersonBody.DownwardForwardBonus*downward)*Config.FirstPersonBody.ForwardSign; local root=if character then character:FindFirstChild("HumanoidRootPart") else nil; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil; if Config.FirstPersonBody.AlignCharacterYaw and root and root:IsA("BasePart") and humanoid and humanoid.AutoRotate then local right=camera.CFrame.RightVector; local horizontalRight=Vector3.new(right.X,0,right.Z); if horizontalRight.Magnitude>.001 then local candidate=Vector3.new(horizontalRight.Z,0,-horizontalRight.X).Unit; if candidate:Dot(lastHorizontalForward)<0 then candidate=-candidate end; lastHorizontalForward=candidate; root.CFrame=CFrame.lookAt(root.Position,root.Position+lastHorizontalForward,Vector3.yAxis) end end end end
end

function Controller._resetPose(_self:any) if waist then waist.Transform=CFrame.identity end; if neck then neck.Transform=CFrame.identity end; if rootMotor then rootMotor.Transform=CFrame.identity end end
function Controller._applyPose(self:any) if not self.Enabled then return end; if Config.LookBend.Enabled then if waist then waist.Transform*=CFrame.Angles(smoothedPitch*Config.LookBend.WaistWeight,0,0) end; if neck then neck.Transform*=CFrame.Angles(smoothedPitch*Config.LookBend.NeckWeight,0,0) end end; if rootMotor then rootMotor.Transform*=CFrame.new(0,0,desiredBodyOffset) end end

function Controller._bindCharacter(self:any,character:Model)
	for _,connection in characterConnections do connection:Disconnect() end; table.clear(characterConnections); table.clear(visibleParts)
	for _,descendant in character:GetDescendants() do if descendant:IsA("BasePart") then visibleParts[descendant]=true end end
	waist=findMotor(character,"Waist"); neck=findMotor(character,"Neck"); rootMotor=findMotor(character,"Root") or findMotor(character,"RootJoint")
	smoothedPitch=0; desiredBodyOffset=0; local root=character:FindFirstChild("HumanoidRootPart"); if root and root:IsA("BasePart") then lastHorizontalForward=root.CFrame.LookVector end
	if Config.Debug then print(`[FirstPerson] Waist={if waist then waist:GetFullName() else "missing"}, Neck={if neck then neck:GetFullName() else "missing"}, Root={if rootMotor then rootMotor:GetFullName() else "missing"}`) end
	table.insert(characterConnections,character.DescendantAdded:Connect(function(descendant) if descendant:IsA("BasePart") then visibleParts[descendant]=true end end))
	table.insert(characterConnections,character.DescendantRemoving:Connect(function(descendant) if descendant:IsA("BasePart") then visibleParts[descendant]=nil end end))
end

function Controller.Start(self:any)
	self:SetEnabled(true)
	RunService:BindToRenderStep("FirstPersonVisibleBody",Enum.RenderPriority.Camera.Value+2,function(dt) self:_updateBody(dt) end)
	table.insert(poseConnections,RunService.PreAnimation:Connect(function() self:_resetPose() end))
	table.insert(poseConnections,RunService.PreSimulation:Connect(function() self:_applyPose() end))
	LocalPlayer.CharacterAdded:Connect(function(character) self:_bindCharacter(character); self:SetEnabled(self.Enabled) end)
	if LocalPlayer.Character then self:_bindCharacter(LocalPlayer.Character) end
end

function Controller.Destroy(self:any) RunService:UnbindFromRenderStep("FirstPersonVisibleBody"); self:_resetPose(); for _,connection in poseConnections do connection:Disconnect() end; table.clear(poseConnections); for _,connection in characterConnections do connection:Disconnect() end; table.clear(characterConnections); table.clear(visibleParts); waist=nil; neck=nil; rootMotor=nil; smoothedPitch=0; desiredBodyOffset=0 end
return Controller
