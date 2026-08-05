--!strict
-- ModuleScript: ServerScriptService/Services/HidingService
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config:any=require(ReplicatedStorage.Shared.HidingConfig)
local S={}; S.__index=S
type Record={Locker:Instance,RoomIndex:number,Root:BasePart,WasAnchored:boolean,Token:string,Generation:number,Phase:string}
local function attachment(target:Instance,name:string):Attachment? local value=target:FindFirstChild(name,true); if value and value:IsA("Attachment") then return value end; return nil end
local function pointCFrame(target:Instance,name:string):CFrame? local value=target:FindFirstChild(name,true); if value and value:IsA("Attachment") then return value.WorldCFrame elseif value and value:IsA("BasePart") then return value.CFrame end; return nil end
function S.new(states:any,tracker:any,remote:RemoteEvent,objectAnimation:any?):any return setmetatable({States=states,Tracker=tracker,Remote=remote,ObjectAnimation=objectAnimation,Lockers={} :: {[Instance]:number},Occupants={} :: {[Instance]:Player},Records={} :: {[Player]:Record},Rates={} :: {[Player]:number},Generation={} :: {[Player]:number}},S) end
function S.IsHidden(self:any,player:Player):boolean local record:Record?=self.Records[player]; return record~=nil and record.Phase=="Hidden" end
function S.GetLocker(self:any,player:Player):Instance? local record:Record?=self.Records[player]; return if record then record.Locker else nil end
function S.IsLockerOccupied(self:any,locker:Instance):boolean return self.Occupants[locker]~=nil end
function S.AvailableInRooms(self:any,first:number,last:number):number local count=0; for locker,index in self.Lockers do if index>=first and index<=last and locker.Parent and locker:GetAttribute("Enabled")~=false and not self.Occupants[locker] then count+=1 end end; return count end
function S.RegisterRoom(self:any,room:any) for _,value in room.Model:GetDescendants() do if value:GetAttribute("InteractionId")=="Locker" then self.Lockers[value]=room.Index; value:SetAttribute("Occupied",false) end end end
function S._cleanup(self:any,player:Player,reason:string)
	self.Generation[player]=(self.Generation[player] or 0)+1; local record:Record?=self.Records[player]; if not record then return end
	self.Records[player]=nil; if self.Occupants[record.Locker]==player then self.Occupants[record.Locker]=nil; if record.Locker.Parent then record.Locker:SetAttribute("Occupied",false); record.Locker:SetAttribute("InteractionText","Hide") end end
	if record.Root.Parent then record.Root.AssemblyLinearVelocity=Vector3.zero; record.Root.AssemblyAngularVelocity=Vector3.zero; record.Root.Anchored=record.WasAnchored; if not record.Root.Anchored then record.Root:SetNetworkOwnershipAuto() end end
	self.States:Release(player,record.Token); self.Remote:FireClient(player,{Kind="Exited",Reason=reason})
end
function S.UnregisterRoom(self:any,room:any) for player,record in self.Records do if record.RoomIndex==room.Index then self:_cleanup(player,"RoomUnloaded") end end; for locker,index in self.Lockers do if index==room.Index then self.Lockers[locker]=nil; self.Occupants[locker]=nil end end end
function S.Enter(self:any,player:Player,locker:Instance)
	local now=workspace:GetServerTimeNow(); if now<(self.Rates[player] or 0) then return end; self.Rates[player]=now+Config.RequestCooldown
	local roomIndex=self.Lockers[locker]; if roomIndex==nil or not locker:IsA("Model") or not locker:IsDescendantOf(workspace) or locker:GetAttribute("Enabled")==false or self.Occupants[locker] or self.Records[player] or self.Tracker:GetPlayerRoom(player)~=roomIndex or not self.States:IsAlive(player) then return end
	local character=player.Character; if not character then return end
	local rootValue=character:FindFirstChild("HumanoidRootPart"); local humanoid=character:FindFirstChildOfClass("Humanoid"); local hidden=attachment(locker,"HiddenPoint"); local exitPoint=attachment(locker,"ExitPoint"); if not rootValue or not rootValue:IsA("BasePart") or not humanoid or not hidden or not exitPoint then warn(`[HidingService] {locker:GetFullName()} requires HiddenPoint and ExitPoint Attachments`); return end
	local interaction=attachment(locker,"InteractionPoint"); local point=if interaction then interaction.WorldPosition else locker:GetPivot().Position; local rawMax=locker:GetAttribute("MaxDistance"); local maxDistance=math.min(if typeof(rawMax)=="number" then rawMax else Config.MaximumDistance,Config.MaximumDistance); if (rootValue.Position-point).Magnitude>maxDistance then return end
	if locker:GetAttribute("RequiresLineOfSight")~=false then local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character}; local hit=workspace:Raycast(rootValue.Position,point-rootValue.Position,params); if hit and not hit.Instance:IsDescendantOf(locker) then return end end
	local token=self.States:Acquire(player,"Hiding",Config.Locks); if not token then return end
	local generation=(self.Generation[player] or 0)+1; self.Generation[player]=generation; self.Occupants[locker]=player; locker:SetAttribute("Occupied",true); locker:SetAttribute("InteractionText","Occupied")
	if Config.UnequipToolsOnEnter then humanoid:UnequipTools() end
	local wasAnchored=rootValue.Anchored; self.Records[player]={Locker=locker,RoomIndex=roomIndex,Root=rootValue,WasAnchored=wasAnchored,Token=token,Generation=generation,Phase="Entering"}
	local startCFrame=pointCFrame(locker,"Start")
	if startCFrame then rootValue.AssemblyLinearVelocity=Vector3.zero; rootValue.AssemblyAngularVelocity=Vector3.zero; rootValue.CFrame=startCFrame; rootValue.Anchored=true end
	if self.ObjectAnimation then self.ObjectAnimation.Play(locker,"LockerEnterObject",0) end
	local camera=attachment(locker,"CameraPoint"); local startTime=workspace:GetServerTimeNow(); self.Remote:FireClient(player,{Kind="Entering",Locker=locker,ServerStartTime=startTime,EnterDuration=Config.EnterDuration,EnterCommitTime=Config.EnterCommitTime,CameraCFrame=if camera then camera.WorldCFrame else hidden.WorldCFrame,Fov=Config.CameraFov})
	task.delay(Config.EnterCommitTime,function()
		local record:Record?=self.Records[player]; if not record or record.Generation~=generation or record.Phase~="Entering" or not locker.Parent or humanoid.Health<=0 then self:_cleanup(player,"EnterCancelled"); return end
		local currentHidden=attachment(locker,"HiddenPoint"); if not currentHidden or not rootValue.Parent then self:_cleanup(player,"EnterCancelled"); return end
		rootValue.AssemblyLinearVelocity=Vector3.zero; rootValue.AssemblyAngularVelocity=Vector3.zero; rootValue.CFrame=currentHidden.WorldCFrame; rootValue.Anchored=Config.AnchorRootWhileHidden==true; record.Phase="Hidden"
		local currentCamera=attachment(locker,"CameraPoint"); self.Remote:FireClient(player,{Kind="Hidden",ServerStartTime=workspace:GetServerTimeNow(),CameraCFrame=if currentCamera then currentCamera.WorldCFrame else currentHidden.WorldCFrame,Fov=Config.CameraFov})
	end)
	task.delay(Config.EnterDuration,function() local record:Record?=self.Records[player]; if record and record.Generation==generation and record.Phase=="Entering" then self:_cleanup(player,"EnterCancelled") end end)
end
function S.Exit(self:any,player:Player)
	local now=workspace:GetServerTimeNow(); if now<(self.Rates[player] or 0) then return end; self.Rates[player]=now+Config.RequestCooldown; local record:Record?=self.Records[player]; if not record or record.Phase~="Hidden" then return end; record.Phase="Exiting"; record.Generation+=1; local generation=record.Generation; local startTime=workspace:GetServerTimeNow()
	if self.ObjectAnimation then self.ObjectAnimation.Play(record.Locker,"LockerExitObject",0) end
	self.Remote:FireClient(player,{Kind="Exiting",ServerStartTime=startTime,ExitDuration=Config.ExitDuration,ExitCommitTime=Config.ExitCommitTime}); task.delay(Config.ExitCommitTime,function() local current:Record?=self.Records[player]; if not current or current.Generation~=generation or current.Phase~="Exiting" then return end; local exitPoint=attachment(current.Locker,"ExitPoint"); if exitPoint and current.Root.Parent then current.Root.CFrame=exitPoint.WorldCFrame; current.Root.AssemblyLinearVelocity=Vector3.zero; current.Root.AssemblyAngularVelocity=Vector3.zero; current.Root.Anchored=current.WasAnchored; if not current.Root.Anchored then current.Root:SetNetworkOwnershipAuto() end end; self:_cleanup(player,"Exited") end)
end
function S.Start(self:any,request:RemoteEvent)
	request.OnServerEvent:Connect(function(player:Player,action:unknown,target:unknown) if action=="Exit" then self:Exit(player) elseif action=="Enter" and typeof(target)=="Instance" then self:Enter(player,target :: Instance) end end)
	Players.PlayerRemoving:Connect(function(player) self:_cleanup(player,"Leaving"); self.Rates[player]=nil end)
	local function bind(player:Player) local function characterAdded(character:Model) local humanoid=character:WaitForChild("Humanoid",10); if humanoid and humanoid:IsA("Humanoid") then humanoid.Died:Connect(function() self:_cleanup(player,"Died") end) end end; player.CharacterRemoving:Connect(function() self:_cleanup(player,"CharacterRemoved") end); player.CharacterAdded:Connect(characterAdded); if player.Character then task.spawn(characterAdded,player.Character) end end
	Players.PlayerAdded:Connect(bind); for _,player in Players:GetPlayers() do bind(player) end
end
return S
