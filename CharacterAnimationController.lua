--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CharacterAnimationController
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config: any = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local Controller = {}
Controller.__index = Controller
local LocalPlayer = Players.LocalPlayer :: Player

function Controller.new(): any
	return setmetatable({Tracks={}, Current=nil, Direction=nil, Character=nil, Humanoid=nil,
		Animator=nil, Connections={}, StepConnection=nil, ToolIdleKey=nil, ToolIdleTrack=nil,
		ToolActionTrack=nil, ToolGeneration=0, InteractionTrack=nil, InteractionKey=nil, InteractionGeneration=0}, Controller)
end

function Controller._cleanup(self: any)
	self.ToolGeneration += 1
	for _, connection: RBXScriptConnection in self.Connections do connection:Disconnect() end
	table.clear(self.Connections)
	for _, track: AnimationTrack in self.Tracks do track:Stop(0); track:Destroy() end
	table.clear(self.Tracks)
	self.Current=nil; self.Direction=nil; self.Character=nil; self.Humanoid=nil; self.Animator=nil
	self.ToolIdleKey=nil; self.ToolIdleTrack=nil; self.ToolActionTrack=nil; self.InteractionTrack=nil; self.InteractionKey=nil
end

function Controller._load(self: any, character: Model)
	self:_cleanup(); self.Character=character
	local humanoid=character:WaitForChild("Humanoid",10)
	if not humanoid or not humanoid:IsA("Humanoid") then return end
	self.Humanoid=humanoid
	local animator=humanoid:WaitForChild("Animator",10)
	if not animator or not animator:IsA("Animator") then return end
	self.Animator=animator
	local animate=character:FindFirstChild("Animate")
	if animate and (animate:IsA("LocalScript") or animate:IsA("Script")) then animate.Disabled=true end
	for key: string, definition: any in Config.Animations do
		if definition.Id ~= "rbxassetid://0" and definition.Id ~= "" then
			local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=definition.Id
			local track=animator:LoadAnimation(animation); animation:Destroy(); track.Name=key
			track.Priority=definition.Priority; track.Looped=definition.Looped; self.Tracks[key]=track
		end
	end
	self:_transition("Idle")
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
	local definition: any=Config.Animations[key]
	local track: AnimationTrack?=self.Tracks[key]
	if not definition or not track then return nil end
	local current: AnimationTrack?=self.InteractionTrack
	if current==track and track.IsPlaying then return track end
	if current and current~=track then current:Stop(Config.FadeOut) end
	self.InteractionGeneration += 1
	self.InteractionTrack=track; self.InteractionKey=key
	track:Play(Config.FadeIn)
	local elapsed=0
	if serverStartTime~=nil then elapsed=math.max(0, workspace:GetServerTimeNow()-serverStartTime) end
	local length=track.Length
	local duration=if length>0 then length elseif fallbackDuration~=nil then fallbackDuration else 0
	if duration>0 then track.TimePosition=math.clamp(elapsed,0,math.max(0,duration-.03)) end
	return track
end

function Controller.StopInteractionAction(self: any, fadeTime: number?)
	self.InteractionGeneration += 1
	local track: AnimationTrack?=self.InteractionTrack
	if track then track:Stop(if fadeTime~=nil then fadeTime else Config.FadeOut) end
	self.InteractionTrack=nil; self.InteractionKey=nil
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
end
return Controller
