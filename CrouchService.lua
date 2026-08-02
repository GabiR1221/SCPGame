--!strict
-- ModuleScript: ServerScriptService/Services/CrouchService
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterConfig"))

local Service={}; Service.__index=Service
function Service.new(states:any):any return setmetatable({States=states,LastRequest={} :: {[Player]:number}},Service) end

function Service._set(self:any,player:Player,wantsCrouch:boolean)
	local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health<=0 then return end
	if not self.States:CanBegin(player) or self.States:IsLocked(player,"Movement") then return end
	local standingValue=humanoid:GetAttribute("StandingHipHeight"); local standing:number
	if typeof(standingValue)=="number" then standing=standingValue else standing=humanoid.HipHeight; humanoid:SetAttribute("StandingHipHeight",standing) end
	if not wantsCrouch and character then local root=character:FindFirstChild("HumanoidRootPart"); if root and root:IsA("BasePart") then local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character}; if workspace:Raycast(root.Position,Vector3.new(0,math.abs(Config.CrouchHipHeightOffset)+1.5,0),params) then return end end end
	humanoid:SetAttribute("Crouched",wantsCrouch)
	humanoid:SetAttribute("ConfiguredWalkSpeed",if wantsCrouch then Config.CrouchSpeed else Config.WalkSpeed)
	humanoid:SetAttribute("ConfiguredJumpPower",if wantsCrouch then 0 else Config.JumpPower)
	humanoid.HipHeight=if wantsCrouch then math.max(0,standing+Config.CrouchHipHeightOffset) else standing
	self.States:Refresh(player)
end

function Service.Start(self:any,remote:RemoteEvent)
	remote.OnServerEvent:Connect(function(player:Player,wantsCrouch:any)
		if typeof(wantsCrouch)~="boolean" then return end
		local now=os.clock(); if now-(self.LastRequest[player] or 0)<Config.CrouchToggleCooldown then return end; self.LastRequest[player]=now
		self:_set(player,wantsCrouch)
	end)
	Players.PlayerRemoving:Connect(function(player) self.LastRequest[player]=nil end)
end
return Service
