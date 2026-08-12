--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CharacterAnimationController
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config: any = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local PoseJointUtil: any = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PoseJointUtil"))
local Controller = {}
Controller.__index = Controller
local LocalPlayer = Players.LocalPlayer :: Player

function Controller.new(): any
	return setmetatable({Tracks={}, Current=nil, Direction=nil, Character=nil, Humanoid=nil,
		Animator=nil, Connections={}, StepConnection=nil, ToolIdleKey=nil, ToolIdleTrack=nil,
		ToolActionTrack=nil, ToolGeneration=0, InteractionTrack=nil, InteractionKey=nil, InteractionGeneration=0, HidingEnterTrack=nil, HidingIdleTrack=nil, HidingExitTrack=nil, HidingGeneration=0, HidingActive=false, HidingRootJoint=nil, HidingWarned=false, PoseStabilizerConnection=nil}, Controller)
end

function Controller._cleanup(self: any)
	self.ToolGeneration += 1
	for _, connection: RBXScriptConnection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	for _, track: AnimationTrack in self.Tracks do track:Stop(0); track:Destroy() end
	table.clear(self.Tracks)
	self.Current=nil; self.Direction=nil; self.Character=nil; self.Humanoid=nil; self.Animator=nil
	self.ToolIdleKey=nil; self.ToolIdleTrack=nil; self.ToolActionTrack=nil; self.InteractionTrack=nil; self.InteractionKey=nil
	self.HidingGeneration += 1; self.HidingEnterTrack=nil; self.HidingIdleTrack=nil; self.HidingExitTrack=nil; self.HidingActive=false; self.HidingRootJoint=nil; self.HidingWarned=false
end

function Controller._load(self: any, character: Model)
	self:_cleanup(); self.Character=character
	local humanoid=character:WaitForChild("Humanoid",10)
	if not humanoid or not humanoid:IsA("Humanoid") then return end
	self.Humanoid=humanoid
	local animator=humanoid:WaitForChild("Animator",10)
	if not animator or not animator:IsA("Animator") then return end
	self.Animator=animator
	local joints: any = PoseJointUtil.Resolve(character,true)
	self.HidingRootJoint=joints.Root
	local animate=character:FindFirstChild("Animate")
	if animate and (animate:IsA("LocalScript") or animate:IsA("Script")) then animate.Disabled=true end
	for key: string, definition: any in Config.Animations do
		if definition.Id ~= "rbxassetid://0" and definition.Id ~= "" then
			local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=definition.Id
			local track=animator:LoadAnimation(animation); animation:Destroy(); track.Name=key
			track.Priority=definition.Priority; track.Looped=definition.Looped; self.Tracks[key]=track
		end
	end
	self:_preloadInteractionAnimations()
	self:_transition("Idle")
end

function Controller._preloadInteractionAnimations(self: any)
	local keys={"OpenDrawer","CloseDrawer","LockerEnter","LockerIdle","LockerExit"}
	local seen:{[string]:boolean}={}
	local animations:{Instance}={}
	for _,key:string in keys do
		local definition:any=Config.Animations[key]
		if definition and definition.Id ~= "" and definition.Id ~= "rbxassetid://0" and not seen[definition.Id] then
			seen[definition.Id]=true
			local animation=Instance.new("Animation")
			animation.Name=`Preload_{key}`
			animation.AnimationId=definition.Id
			table.insert(animations,animation)
		end
	end
	if #animations==0 then return end
	task.spawn(function()
		local ok,err=pcall(function() ContentProvider:PreloadAsync(animations) end)
		if not ok and Config.InteractionTimingDebug then warn(`[CharacterAnimationController] interaction animation preload failed: {err}`) end
		for _,animation:Instance in animations do animation:Destroy() end
	end)
end

function Controller._playSynced(self: any, key: string, serverStartTime: number?, fallbackDuration: number?): AnimationTrack?
	local definition:any=Config.Animations[key]
	local track:AnimationTrack?=self.Tracks[key]
	if not definition or not track then return nil end
	track:Play(Config.FadeIn)
	local elapsed=0
	if serverStartTime~=nil then elapsed=math.max(0,workspace:GetServerTimeNow()-serverStartTime) end
	local duration=if track.Length>0 then track.Length elseif fallbackDuration~=nil then fallbackDuration else 0
	if duration>0 then track.TimePosition=math.clamp(elapsed,0,math.max(0,duration-.03)) end
	return track
end

function Controller._transition(self: any, key: string)
	if self.Current==key then return end
	local old: AnimationTrack?=if self.Current then self.Tracks[self.Current] else nil
	if old then old:Stop(Config.FadeOut) end
	self.Current=key
	local track: AnimationTrack?=self.Tracks[key]
	if track then track:Play(Config.FadeIn) end
end

function Controller.PlayAction(self: any, key: string): AnimationTrack?
	local definition: any=Config.Animations[key]; local track: AnimationTrack?=self.Tracks[key]
	if not definition or not track then return nil end
	track:Play(Config.FadeIn); return track
end

function Controller.PlayInteractionAction(self: any, key: string, serverStartTime: number?, fallbackDuration: number?): AnimationTrack?
	local track: AnimationTrack?=self.Tracks[key]
	if track==nil or Config.Animations[key]==nil then return nil end
	local current: AnimationTrack?=self.InteractionTrack
	if current==track and track.IsPlaying then return track end
	if current and current~=track then current:Stop(Config.FadeOut) end
	self.InteractionGeneration += 1
	self.InteractionTrack=track; self.InteractionKey=key
	return self:_playSynced(key,serverStartTime,fallbackDuration)
end

function Controller.StopInteractionAction(self: any, fadeTime: number?)
	self.InteractionGeneration += 1
	local track: AnimationTrack?=self.InteractionTrack
	if track then track:Stop(if fadeTime~=nil then fadeTime else Config.FadeOut) end
	self.InteractionTrack=nil; self.InteractionKey=nil
end

function Controller._stopNonHidingActions(self: any, fadeTime: number?)
	self:StopInteractionAction(fadeTime)
	self:ClearToolAnimations()
	for key:string,track:AnimationTrack in self.Tracks do
		if key~="LockerEnter" and key~="LockerIdle" and key~="LockerExit" then
			local definition:any=Config.Animations[key]
			if definition and track.IsPlaying then
				local priority:Enum.AnimationPriority=definition.Priority
				if priority==Enum.AnimationPriority.Action or priority==Enum.AnimationPriority.Action2 or priority==Enum.AnimationPriority.Action3 or priority==Enum.AnimationPriority.Action4 then
					track:Stop(if fadeTime~=nil then fadeTime else Config.FadeOut)
				end
			end
		end
	end
end

function Controller.BeginHidingEnter(self: any, serverStartTime: number?, duration: number?): AnimationTrack?
	self.HidingGeneration += 1; self.HidingActive=false; self.HidingWarned=false
	self:_stopNonHidingActions(.08)
	local exitTrack:AnimationTrack?=self.HidingExitTrack; if exitTrack then exitTrack:Stop(.08) end
	local idleTrack:AnimationTrack?=self.HidingIdleTrack; if idleTrack then idleTrack:Stop(.08) end
	local track=self:_playSynced("LockerEnter",serverStartTime,duration)
	self.HidingEnterTrack=track
	return track
end

function Controller.BeginHidingIdle(self: any): AnimationTrack?
	self.HidingGeneration += 1; self.HidingActive=true
	self:_stopNonHidingActions(.08)
	local enterTrack:AnimationTrack?=self.HidingEnterTrack; if enterTrack then enterTrack:Stop(.08) end
	local exitTrack:AnimationTrack?=self.HidingExitTrack; if exitTrack then exitTrack:Stop(.08) end
	local track:AnimationTrack?=self.Tracks.LockerIdle
	if track then track.Looped=true; if not track.IsPlaying then track:Play(Config.FadeIn) end; self.HidingIdleTrack=track end
	self:DebugPlayingTracks("Hidden")
	return track
end

function Controller.BeginHidingExit(self: any, serverStartTime: number?, duration: number?): AnimationTrack?
	self.HidingGeneration += 1; self.HidingActive=false
	local idleTrack:AnimationTrack?=self.HidingIdleTrack; if idleTrack then idleTrack:Stop(.08) end
	self:_stopNonHidingActions(.08)
	local track=self:_playSynced("LockerExit",serverStartTime,duration)
	self.HidingExitTrack=track
	return track
end

function Controller.ClearHidingAnimations(self: any, fadeTime: number?)
	self.HidingGeneration += 1; self.HidingActive=false; self.HidingWarned=false
	local fade=if fadeTime~=nil then fadeTime else Config.FadeOut
	local enterTrack:AnimationTrack?=self.HidingEnterTrack; if enterTrack then enterTrack:Stop(fade) end
	local idleTrack:AnimationTrack?=self.HidingIdleTrack; if idleTrack then idleTrack:Stop(fade) end
	local exitTrack:AnimationTrack?=self.HidingExitTrack; if exitTrack then exitTrack:Stop(fade) end
	self.HidingEnterTrack=nil; self.HidingIdleTrack=nil; self.HidingExitTrack=nil
end

function Controller.DebugPlayingTracks(self: any, context: string)
	if not Config.HidingDebug then return end
	local animator:Animator?=self.Animator; if animator==nil then return end
	for _,track:AnimationTrack in animator:GetPlayingAnimationTracks() do
		print(`[HidingTracks] {context} {track.Name} priority={track.Priority.Name} weight={track.WeightCurrent} target={track.WeightTarget} time={track.TimePosition} length={track.Length} looped={track.Looped}`)
	end
end

function Controller._stabilizeHidingRoot(self: any)
	if not self.HidingActive or Config.StabilizeRootTranslationWhileHidden~=true then return end
	local joint:any=self.HidingRootJoint
	if joint==nil then return end
	local transform:CFrame=joint.Transform
	local tolerance=if typeof(Config.RootTranslationTolerance)=="number" then Config.RootTranslationTolerance else .05
	if transform.Position.Magnitude<=tolerance then return end
	if not self.HidingWarned then self.HidingWarned=true; warn(`[CharacterAnimationController] Hidden animation is translating Root/RootJoint by {transform.Position.Magnitude}; stripping translation while hidden. Reauthor LockerIdle/LockerEnter without root translation.`) end
	local rx,ry,rz=transform:ToOrientation()
	joint.Transform=CFrame.fromOrientation(rx,ry,rz)
end

function Controller.SetToolIdle(self: any, animationKey: string?)
	if self.ToolIdleTrack then self.ToolIdleTrack:Stop(Config.FadeOut) end
	self.ToolGeneration += 1; self.ToolIdleKey=animationKey; self.ToolIdleTrack=nil
	if animationKey == nil then return end
	local track: AnimationTrack?=self.Tracks[animationKey]
	if track then self.ToolIdleTrack=track; if not track.IsPlaying then track:Play(Config.FadeIn) end end
end

function Controller.PlayToolAction(self: any, animationKey: string): AnimationTrack?
	local track: AnimationTrack?=self.Tracks[animationKey]
	if track==nil then return nil end
	self.ToolGeneration += 1
	local generation: number=self.ToolGeneration
	local idle: AnimationTrack?=self.ToolIdleTrack
	if idle then idle:Stop(Config.FadeOut) end
	track:Play(Config.FadeIn); self.ToolActionTrack=track
	table.insert(self.Connections, track.Stopped:Connect(function()
		if self.ToolGeneration~=generation or self.ToolActionTrack~=track then return end
		self.ToolActionTrack=nil
		local currentIdle: AnimationTrack?=self.ToolIdleTrack
		if currentIdle and not currentIdle.IsPlaying then currentIdle:Play(Config.FadeIn) end
	end))
	return track
end

function Controller.ClearToolAnimations(self: any)
	self.ToolGeneration += 1
	local action: AnimationTrack?=self.ToolActionTrack; if action then action:Stop(Config.FadeOut) end
	local idle: AnimationTrack?=self.ToolIdleTrack; if idle then idle:Stop(Config.FadeOut) end
	self.ToolActionTrack=nil; self.ToolIdleTrack=nil; self.ToolIdleKey=nil
end

function Controller._direction(self: any, localVelocity: Vector3): string
	local x,z=localVelocity.X,localVelocity.Z
	local candidate=if math.abs(x)>math.abs(z) then (if x<0 then "Left" else "Right") else (if z<0 then "Forward" else "Backward")
	local current: string?=self.Direction
	if current and current~=candidate then
		local currentStrength=if current=="Left" or current=="Right" then math.abs(x) else math.abs(z)
		local candidateStrength=if candidate=="Left" or candidate=="Right" then math.abs(x) else math.abs(z)
		local oppositeAxis=(current=="Left" and candidate=="Right") or (current=="Right" and candidate=="Left") or (current=="Forward" and candidate=="Backward") or (current=="Backward" and candidate=="Forward")
		local switchMargin=Config.DirectionalMovement.DirectionSwitchThreshold+Config.DirectionalMovement.DirectionHysteresis
		if not oppositeAxis and candidateStrength < currentStrength + switchMargin then return current end
	end
	self.Direction=candidate; return candidate
end

function Controller._locomotionKey(self: any, base: string, localVelocity: Vector3): string
	if not Config.DirectionalMovement.Enabled or localVelocity.Magnitude<Config.DirectionalMovement.MinimumDirectionalSpeed then return base end
	local direction=self:_direction(localVelocity)
	local directionalKey=if base=="CrouchWalk" then `CrouchWalk{direction}` else `{base}{direction}`
	if self.Tracks[directionalKey] then return directionalKey end
	-- Normal WalkSpeed is currently above the Run threshold. Until dedicated
	-- Run direction tracks are supplied, reuse the configured directional Walk
	-- track instead of losing sideways/backward animation selection.
	if base=="Run" then
		local walkDirectionalKey=`Walk{direction}`
		if self.Tracks[walkDirectionalKey] then return walkDirectionalKey end
	end
	-- Base Walk/Run/CrouchWalk is the final missing-ID fallback.
	return base
end

function Controller._step(self: any)
	local humanoid: Humanoid?=self.Humanoid; if not humanoid or humanoid.Health<=0 then return end
	local state=humanoid:GetState(); local key: string; local speed=0
	if state==Enum.HumanoidStateType.Jumping then key="Jump"
	elseif state==Enum.HumanoidStateType.Freefall then key="Fall"
	else
		local character: Model?=self.Character; local rootInstance=if character then character:FindFirstChild("HumanoidRootPart") else nil
		local velocity=if rootInstance and rootInstance:IsA("BasePart") then rootInstance.AssemblyLinearVelocity else Vector3.zero
		local horizontal=Vector3.new(velocity.X,0,velocity.Z); speed=horizontal.Magnitude
		local localVelocity=if rootInstance and rootInstance:IsA("BasePart") then rootInstance.CFrame:VectorToObjectSpace(horizontal) else Vector3.zero
		local crouched=humanoid:GetAttribute("Crouched")==true
		if crouched then key=if speed<.5 then "CrouchIdle" else self:_locomotionKey("CrouchWalk",localVelocity)
		elseif speed<.5 then key="Idle"
		elseif speed>13 then key=self:_locomotionKey("Run",localVelocity)
		else key=self:_locomotionKey("Walk",localVelocity) end
	end
	self:_transition(key)
	local track: AnimationTrack?=self.Tracks[key]; local definition: any=Config.Animations[key]
	if track and definition and definition.AuthoredSpeed>1 then track:AdjustSpeed(math.clamp(speed/definition.AuthoredSpeed,Config.MinSpeed,Config.MaxSpeed)) end
end

function Controller.Start(self: any)
	LocalPlayer.CharacterAdded:Connect(function(character) self:_load(character) end)
	LocalPlayer.CharacterRemoving:Connect(function() self:_cleanup() end)
	if LocalPlayer.Character then self:_load(LocalPlayer.Character :: Model) end
	self.StepConnection=RunService.Heartbeat:Connect(function() self:_step() end)
	self.PoseStabilizerConnection=RunService.PreSimulation:Connect(function() self:_stabilizeHidingRoot() end)
end
return Controller
