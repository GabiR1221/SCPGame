--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/HidingController
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("HidingConfig"))
local C={}; C.__index=C
function C.new(camera:any,animation:any,firstPerson:any):any
	local remotes=ReplicatedStorage:WaitForChild("Remotes")
	return setmetatable({Camera=camera,Animation=animation,FirstPerson=firstPerson,Hidden=false,Exiting=false,IdleTrack=nil :: AnimationTrack?,ExitTrack=nil :: AnimationTrack?,Request=remotes:WaitForChild("HidingRequest") :: RemoteEvent,State=remotes:WaitForChild("HidingStateChanged") :: RemoteEvent},C)
end
function C._stopTracks(self:any)
	local idle:AnimationTrack?=self.IdleTrack; if idle then idle:Stop(.12) end
	local exit:AnimationTrack?=self.ExitTrack; if exit then exit:Stop(.12) end
	self.IdleTrack=nil; self.ExitTrack=nil
end
function C._setBodyPoseEnabled(_self:any,enabled:boolean)
	local player=Players.LocalPlayer
	if player then
		player:SetAttribute("FirstPersonBodyPoseEnabled",enabled)
	end
end
function C.HandleInteract(self:any):boolean
	if not self.Hidden or self.Exiting then return false end
	-- The server owns the phase change. Do not optimistically mark Exiting here:
	-- a rate-limited request would otherwise leave the client stuck forever.
	self.Request:FireServer("Exit"); return true
end
function C.Start(self:any)
	local player=Players.LocalPlayer; if player then player.CharacterAdded:Connect(function() self.Hidden=false; self.Exiting=false; self:_stopTracks(); self:_setBodyPoseEnabled(true); self.Camera:Release("Hiding") end) end
	self.State.OnClientEvent:Connect(function(message:any)
		if message.Kind=="Hidden" then
			self:_stopTracks(); self.Hidden=true; self.Exiting=false; self:_setBodyPoseEnabled(false); self.IdleTrack=self.Animation:PlayAction("LockerIdle")
			if Config.UseFixedCamera and self.Camera:Acquire("Hiding","Hiding") then self.Camera:SetScriptCFrame("Hiding",message.CameraCFrame); self.Camera:SetFov("Hiding",message.Fov) end
		elseif message.Kind=="Exiting" then
			local idle:AnimationTrack?=self.IdleTrack; if idle then idle:Stop(.12) end; self.IdleTrack=nil; self.Exiting=true; self.ExitTrack=self.Animation:PlayAction("LockerExit")
		elseif message.Kind=="Exited" then
			self.Hidden=false; self.Exiting=false; self:_stopTracks(); self:_setBodyPoseEnabled(true); self.Camera:Release("Hiding")
		end
	end)
end
return C
