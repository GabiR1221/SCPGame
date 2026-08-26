--!strict
-- ModuleScript: ServerScriptService/Services/CreatureService
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local shared=ReplicatedStorage:WaitForChild("Shared")
local entityConfigModule=shared:WaitForChild("EntityConfig")
assert(entityConfigModule:IsA("ModuleScript"),"ReplicatedStorage.Shared.EntityConfig must be a ModuleScript")
local entityConfig:any=require(entityConfigModule)
local Config:any=entityConfig.Entities.Hert
local Service={}; Service.__index=Service
type Creature={Model:Model,Root:BasePart,Room:any,Health:number,MaxHealth:number,Dead:boolean,State:string,NextAttack:number,JumpStart:number,StartPosition:Vector3,TargetPosition:Vector3,HitPlayers:{[Player]:boolean},Tracks:{[string]:AnimationTrack},Random:Random}

local function play(creature:Creature,key:string)
	for name,track in creature.Tracks do if name~=key and track.IsPlaying then track:Stop(.1) end end
	local track=creature.Tracks[key]; if track and not track.IsPlaying then track:Play(.1) end
end
function Service.new(lifecycle:any,tracker:any,runManager:any):any
	return setmetatable({Lifecycle=lifecycle,Tracker=tracker,RunManager=runManager,Creatures={} :: {[Model]:Creature},Connection=nil :: RBXScriptConnection?},Service)
end
function Service._register(self:any,model:Model,room:any):Creature?
	local root=model.PrimaryPart; if not root then warn(`[CreatureService] {model:GetFullName()} has no PrimaryPart`); model:Destroy(); return nil end
	for _,part in model:GetDescendants() do if part:IsA("BasePart") then part.Anchored=true; part.CanTouch=false end end
	local tracks:{[string]:AnimationTrack}={}; local animator=model:FindFirstChildWhichIsA("Animator",true)
	if animator then for key,definition in Config.Animations do if definition.Id~="" and definition.Id~="rbxassetid://0" then local animation=Instance.new("Animation"); animation.AnimationId=definition.Id; local track=animator:LoadAnimation(animation); animation:Destroy(); track.Looped=definition.Looped; tracks[key]=track end end end
	local creature:Creature={Model=model,Root=root,Room=room,Health=Config.MaxHealth,MaxHealth=Config.MaxHealth,Dead=false,State="Idle",NextAttack=0,JumpStart=0,StartPosition=Vector3.zero,TargetPosition=Vector3.zero,HitPlayers={},Tracks=tracks,Random=Random.new(room.Seed+room.Index*1543)}
	self.Creatures[model]=creature; model:SetAttribute("EntityId","Hert"); model:SetAttribute("Health",creature.Health); model:SetAttribute("MaxHealth",creature.MaxHealth); model:SetAttribute("RoomIndex",room.Index); play(creature,Config.IdleAnimation)
	return creature
end
function Service._spawnRoom(self:any,room:any)
	if not Config.Enabled then return end
	local templates=ServerStorage:FindFirstChild("EntityTemplates"); local source=if templates then templates:FindFirstChild(Config.TemplateName) else nil
	if not source or not source:IsA("Model") then warn("[CreatureService] ServerStorage.EntityTemplates.Hert Model is missing; Hert spawns skipped"); return end
	local run=self.RunManager:GetState(); if not run then return end
	local foundSpawns=0
	local used:{[Instance]:boolean}={}
	for _,marker in room.Model:GetDescendants() do
		if marker:GetAttribute("EntityId")~="Hert" then continue end
		local spawnAttachment:Attachment?=nil
		local spawnPart:BasePart?=nil
		if marker:IsA("Attachment") then
			spawnAttachment=marker
		elseif marker:IsA("BasePart") then
			spawnPart=marker
			local child=marker:FindFirstChild("Spawn")
			if child and child:IsA("Attachment") then spawnAttachment=child end
		else
			local child=marker:FindFirstChild("Spawn",true)
			if child and child:IsA("Attachment") then spawnAttachment=child end
		end
		local spawnKey:Instance?=spawnAttachment or spawnPart
		if not spawnKey or used[spawnKey] then continue end
		used[spawnKey]=true; foundSpawns+=1
		local indexValue=marker:GetAttribute("SpawnIndex")
		if indexValue==nil then indexValue=spawnKey:GetAttribute("SpawnIndex") end
		local index=if typeof(indexValue)=="number" then math.floor(indexValue) else foundSpawns
		local chanceValue=marker:GetAttribute("SpawnChance")
		if chanceValue==nil then chanceValue=spawnKey:GetAttribute("SpawnChance") end
		local chance=if typeof(chanceValue)=="number" then chanceValue else Config.SpawnChance
		-- Accept either 0..1 probability or the commonly authored 0..100 percent.
		if chance>1 then chance/=100 end
		chance=math.clamp(chance,0,1)
		local seed=(run.Seed*1103515245+room.Index*7919+index*104729)%2147483647
		local roll=Random.new(seed):NextNumber()
		if Config.Debug then print(`[CreatureService] room {room.Index} Hert spawn {index}: roll={roll}, chance={chance}`) end
		if Config.ForceSpawn or roll<=chance then
			local model=source:Clone(); model.Name=`Hert_{room.Index}_{index}`; model.Parent=room.Model
			model:PivotTo(if spawnAttachment then spawnAttachment.WorldCFrame else (spawnPart :: BasePart).CFrame)
			self:_register(model,room)
		end
	end
	if Config.Debug and foundSpawns==0 then warn(`[CreatureService] room {room.Index} has no Hert spawn marker with EntityId="Hert"`) end
end
function Service._removeRoom(self:any,room:any) for model,creature in self.Creatures do if creature.Room==room then self.Creatures[model]=nil; if model.Parent then model:Destroy() end end end end
function Service._resolve(self:any,instance:Instance):Creature?
	local cursor:Instance?=instance; while cursor do if cursor:IsA("Model") then local found=self.Creatures[cursor]; if found then return found end end; cursor=cursor.Parent end; return nil
end
function Service.IsDamageable(self:any,instance:Instance):boolean local c=self:_resolve(instance); return c~=nil and not (c :: Creature).Dead end
function Service.Damage(self:any,instance:Instance,amount:number,sourcePlayer:Player?):boolean
	if amount<=0 or amount~=amount then return false end; local c=self:_resolve(instance); if not c or c.Dead then return false end
	c.Health=math.max(0,c.Health-amount); c.Model:SetAttribute("Health",c.Health); c.Model:SetAttribute("LastDamageAmount",amount); c.Model:SetAttribute("LastDamagedAt",workspace:GetServerTimeNow())
	if Config.Debug then print(`[CreatureService] Hert in room {c.Room.Index} took {amount} damage from {if sourcePlayer then sourcePlayer.Name else "unknown"}; health={c.Health}/{c.MaxHealth}`) end
	if c.Health<=0 then c.Dead=true; c.State="Dead"; play(c,Config.DeathAnimation); c.Model:SetAttribute("Dead",true); task.delay(2,function() if c.Model.Parent then c.Model:Destroy() end; self.Creatures[c.Model]=nil end) end
	return true
end
function Service._visible(self:any,c:Creature,targetRoot:BasePart,character:Model):boolean
	if not Config.RequireLineOfSight then return true end
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={c.Model}; local result=workspace:Raycast(c.Root.Position,targetRoot.Position-c.Root.Position,params)
	return result==nil or result.Instance:IsDescendantOf(character)
end
function Service._target(self:any,c:Creature):(Player?,BasePart?)
	local best:Player?=nil; local bestRoot:BasePart?=nil; local distance=Config.DetectionRange
	for _,player in Players:GetPlayers() do if self.Tracker:GetPlayerRoom(player)==c.Room.Index then local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil; local root=if character then character:FindFirstChild("HumanoidRootPart") else nil
			if character and humanoid and humanoid.Health>0 and root and root:IsA("BasePart") then local d=(root.Position-c.Root.Position).Magnitude; if d<=distance and self:_visible(c,root,character) then best=player; bestRoot=root; distance=d end end end end
	return best,bestRoot
end
function Service._step(self:any,now:number)
	for _,c in self.Creatures do if c.Dead or not c.Model.Parent then continue end
		if c.Room.State~="Active" then continue end
		if c.State=="Jumping" then local alpha=math.clamp((now-c.JumpStart)/Config.JumpDuration,0,1); local position=c.StartPosition:Lerp(c.TargetPosition,alpha)+Vector3.new(0,4*Config.JumpHeight*alpha*(1-alpha),0); c.Model:PivotTo(CFrame.new(position)*c.Model:GetPivot().Rotation)
			for _,player in Players:GetPlayers() do if not c.HitPlayers[player] and self.Tracker:GetPlayerRoom(player)==c.Room.Index then local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil; local root=if character then character:FindFirstChild("HumanoidRootPart") else nil; if humanoid and root and root:IsA("BasePart") and humanoid.Health>0 and (root.Position-position).Magnitude<=Config.HitRadius then c.HitPlayers[player]=true; humanoid:TakeDamage(Config.Damage) end end end
			if alpha>=1 then c.State="Idle"; c.NextAttack=now+c.Random:NextNumber(Config.MinimumAttackCooldown,Config.MaximumAttackCooldown); play(c,Config.IdleAnimation) end
		elseif now>=c.NextAttack then local _,root=self:_target(c); if root then c.State="Jumping"; c.JumpStart=now; c.StartPosition=c.Root.Position; c.TargetPosition=root.Position; table.clear(c.HitPlayers); play(c,Config.AttackAnimation) end end
	end end
function Service.Start(self:any)
	self.Lifecycle:Subscribe("Loaded",function(room:any) self:_spawnRoom(room) end); self.Lifecycle:Subscribe("Unloading",function(room:any) self:_removeRoom(room) end)
	self.Connection=RunService.Heartbeat:Connect(function() self:_step(workspace:GetServerTimeNow()) end)
end
return Service
