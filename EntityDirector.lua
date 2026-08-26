--!strict
-- ModuleScript: ServerScriptService/Services/EntityDirector
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config:any=require(ReplicatedStorage.Shared.EntityConfig)
-- Resolve through WaitForChild so Studio does not depend on a stale inferred
-- type for the Services Folder while files are being synchronized.
local pathUtilModule=script.Parent:WaitForChild("EntityPathUtil")
assert(pathUtilModule:IsA("ModuleScript"),"ServerScriptService.Services.EntityPathUtil must be a ModuleScript")
local PathUtil:any=require(pathUtilModule)
local D={}; D.__index=D
type Node={Position:Vector3,RoomIndex:number}
type Active={Id:string,Model:Model,Nodes:{Node},Segment:number,Offset:number,Speed:number,Pins:{number},Crossed:{[number]:boolean}}
local function hash(seed:number,index:number,id:string):number local value=(seed*48271+index*69621)%2147483647; for i=1,#id do value=(value*31+string.byte(id,i))%2147483647 end; return math.max(1,value) end
local function ensureDebugTemplate()
	if not Config.Debug.CreatePlaceholderTemplate then return end
	local folderValue=ServerStorage:FindFirstChild("EntityTemplates")
	if folderValue and not folderValue:IsA("Folder") then warn("[EntityDirector] ServerStorage.EntityTemplates must be a Folder"); return end
	local folder:Folder
	if folderValue then folder=folderValue else folder=Instance.new("Folder"); folder.Name="EntityTemplates"; folder.Parent=ServerStorage end
	if folder:FindFirstChild("HallwayRush") then return end
	local model=Instance.new("Model"); model.Name="HallwayRush"
	local root=Instance.new("Part"); root.Name="Root"; root.Shape=Enum.PartType.Ball; root.Size=Vector3.new(4,4,4); root.Material=Enum.Material.Neon; root.Color=Color3.fromRGB(225,35,35); root.Transparency=.15; root.Anchored=true; root.CanCollide=false; root.CanTouch=false; root.CastShadow=false; root.Parent=model
	local light=Instance.new("PointLight"); light.Color=root.Color; light.Brightness=2; light.Range=18; light.Parent=root
	model.PrimaryPart=root; model.Parent=folder; warn("[EntityDirector] created DEBUG HallwayRush placeholder; replace it with your original model before publishing")
end
function D.new(lifecycle:any,runManager:any,tracker:any,hiding:any,retention:any,event:RemoteEvent):any
	local behind=0
	for _,definition:any in Config.Entities do
		-- Room-bound creatures have their own service and do not satisfy the
		-- multi-room Hallway director contract.
		if definition.Director=="Hallway" then
			behind=math.max(behind,definition.SpawnBehindRooms)
		end
	end
	retention:SetBehind(behind)
	return setmetatable({Lifecycle=lifecycle,RunManager=runManager,Tracker=tracker,Hiding=hiding,Retention=retention,Event=event,Evaluated={} :: {[number]:boolean},Active={} :: {Active},Pending={} :: {[string]:number},LastSpawn={} :: {[string]:number},Connection=nil :: RBXScriptConnection?},D)
end
function D._killRoom(self:any,active:Active,index:number) if active.Crossed[index] then return end; active.Crossed[index]=true; for _,player in Players:GetPlayers() do if self.Tracker:GetPlayerRoom(player)==index and not self.Hiding:IsHidden(player) then local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil; if humanoid and humanoid.Health>0 then humanoid.Health=0 end end end end
function D._finish(self:any,position:number) local active=self.Active[position]; if not active then return end; active.Model:Destroy(); for _,index in active.Pins do self.Retention:Release(index) end; table.remove(self.Active,position) end
function D._step(self:any,dt:number)
	for position=#self.Active,1,-1 do local active=self.Active[position]; local remaining=active.Speed*dt
		while remaining>0 do local current=active.Nodes[active.Segment]; local following=active.Nodes[active.Segment+1]; if not current or not following then self:_finish(position); break end; self:_killRoom(active,current.RoomIndex); local delta=following.Position-current.Position; local length=delta.Magnitude; local available=length-active.Offset; if remaining>=available then remaining-=available; active.Segment+=1; active.Offset=0 else active.Offset+=remaining; remaining=0 end; local now=active.Nodes[active.Segment]; local nextNode=active.Nodes[active.Segment+1]; if now and nextNode and active.Model.Parent then local direction=nextNode.Position-now.Position; local location=now.Position+(if direction.Magnitude>0 then direction.Unit*active.Offset else Vector3.zero); active.Model:PivotTo(if direction.Magnitude>0 then CFrame.lookAt(location,nextNode.Position) else CFrame.new(location)) end end
	end
end
function D._start(self:any,id:string,trigger:number,definition:any,first:number,last:number)
	self.Pending[id]=math.max(0,(self.Pending[id] or 1)-1)
	local run=self.RunManager:GetState(); if not run then return end; local templates=ServerStorage:FindFirstChild("EntityTemplates"); local template=if templates then templates:FindFirstChild(definition.TemplateName) else nil; if not template or not template:IsA("Model") then warn(`[EntityDirector] Missing ServerStorage.EntityTemplates.{definition.TemplateName}`); return end
	local nodes:{Node}={}; local pins:{number}={}; for index=first,last do local room=run.ActiveRooms[index]; if not room then warn(`[EntityDirector] cancelled {id}: required room {index} is unavailable`); return end; local points=PathUtil.RoomPoints(room); if not points then warn(`[EntityDirector] cancelled {id}: room {index} has no valid entity path`); return end; for _,point in points do table.insert(nodes,{Position=point,RoomIndex=index}) end; table.insert(pins,index) end
	local clone=template:Clone(); local root=clone:FindFirstChild("Root",true); if not root or not root:IsA("BasePart") then clone:Destroy(); warn(`[EntityDirector] {template:GetFullName()} requires Root BasePart`); return end; clone.PrimaryPart=root; for _,value in clone:GetDescendants() do if value:IsA("LuaSourceContainer") then value:Destroy() elseif value:IsA("BasePart") then value.Anchored=true; value.CanCollide=false; value.CanTouch=false end end; local runtime=workspace:FindFirstChild("RuntimeEntities"); clone.Parent=runtime or workspace; clone:PivotTo(CFrame.new(nodes[1].Position)); for _,index in pins do self.Retention:Pin(index) end; table.insert(self.Active,{Id=id,Model=clone,Nodes=nodes,Segment=1,Offset=0,Speed=definition.TravelSpeed,Pins=pins,Crossed={}}); self.LastSpawn[id]=trigger
end
function D.Evaluate(self:any,room:any)
	local index=room.Index; if self.Evaluated[index] then return end; self.Evaluated[index]=true; local run=self.RunManager:GetState(); if not run then return end
	for id,definition:any in Config.Entities do
		if definition.Director~="Hallway" then continue end
		if not definition.Enabled or (not Config.Debug.IgnoreMinimumTriggerRoom and index<definition.MinimumTriggerRoom) or room.Model:GetAttribute("AllowsEntities")==false or (not Config.Debug.IgnoreCooldown and index-(self.LastSpawn[id] or -math.huge)<definition.CooldownRooms) then continue end
		local concurrent=self.Pending[id] or 0; for _,active in self.Active do if active.Id==id then concurrent+=1 end end; if concurrent>=definition.MaximumConcurrent then continue end
		local first=index-definition.SpawnBehindRooms; local last=index+definition.PassAheadRooms; local valid=true; for routeIndex=first,last do if not run.ActiveRooms[routeIndex] then valid=false; break end end
		if not valid then if definition.Debug or Config.Debug.PrintDecisions then warn(`[EntityDirector] {id} route {first}-{last} unavailable at trigger room {index}`) end; continue end
		if not Config.Debug.IgnoreLockerRequirement and definition.RequireAvailableLocker and self.Hiding:AvailableInRooms(index,index)<definition.MinimumAvailableLockers then if Config.Debug.PrintDecisions then warn(`[EntityDirector] {id} rejected at room {index}: not enough available lockers`) end; continue end
		local templates=ServerStorage:FindFirstChild("EntityTemplates"); if not templates or not templates:FindFirstChild(definition.TemplateName) then warn(`[EntityDirector] missing template for {id}`); continue end
		local spawnRoll=Random.new(hash(run.Seed,index,id)):NextNumber(); if Config.Debug.PrintDecisions then print(`[EntityDirector] {id} room={index} roll={spawnRoll} chance={definition.SpawnChance}`) end; if not Config.Debug.ForceSpawn and spawnRoll>definition.SpawnChance then continue end
		self.Pending[id]=(self.Pending[id] or 0)+1; local startTime=workspace:GetServerTimeNow(); local travelTime=startTime+definition.WarningDuration; self.Event:FireAllClients({EntityId=id,TriggerRoomIndex=index,WarningStartTime=startTime,TravelStartTime=travelTime,AffectedRoomRange={first,last},WarningSoundId=definition.WarningSoundId,TravelSoundId=definition.TravelSoundId}); task.delay(definition.WarningDuration,function() if self.RunManager:GetState()==run then self:_start(id,index,definition,first,last) else self.Pending[id]=math.max(0,(self.Pending[id] or 1)-1) end end)
	end
end
function D.UnloadRoom(self:any,room:any) for position=#self.Active,1,-1 do local active=self.Active[position]; if table.find(active.Pins,room.Index) then self:_finish(position) end end end
function D.Start(self:any) ensureDebugTemplate(); self.Connection=RunService.Heartbeat:Connect(function(dt) self:_step(dt) end); self.Lifecycle:Subscribe("PlayerEntered",function(room) self:Evaluate(room) end); self.Lifecycle:Subscribe("Unloading",function(room) self:UnloadRoom(room) end) end
function D.Stop(self:any) if self.Connection then self.Connection:Disconnect(); self.Connection=nil end; for i=#self.Active,1,-1 do self:_finish(i) end; table.clear(self.Evaluated); table.clear(self.Pending); self.Retention:Clear() end
return D
