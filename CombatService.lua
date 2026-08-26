--!strict
-- ModuleScript: ServerScriptService/Services/CombatService
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local shared=ReplicatedStorage:WaitForChild("Shared")
local powerConfigModule=shared:WaitForChild("PowerConfig")
assert(powerConfigModule:IsA("ModuleScript"),"ReplicatedStorage.Shared.PowerConfig must be a ModuleScript")
local Config:any=require(powerConfigModule)

local Service={}; Service.__index=Service
type Record={Equipped:boolean,Model:Model?,LastFire:number}
type Projectile={Visual:Instance,ForwardToPivot:CFrame,Position:Vector3,Direction:Vector3,RemainingRange:number,ExpiresAt:number,Damage:number,Shooter:Player,Character:Model}

local function getPivot(visual:Instance):CFrame
	if visual:IsA("Model") then return visual:GetPivot() elseif visual:IsA("BasePart") then return visual.CFrame end
	return CFrame.new()
end
local function moveVisual(visual:Instance,forwardToPivot:CFrame,position:Vector3,direction:Vector3)
	local cframe=CFrame.lookAt(position,position+direction)*forwardToPivot
	if visual:IsA("Model") then visual:PivotTo(cframe) elseif visual:IsA("BasePart") then visual.CFrame=cframe end
end

function Service.new(playerState:any,upgrades:any,creatures:any,request:RemoteEvent,stateRemote:RemoteEvent):any
	return setmetatable({PlayerState=playerState,Upgrades=upgrades,Creatures=creatures,Request=request,StateRemote=stateRemote,Records={} :: {[Player]:Record},Projectiles={} :: {Projectile},ProjectileConnection=nil :: RBXScriptConnection?,BulletForwardWarned=false},Service)
end
function Service._valid(self:any,player:Player):boolean return self.PlayerState:CanUseTools(player) and self.Upgrades:GetTreeId(player)=="Gun" end
function Service._unequip(self:any,player:Player)
	local record:Record?=self.Records[player]; if not record then return end
	record.Equipped=false; if record.Model then record.Model:Destroy(); record.Model=nil end
	player:SetAttribute("PowerEquipped",nil); self.StateRemote:FireClient(player,"Unequipped",Config.Gun.UnequipAnimation)
end
function Service._equip(self:any,player:Player)
	if not self:_valid(player) then self:_unequip(player); return end
	local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil; local hand=if character then character:FindFirstChild("RightHand") else nil
	if not character or not humanoid or not hand or not hand:IsA("BasePart") then return end; humanoid:UnequipTools()
	local folder=ServerStorage:FindFirstChild("PowerTemplates"); local source=if folder then folder:FindFirstChild(Config.Gun.TemplateName) else nil
	if not source or not source:IsA("Model") then warn("[CombatService] ServerStorage.PowerTemplates.Gun Model is missing"); return end
	local model=source:Clone(); local handle=model:FindFirstChild("Handle"); if not handle or not handle:IsA("BasePart") then warn("[CombatService] Gun.Handle must be a BasePart"); model:Destroy(); return end
	for _,part in model:GetDescendants() do if part:IsA("BasePart") then part.Anchored=false; part.CanCollide=false; part.CanTouch=false; part.Massless=true end end
	model.PrimaryPart=handle
	local handGrip=hand:FindFirstChild(Config.Gun.HandGripAttachmentName)
	local gunGrip=model:FindFirstChild(Config.Gun.GunGripAttachmentName,true)
	if handGrip and handGrip:IsA("Attachment") and gunGrip and gunGrip:IsA("Attachment") then
		local gripFromPivot=model:GetPivot():ToObjectSpace(gunGrip.WorldCFrame)
		model:PivotTo(handGrip.WorldCFrame*gripFromPivot:Inverse())
	else
		model:PivotTo(hand.CFrame*Config.Gun.GripCFrame)
		warn("[CombatService] Gun grip Attachments are missing; using PowerConfig.Gun.GripCFrame fallback")
	end
	model.Parent=character
	local weld=Instance.new("WeldConstraint"); weld.Name="PowerGrip"; weld.Part0=hand; weld.Part1=handle; weld.Parent=handle
	local record=self.Records[player] or {Equipped=false,Model=nil,LastFire=0}; self.Records[player]=record; record.Equipped=true; record.Model=model
	player:SetAttribute("PowerEquipped","Gun"); self.StateRemote:FireClient(player,"Equipped",Config.Gun.EquipAnimation,Config.Gun.IdleAnimation)
end
function Service._createBullet(self:any,player:Player,character:Model,origin:Vector3,direction:Vector3,damage:number,range:number):boolean
	local templates=ServerStorage:FindFirstChild("PowerTemplates"); local source=if templates then templates:FindFirstChild(Config.Gun.BulletTemplateName) else nil
	if not source or (not source:IsA("Model") and not source:IsA("BasePart")) then warn("[CombatService] ServerStorage.PowerTemplates.GunBullet must be a Model or BasePart; shot cancelled"); return false end
	local visual:Instance=source:Clone()
	if visual:IsA("Model") and not visual.PrimaryPart then warn("[CombatService] GunBullet Model requires a PrimaryPart"); visual:Destroy(); return false end
	if visual:IsA("BasePart") then visual.Anchored=true; visual.CanCollide=false; visual.CanTouch=false; visual.CanQuery=false else for _,descendant in visual:GetDescendants() do if descendant:IsA("BasePart") then descendant.Anchored=true; descendant.CanCollide=false; descendant.CanTouch=false; descendant.CanQuery=false end end end
	local forwardToPivot: CFrame=Config.Gun.BulletOrientationOffset
	local forwardValue=visual:FindFirstChild(Config.Gun.BulletForwardAttachmentName,true)
	if forwardValue and forwardValue:IsA("Attachment") then
		local forwardFromPivot=getPivot(visual):ToObjectSpace(forwardValue.WorldCFrame)
		forwardToPivot=forwardFromPivot:Inverse()
	elseif not self.BulletForwardWarned then
		self.BulletForwardWarned=true
		warn("[CombatService] GunBullet.ForwardAttachment is missing; using PowerConfig.Gun.BulletOrientationOffset fallback")
	end
	local runtime=workspace:FindFirstChild("RuntimeEntities"); visual.Name="GunBullet"; visual.Parent=runtime or workspace; moveVisual(visual,forwardToPivot,origin,direction)
	table.insert(self.Projectiles,{Visual=visual,ForwardToPivot=forwardToPivot,Position=origin,Direction=direction,RemainingRange=range,ExpiresAt=workspace:GetServerTimeNow()+Config.Gun.MaximumBulletLifetime,Damage=damage,Shooter=player,Character=character})
	return true
end
function Service._fire(self:any,player:Player,directionValue:unknown)
	local record:Record?=self.Records[player]; if not record or not record.Equipped or not self:_valid(player) then self:_unequip(player); return end
	if typeof(directionValue)~="Vector3" then return end; local direction:Vector3=directionValue; local magnitude=direction.Magnitude; if magnitude~=magnitude or magnitude<.99 or magnitude>Config.Gun.MaximumAimDirectionMagnitude then return end; direction=direction.Unit
	local effects=self.Upgrades:GetEffects(player); local cooldown=Config.Gun.FireCooldown*(effects.FireCooldownMultiplier or 1); player:SetAttribute("EffectiveGunFireCooldown",cooldown)
	local now=workspace:GetServerTimeNow(); if now-record.LastFire<math.max(.05,cooldown) then return end
	local character=player.Character; if not character then return end; local muzzlePosition:Vector3?=nil; if record.Model then local muzzle=record.Model:FindFirstChild("Muzzle",true); if muzzle and muzzle:IsA("Attachment") then muzzlePosition=muzzle.WorldPosition end end
	local root=character:FindFirstChild("HumanoidRootPart"); local origin=if muzzlePosition then muzzlePosition else if root and root:IsA("BasePart") then root.Position+Vector3.new(0,1.5,0) else nil; if not origin then return end
	local range=Config.Gun.Range+(effects.RangeBonus or 0); local damage=Config.Gun.Damage*(effects.DamageMultiplier or 1)+(effects.DamageBonus or 0)
	if not self:_createBullet(player,character,origin,direction,damage,range) then return end
	record.LastFire=now; self.StateRemote:FireClient(player,"Fired",Config.Gun.FireAnimation)
end
function Service._stepProjectiles(self:any,dt:number)
	local now=workspace:GetServerTimeNow()
	for index=#self.Projectiles,1,-1 do
		local projectile:Projectile=self.Projectiles[index]
		local distance=math.min(projectile.RemainingRange,Config.Gun.BulletSpeed*dt)
		local remove=now>=projectile.ExpiresAt or distance<=0 or projectile.Visual.Parent==nil
		if not remove then
			local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={projectile.Character,projectile.Visual}; params.IgnoreWater=true
			local result=workspace:Raycast(projectile.Position,projectile.Direction*distance,params)
			if result then projectile.Position=result.Position; self.Creatures:Damage(result.Instance,projectile.Damage,projectile.Shooter); remove=true else projectile.Position+=projectile.Direction*distance; projectile.RemainingRange-=distance; moveVisual(projectile.Visual,projectile.ForwardToPivot,projectile.Position,projectile.Direction); remove=projectile.RemainingRange<=0 end
		end
		if remove then projectile.Visual:Destroy(); table.remove(self.Projectiles,index) end
	end
end
function Service.Start(self:any)
	self.Request.OnServerEvent:Connect(function(player:Player,action:unknown,value:unknown) if action=="Toggle" then local r:Record?=self.Records[player]; if r and r.Equipped then self:_unequip(player) else self:_equip(player) end elseif action=="Fire" then self:_fire(player,value) end end)
	local function added(player:Player) self.Records[player]={Equipped=false,Model=nil,LastFire=0}; player.CharacterAdded:Connect(function(character) self:_unequip(player); local humanoid=character:WaitForChild("Humanoid",10); if humanoid and humanoid:IsA("Humanoid") then humanoid.Died:Once(function() self:_unequip(player) end) end end) end
	Players.PlayerAdded:Connect(added); Players.PlayerRemoving:Connect(function(p) self:_unequip(p); self.Records[p]=nil end); for _,p in Players:GetPlayers() do added(p) end
	self.ProjectileConnection=RunService.Heartbeat:Connect(function(dt:number) self:_stepProjectiles(dt) end)
	task.spawn(function() while true do task.wait(.25); for p,r in self.Records do if r.Equipped and not self:_valid(p) then self:_unequip(p) end end end end)
end
return Service
