--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/ViewmodelController
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Workspace=game:GetService("Workspace")
local LocalPlayer=Players.LocalPlayer :: Player
local ToolConfig:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ToolConfig"))
local AnimationConfig:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local Controller={}; Controller.__index=Controller
local RENDER_NAME="FlashlightViewmodel"

local function resolvePath(root:Instance,path:{string}):Instance?
	local current:Instance?=root
	for _,name in path do local snapshot=current; if snapshot==nil then return nil end; current=snapshot:FindFirstChild(name) end
	return current
end

function Controller.new(cameraController:any,firstPersonController:any):any
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.IgnoreWater=true
	return setmetatable({CameraController=cameraController,FirstPerson=firstPersonController,EquippedTool=nil,
		ToolId=nil,Model=nil,Root=nil,Attachment=nil,ViewLight=nil,WorldLight=nil,WorldLightWasEnabled=false,
		Visibility={} :: {[BasePart]:number},Tracks={} :: {[string]:AnimationTrack},IdleTrack=nil,
		DesiredIdleKey=nil,
		Connections={} :: {RBXScriptConnection},RaycastParams=params,Generation=0,Removing=false,
		LifecycleConnections={} :: {RBXScriptConnection},Unavailable=false,MissingWarnings={} :: {[string]:boolean}},Controller)
end

function Controller._restoreVisibility(self:any)
	for part,previous in self.Visibility do if part.Parent~=nil then part.LocalTransparencyModifier=previous end end
	table.clear(self.Visibility)
	local worldLight:SpotLight?=self.WorldLight; local tool:Tool?=self.EquippedTool
	if worldLight and worldLight.Parent~=nil then worldLight.Enabled=tool~=nil and tool:GetAttribute("Active")==true or self.WorldLightWasEnabled end
	self.WorldLight=nil; self.WorldLightWasEnabled=false
end

function Controller._clearConnections(self:any)
	for _,connection:RBXScriptConnection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
end

function Controller._deactivate(self:any)
	self:_clearConnections(); self:_restoreVisibility()
	for _,track:AnimationTrack in self.Tracks do track:Stop(0); track:Destroy() end
	table.clear(self.Tracks); self.IdleTrack=nil
	local model:Model?=self.Model; if model then model:Destroy() end
	self.Model=nil; self.Root=nil; self.Attachment=nil; self.ViewLight=nil; self.Removing=false
end

function Controller._warnOnce(self:any,key:string,message:string)
	if self.MissingWarnings[key] then return end; self.MissingWarnings[key]=true; warn(message)
end

function Controller._hidePart(self:any,part:BasePart)
	if self.Visibility[part]==nil then self.Visibility[part]=part.LocalTransparencyModifier end
	part.LocalTransparencyModifier=1
end

local function copyMotor(source:Motor6D,parent:Instance,part0:BasePart,part1:BasePart)
	local motor=Instance.new("Motor6D"); motor.Name=source.Name; motor.C0=source.C0; motor.C1=source.C1
	motor.Part0=part0; motor.Part1=part1; motor.Parent=parent
end

local function removeJoints(part:BasePart)
	for _,descendant in part:GetDescendants() do if descendant:IsA("JointInstance") then descendant:Destroy() end end
end

local function findMotor(character:Model,names:{string},part0Name:string,part1Name:string):Motor6D?
	for _,wantedName in names do
		for _,descendant in character:GetDescendants() do
			if descendant.Name==wantedName and descendant:IsA("Motor6D") then
				local part0=descendant.Part0; local part1=descendant.Part1
				if part0 and part1 and part0.Name==part0Name and part1.Name==part1Name then return descendant end
			end
		end
	end
	for _,descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then local part0=descendant.Part0; local part1=descendant.Part1; if part0 and part1 and part0.Name==part0Name and part1.Name==part1Name then return descendant end end
	end
	return nil
end

function Controller._buildCharacterRig(self:any,model:Model,root:BasePart,tool:Tool,character:Model,definition:any):boolean
	if not definition.BuildArmsFromCharacter then return false end
	local sourceUpper=character:FindFirstChild("RightUpperArm"); local sourceLower=character:FindFirstChild("RightLowerArm"); local sourceHand=character:FindFirstChild("RightHand"); local torso=character:FindFirstChild("UpperTorso"); local lowerTorso=character:FindFirstChild("LowerTorso"); local humanoidRoot=character:FindFirstChild("HumanoidRootPart")
	if not sourceUpper or not sourceUpper:IsA("BasePart") or not sourceLower or not sourceLower:IsA("BasePart") or not sourceHand or not sourceHand:IsA("BasePart") or not torso or not torso:IsA("BasePart") or not lowerTorso or not lowerTorso:IsA("BasePart") or not humanoidRoot or not humanoidRoot:IsA("BasePart") then self:_warnOnce("R15Arm","[ViewmodelController] Character is missing the R15 torso/right-arm chain; using the real Tool presentation"); return false end
	-- Standard R15 motors are commonly parented under Part1 (for example Root
	-- under LowerTorso), so resolve them by endpoints instead of assumed parents.
	local rootJoint=findMotor(character,{"Root","RootJoint"},"HumanoidRootPart","LowerTorso"); local waist=findMotor(character,{"Waist"},"LowerTorso","UpperTorso"); local shoulder=findMotor(character,{"RightShoulder"},"UpperTorso","RightUpperArm"); local elbow=findMotor(character,{"RightElbow"},"RightUpperArm","RightLowerArm"); local wrist=findMotor(character,{"RightWrist"},"RightLowerArm","RightHand")
	if not rootJoint or not waist or not shoulder or not elbow or not wrist then self:_warnOnce("R15Motors","[ViewmodelController] Character is missing the connected R15 Root/Waist/right-arm Motor6Ds; using the real Tool presentation"); return false end
	for _,name in {"RightUpperArm","RightLowerArm","RightHand"} do local old=model:FindFirstChild(name,true); if old then old:Destroy() end end
	local upperValue=sourceUpper:Clone(); local lowerValue=sourceLower:Clone(); local handValue=sourceHand:Clone()
	if not upperValue:IsA("BasePart") or not lowerValue:IsA("BasePart") or not handValue:IsA("BasePart") then upperValue:Destroy(); lowerValue:Destroy(); handValue:Destroy(); return false end
	local upper:BasePart=upperValue; local lower:BasePart=lowerValue; local hand:BasePart=handValue
	removeJoints(upper); removeJoints(lower); removeJoints(hand)
	-- Keep standard R15 names for animation pose resolution, but make the torso
	-- proxies tiny so a cloned classic Shirt cannot render a camera-filling torso.
	local lowerProxy=Instance.new("Part"); lowerProxy.Name="LowerTorso"; lowerProxy.Size=Vector3.one*.05; lowerProxy.Transparency=1; lowerProxy.Anchored=false; lowerProxy.CanCollide=false; lowerProxy.CanTouch=false; lowerProxy.CanQuery=false; lowerProxy.Massless=true; lowerProxy.Parent=model
	local upperProxy=Instance.new("Part"); upperProxy.Name="UpperTorso"; upperProxy.Size=Vector3.one*.05; upperProxy.Transparency=1; upperProxy.Anchored=false; upperProxy.CanCollide=false; upperProxy.CanTouch=false; upperProxy.CanQuery=false; upperProxy.Massless=true; upperProxy.Parent=model
	for _,part in {upper,lower,hand} do part.Anchored=false; part.CanCollide=false; part.CanTouch=false; part.CanQuery=false; part.CastShadow=false; part.Massless=true; part.Parent=model end
	-- Parent each recreated Motor6D under Part1, matching the standard R15 rig.
	copyMotor(rootJoint,lowerProxy,root,lowerProxy); copyMotor(waist,upperProxy,lowerProxy,upperProxy); copyMotor(shoulder,upper,upperProxy,upper); copyMotor(elbow,lower,upper,lower); copyMotor(wrist,hand,lower,hand)
	if definition.CloneWorldHandle then
		local sourceHandle=tool:FindFirstChild("Handle"); local flashlightModel=model:FindFirstChild("FlashlightModel")
		if sourceHandle and sourceHandle:IsA("BasePart") and flashlightModel and flashlightModel:IsA("Model") then
			local oldBody=flashlightModel:FindFirstChild("LightBody"); if oldBody then oldBody:Destroy() end
			local bodyValue=sourceHandle:Clone()
			if bodyValue:IsA("BasePart") then
				local body:BasePart=bodyValue; body.Name="LightBody"; removeJoints(body); body.Anchored=false; body.CanCollide=false; body.CanTouch=false; body.CanQuery=false; body.CastShadow=false; body.Massless=true; body.Parent=flashlightModel
				local realGrip=sourceHand:FindFirstChild("RightGrip")
				if realGrip and realGrip:IsA("Motor6D") then copyMotor(realGrip,hand,hand,body) else local grip=Instance.new("Motor6D"); grip.Name="RightGrip"; grip.Part0=hand; grip.Part1=body; grip.C0=tool.Grip; grip.Parent=hand end
			end
		end
	end
	return true
end

function Controller._loadTracks(self:any,model:Model,definition:any)
	local animationController=model:FindFirstChildOfClass("AnimationController")
	if animationController==nil then self:_warnOnce("AnimationController","[ViewmodelController] Flashlight viewmodel has no AnimationController; animations are disabled"); return end
	local foundAnimator=animationController:FindFirstChildOfClass("Animator")
	local animator:Animator
	if foundAnimator then animator=foundAnimator else local createdAnimator=Instance.new("Animator"); createdAnimator.Parent=animationController; animator=createdAnimator end
	for _,key in {definition.EquipAnimation,definition.IdleAnimation,definition.PrimaryAnimation,definition.UnequipAnimation} do
		local animationDefinition:any=AnimationConfig.Animations[key]
		if (animationDefinition==nil or animationDefinition.Id=="" or animationDefinition.Id=="rbxassetid://0") and definition.AnimationFallbacks then local fallbackKey:any=definition.AnimationFallbacks[key]; if typeof(fallbackKey)=="string" then animationDefinition=AnimationConfig.Animations[fallbackKey] end end
		if animationDefinition and animationDefinition.Id~="" and animationDefinition.Id~="rbxassetid://0" then
			local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=animationDefinition.Id
			local track=animator:LoadAnimation(animation); animation:Destroy(); track.Name=key
			track.Priority=animationDefinition.Priority; track.Looped=animationDefinition.Looped; self.Tracks[key]=track
		end
	end
end

function Controller._eligible(self:any):boolean
	return self.EquippedTool~=nil and self.FirstPerson:IsEnabled() and self.CameraController:IsGameplayCamera()
end

function Controller._activate(self:any):boolean
	local existingModel:Model?=self.Model
	if existingModel~=nil then return true end
	if not self:_eligible() then return false end
	local tool:Tool?=self.EquippedTool; local toolId:string?=self.ToolId
	if tool==nil or toolId==nil or tool.Parent~=LocalPlayer.Character then return false end
	local definition:any=ToolConfig.Tools[toolId]; local viewDefinition:any=if definition then definition.Viewmodel else nil
	if viewDefinition==nil or not viewDefinition.Enabled then self.Unavailable=true; return false end
	local assets=ReplicatedStorage:FindFirstChild("ClientAssets"); local folder=if assets then assets:FindFirstChild("Viewmodels") else nil
	local source=if folder then folder:FindFirstChild(viewDefinition.TemplateName) else nil
	if not source or not source:IsA("Model") then self.Unavailable=true; self:_warnOnce(toolId,`[ViewmodelController] Missing Model ReplicatedStorage.ClientAssets.Viewmodels.{viewDefinition.TemplateName}; using real Tool fallback`); return false end
	local model=source:Clone(); model.Name=`{toolId}Viewmodel`
	local root=model.PrimaryPart; if root==nil then local candidate=model:FindFirstChild(viewDefinition.RootName); if candidate and candidate:IsA("BasePart") then root=candidate; model.PrimaryPart=candidate end end
	if root==nil then model:Destroy(); self.Unavailable=true; self:_warnOnce(`{toolId}:Root`,`[ViewmodelController] {source:GetFullName()} needs a PrimaryPart or BasePart named {viewDefinition.RootName}`); return false end
	local character=LocalPlayer.Character
	local rigBuilt=if character then self:_buildCharacterRig(model,root,tool,character,viewDefinition) else false
	if viewDefinition.BuildArmsFromCharacter and not rigBuilt then model:Destroy(); self.Unavailable=true; return false end
	for _,descendant in model:GetDescendants() do if descendant:IsA("BasePart") then descendant.CanCollide=false; descendant.CanTouch=false; descendant.CanQuery=false; descendant.CastShadow=false; descendant.Massless=true end end
	root.Anchored=true
	local lightValue=resolvePath(model,viewDefinition.LightPath)
	if not lightValue or not lightValue:IsA("SpotLight") then model:Destroy(); self.Unavailable=true; self:_warnOnce(`{toolId}:Light`,`[ViewmodelController] Viewmodel is missing configured LightAttachment.SpotLight path`); return false end
	local attachmentParent=lightValue.Parent
	if not attachmentParent or not attachmentParent:IsA("Attachment") then model:Destroy(); self.Unavailable=true; self:_warnOnce(`{toolId}:Attachment`,`[ViewmodelController] Viewmodel SpotLight must be parented to an Attachment`); return false end
	local attachmentPart=attachmentParent.Parent
	if not attachmentPart or not attachmentPart:IsA("BasePart") then model:Destroy(); self.Unavailable=true; self:_warnOnce(`{toolId}:LightPart`,`[ViewmodelController] Viewmodel LightAttachment must be parented to a BasePart`); return false end
	local camera=Workspace.CurrentCamera; if camera==nil then model:Destroy(); return false end
	model.Parent=camera; model:PivotTo(camera.CFrame*viewDefinition.Offset)
	self.Model=model; self.Root=root; self.Attachment=attachmentParent; self.ViewLight=lightValue
	local defaults:any=definition.LightDefaults
	if defaults then lightValue.Face=defaults.Face; lightValue.Brightness=defaults.Brightness; lightValue.Range=defaults.Range; lightValue.Angle=defaults.Angle; lightValue.Shadows=defaults.Shadows; lightValue.Color=defaults.Color end
	lightValue.Face=definition.FlashlightAim.ExpectedFace; lightValue.Enabled=tool:GetAttribute("Active")==true
	self:_loadTracks(model,viewDefinition)
	local replacementArm=false
	for _,name in {"RightUpperArm","RightLowerArm","RightHand"} do local part=model:FindFirstChild(name,true); if part and part:IsA("BasePart") then replacementArm=true; break end end
	if viewDefinition.HideWorldTool then for _,descendant in tool:GetDescendants() do if descendant:IsA("BasePart") then self:_hidePart(descendant) end end end
	if character and viewDefinition.CopyCharacterArmColors then
		for _,name in {"RightUpperArm","RightLowerArm","RightHand"} do local characterPart=character:FindFirstChild(name); local viewPart=model:FindFirstChild(name,true); if characterPart and characterPart:IsA("BasePart") and viewPart and viewPart:IsA("BasePart") then viewPart.Color=characterPart.Color end end
	end
	if character and viewDefinition.CopyClassicShirt then
		for _,child in model:GetChildren() do if child:IsA("Shirt") then child:Destroy() end end
		local shirt=character:FindFirstChildOfClass("Shirt"); if shirt then local clonedShirt=shirt:Clone(); clonedShirt.Parent=model end
	end
	if replacementArm and viewDefinition.HideWorldRightArm and character then for _,name in {"RightUpperArm","RightLowerArm","RightHand"} do local part=character:FindFirstChild(name); if part and part:IsA("BasePart") then self:_hidePart(part) end end end
	local worldLightValue=resolvePath(tool,definition.LightPath)
	if worldLightValue and worldLightValue:IsA("SpotLight") then self.WorldLight=worldLightValue; self.WorldLightWasEnabled=worldLightValue.Enabled; worldLightValue.Enabled=false; table.insert(self.Connections,worldLightValue:GetPropertyChangedSignal("Enabled"):Connect(function() if self.Model~=nil and worldLightValue.Enabled then worldLightValue.Enabled=false end end)) end
	table.insert(self.Connections,tool:GetAttributeChangedSignal("Active"):Connect(function() local viewLight:SpotLight?=self.ViewLight; if viewLight then viewLight.Enabled=tool:GetAttribute("Active")==true end end))
	local filters:{Instance}={model,tool}; if character then table.insert(filters,character) end; self.RaycastParams.FilterDescendantsInstances=filters
	local desiredIdle:string?=self.DesiredIdleKey; if desiredIdle then self:SetIdle(desiredIdle) end
	return true
end

function Controller.SetEquippedTool(self:any,tool:Tool,toolId:string)
	self.Generation+=1; self.Removing=false; self.Unavailable=false; self.DesiredIdleKey=nil; self:_deactivate(); self.EquippedTool=tool; self.ToolId=toolId
	if self:_activate() then local definition:any=ToolConfig.Tools[toolId]; self:PlayAction(definition.Viewmodel.EquipAnimation) end
end

function Controller.SetIdle(self:any,animationKey:string?)
	self.DesiredIdleKey=animationKey
	local old:AnimationTrack?=self.IdleTrack; if old then old:Stop(.12) end; self.IdleTrack=nil
	if animationKey==nil then return end; local track:AnimationTrack?=self.Tracks[animationKey]; if track then self.IdleTrack=track; if not track.IsPlaying then track:Play(.12) end end
end

function Controller.PlayAction(self:any,animationKey:string):AnimationTrack?
	local track:AnimationTrack?=self.Tracks[animationKey]; if track==nil then return nil end
	local idle:AnimationTrack?=self.IdleTrack; if idle then idle:Stop(.1) end; track:Play(.1)
	local generation:number=self.Generation
	track.Stopped:Once(function() if self.Generation~=generation then return end; local currentIdle:AnimationTrack?=self.IdleTrack; if currentIdle and not currentIdle.IsPlaying then currentIdle:Play(.12) end end)
	return track
end

function Controller.Unequip(self:any,tool:Tool)
	if self.EquippedTool~=tool then return end; self.Generation+=1; local generation:number=self.Generation
	local toolId:string?=self.ToolId; self.Removing=true; self:_clearConnections(); self:_restoreVisibility()
	local duration=.25
	if toolId then local definition:any=ToolConfig.Tools[toolId]; if definition then local track=self:PlayAction(definition.Viewmodel.UnequipAnimation); if track and track.Length>0 then duration=math.min(track.Length,1) end end end
	self.EquippedTool=nil; local viewLight:SpotLight?=self.ViewLight; if viewLight then viewLight.Enabled=false end
	task.delay(duration,function() if self.Generation==generation then self.ToolId=nil; self.DesiredIdleKey=nil; self:_deactivate() end end)
end

function Controller.Clear(self:any)
	self.Generation+=1; self.EquippedTool=nil; self.ToolId=nil; self.DesiredIdleKey=nil; self:_deactivate()
end

function Controller._render(self:any)
	if self.Removing then local camera=Workspace.CurrentCamera; local model:Model?=self.Model; if camera and model then local toolId:string?=self.ToolId; if toolId then local definition:any=ToolConfig.Tools[toolId]; if definition then model:PivotTo(camera.CFrame*definition.Viewmodel.Offset) end end end; return end
	if not self:_eligible() then if self.Model~=nil then self:_deactivate() end; return end
	if self.Unavailable then return end
	if self.Model==nil and not self:_activate() then return end
	local camera=Workspace.CurrentCamera; local model:Model?=self.Model; local toolId:string?=self.ToolId
	if camera==nil or model==nil or toolId==nil then return end
	local definition:any=ToolConfig.Tools[toolId]; if definition==nil then return end
	model:PivotTo(camera.CFrame*definition.Viewmodel.Offset)
	for part in self.Visibility do if part.Parent~=nil then part.LocalTransparencyModifier=1 end end
	local worldLight:SpotLight?=self.WorldLight; if worldLight and worldLight.Enabled then worldLight.Enabled=false end
	local attachment:Attachment?=self.Attachment; if attachment==nil or not definition.FlashlightAim.Enabled then return end
	local viewport=camera.ViewportSize; local centerRay=camera:ViewportPointToRay(viewport.X*.5,viewport.Y*.5)
	local maximum:number=definition.FlashlightAim.MaximumDistance; local hit=Workspace:Raycast(centerRay.Origin,centerRay.Direction*maximum,self.RaycastParams)
	local target=if hit and definition.FlashlightAim.UseCrosshairHitPosition then hit.Position else centerRay.Origin+centerRay.Direction*maximum
	local origin=attachment.WorldPosition; local delta=target-origin; local minimum:number=definition.FlashlightAim.MinimumConvergenceDistance
	if delta.Magnitude<minimum then target=origin+centerRay.Direction*minimum end
	local parent=attachment.Parent; if not parent or not parent:IsA("BasePart") then return end
	local desired=CFrame.lookAt(origin,target)*definition.FlashlightAim.AimOrientationCorrection
	attachment.CFrame=parent.CFrame:ToObjectSpace(desired)
end

function Controller.Start(self:any)
	RunService:BindToRenderStep(RENDER_NAME,Enum.RenderPriority.Camera.Value+3,function() self:_render() end)
	table.insert(self.LifecycleConnections,LocalPlayer.CharacterRemoving:Connect(function() self:Clear() end))
end

function Controller.Destroy(self:any) RunService:UnbindFromRenderStep(RENDER_NAME); for _,connection:RBXScriptConnection in self.LifecycleConnections do connection:Disconnect() end; table.clear(self.LifecycleConnections); self:Clear() end
return Controller
