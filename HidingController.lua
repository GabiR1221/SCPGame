--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/HidingController
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HidingConfig"))
local C={}; C.__index=C
function C.new(camera:any,animation:any,firstPerson:any):any
	local remotes=ReplicatedStorage:WaitForChild("Remotes")
	return setmetatable({Camera=camera,Animation=animation,FirstPerson=firstPerson,Hidden=false,Entering=false,Exiting=false,EnterGeneration=0,IdleTrack=nil :: AnimationTrack?,ExitTrack=nil :: AnimationTrack?,Request=remotes:WaitForChild("HidingRequest") :: RemoteEvent,State=remotes:WaitForChild("HidingStateChanged") :: RemoteEvent},C)
end
function C._stopTracks(self:any)
	local idle:AnimationTrack?=self.IdleTrack; if idle then idle:Stop(.12) end
	local exit:AnimationTrack?=self.ExitTrack; if exit then exit:Stop(.12) end
	self.IdleTrack=nil; self.ExitTrack=nil
	self.Animation:ClearHidingAnimations(.12)
end
function C._setBodyControlEnabled(self:any,enabled:boolean)
	local player=Players.LocalPlayer
	if player then
		player:SetAttribute("FirstPersonBodyPoseEnabled",enabled)
		player:SetAttribute("FirstPersonCharacterYawEnabled",enabled)
	end
	local firstPerson:any=self.FirstPerson
	if firstPerson~=nil then
		firstPerson:SetBodyControlEnabled(enabled)
	end
end
function C.RequestEnter(self:any,locker:Instance):boolean
	if self.Hidden or self.Entering or self.Exiting then return false end
	self.Entering=true; self.EnterGeneration+=1; local generation:number=self.EnterGeneration
	self:_setBodyControlEnabled(false)
	self.Request:FireServer("Enter",locker)
	task.delay(Config.EnterRequestFallbackDuration,function()
		if self.EnterGeneration~=generation or not self.Entering or self.Hidden then return end
		self.Entering=false; self:_setBodyControlEnabled(true)
	end)
	return true
end
function C.HandleInteract(self:any):boolean
	if not self.Hidden or self.Exiting then return false end
	-- The server owns the phase change. Do not optimistically mark Exiting here:
	-- a rate-limited request would otherwise leave the client stuck forever.
	self.Request:FireServer("Exit"); return true
end
function C.Start(self:any)
	local player=Players.LocalPlayer; if player then player.CharacterAdded:Connect(function() self.Hidden=false; self.Entering=false; self.Exiting=false; self:_stopTracks(); self.Animation:StopInteractionAction(.12); self.Animation:ClearHidingAnimations(.12); self:_setBodyControlEnabled(true); self.Camera:Release("Hiding") end) end
	self.State.OnClientEvent:Connect(function(message:any)
		if message.Kind=="Entering" then
			self.Hidden=false; self.Entering=true; self.Exiting=false; self:_setBodyControlEnabled(false); self.Animation:BeginHidingEnter(message.ServerStartTime,message.EnterDuration)
		elseif message.Kind=="Hidden" then
			self:_stopTracks(); self.Hidden=true; self.Entering=false; self.Exiting=false; self:_setBodyControlEnabled(false); self.IdleTrack=self.Animation:BeginHidingIdle()
			if Config.UseFixedCamera and self.Camera:Acquire("Hiding","Hiding") then self.Camera:SetScriptCFrame("Hiding",message.CameraCFrame); self.Camera:SetFov("Hiding",message.Fov) end
		elseif message.Kind=="Exiting" then
			local idle:AnimationTrack?=self.IdleTrack; if idle then idle:Stop(.12) end; self.IdleTrack=nil; self.Exiting=true; self:_setBodyControlEnabled(false); self.ExitTrack=self.Animation:BeginHidingExit(message.ServerStartTime,message.ExitDuration)
		elseif message.Kind=="Exited" then
			self.Hidden=false; self.Entering=false; self.Exiting=false; self:_stopTracks(); self.Animation:StopInteractionAction(.12); self.Animation:ClearHidingAnimations(.12); self:_setBodyControlEnabled(true); self.Camera:Release("Hiding")
		end
	end)
end
return C
