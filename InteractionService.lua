--!strict
-- ModuleScript: ServerScriptService/Services/InteractionService
local Players=game:GetService("Players"); local CollectionService=game:GetService("CollectionService"); local ProximityPromptService=game:GetService("ProximityPromptService"); local RS=game:GetService("ReplicatedStorage")
local Config:any=require(RS:WaitForChild("Shared"):WaitForChild("InteractionConfig")); local S={}; S.__index=S
function S.new(states:any,noise:any,remote:RemoteEvent):any return setmetatable({States=states,Noise=noise,Remote=remote,Rooms={} :: {[number]:boolean},Active={},Reserved={},Cooldowns={},Buckets={},Handlers={},SpecialHandlers={}},S) end
function S.RegisterHandler(self:any,id:string,callback:(Player,Instance)->()) assert(Config.Definitions[id],"handler must use configured InteractionId"); self.Handlers[id]=callback end
function S.RegisterSpecialHandler(self:any,id:string,callback:(Player,Instance)->()) assert(Config.Definitions[id],"special handler must use configured InteractionId"); self.SpecialHandlers[id]=callback end
function S.RegisterRoom(self:any,room:any)
	local indexValue=room.Index or room.Model:GetAttribute("RoomIndex")
	if typeof(indexValue)~="number" then warn("[InteractionService] cannot register a room without a numeric RoomIndex"); return end
	local index:number=indexValue
	self.Rooms[index]=room.State=="Active"
	for _,value in room.Model:GetDescendants() do
		local idValue=value:GetAttribute("InteractionId")
		if typeof(idValue)=="string" then
			local interactionId:string=idValue
			if value:GetAttribute("RoomIndex")==nil then value:SetAttribute("RoomIndex",index) end
			CollectionService:AddTag(value,"Interactable")
		end
	end
end
function S.SetRoomActive(self:any,index:number,active:boolean) self.Rooms[index]=active; if not active then self:CancelRoom(index,"RoomInactive") end end
function S.UnregisterRoom(self:any,index:number) self:CancelRoom(index,"RoomUnloaded"); self.Rooms[index]=nil end
function S._reject(self:any,p:Player,reason:string) if Config.Debug then warn(`[InteractionService] rejected {p.Name}: {reason}`) end; self.Remote:FireClient(p,{kind="Rejected",reason=reason}) end
function S._rate(self:any,p:Player):boolean local now=os.clock(); local b=self.Buckets[p] or {tokens=Config.RequestBurst,time=now}; b.tokens=math.min(Config.RequestBurst,b.tokens+(now-b.time)*Config.RequestRefillPerSecond); b.time=now; if b.tokens<1 then self.Buckets[p]=b; return false end; b.tokens-=1; self.Buckets[p]=b; return true end
function S._point(self:any,target:Instance):Vector3? if target:IsA("BasePart") then return target.Position end; local a=target:FindFirstChild("InteractionPoint",true); if a and a:IsA("Attachment") then return a.WorldPosition end; local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true); local promptParent=if prompt then prompt.Parent else nil; if promptParent and promptParent:IsA("Attachment") then return promptParent.WorldPosition end; if promptParent and promptParent:IsA("BasePart") then return promptParent.Position end; if target:IsA("Model") then return target:GetPivot().Position end; return nil end
function S._request(self:any,player:Player,targetValue:any,requested:any,clientInputTime:any?)
	local serverReceived=workspace:GetServerTimeNow()
	if not self:_rate(player) then self:_reject(player,"RateLimited"); return end
	-- Narrow the untrusted RemoteEvent value before calling any Instance methods.
	-- Keeping typeof() and method calls in separate statements avoids a Studio
	-- analyzer limitation around short-circuit unions containing `any`.
	if typeof(targetValue)~="Instance" then self:_reject(player,"InvalidTarget"); return end
	local target:Instance=targetValue :: Instance
	if not target:IsDescendantOf(workspace) or not CollectionService:HasTag(target,"Interactable") then self:_reject(player,"InvalidTarget"); return end
	local id=target:GetAttribute("InteractionId")
	if typeof(id)~="string" or requested~=id or not Config.Definitions[id] then self:_reject(player,"InvalidInteraction"); return end
	if target:GetAttribute("Enabled")==false then self:_reject(player,"Disabled"); return end
	if Config.TimingDebug then local hold=target:GetAttribute("HoldDuration"); if typeof(hold)=="number" and hold>0 then warn(`[InteractionTiming] {id} target={target:GetFullName()} has HoldDuration={hold}`) end end
	local specialHandlers:{[string]:(Player,Instance)->()}=self.SpecialHandlers
	local special:((Player,Instance)->())?=specialHandlers[id]
	if special~=nil then if Config.TimingDebug then print(`[InteractionTiming] {id} input={if typeof(clientInputTime)=="number" then serverReceived-clientInputTime else -1} serverReceived={serverReceived}`) end; special(player,target); return end
	local room=target:GetAttribute("RoomIndex"); if typeof(room)=="number" and self.Rooms[room]~=true then self:_reject(player,"RoomInactive"); return end; if not self.States:CanBegin(player) then self:_reject(player,"Busy"); return end; local character=player.Character; local root=if character then character:FindFirstChild("HumanoidRootPart") else nil; local head=if character then character:FindFirstChild("Head") else nil; local point=self:_point(target); if not root or not root:IsA("BasePart") or not point then self:_reject(player,"NoCharacter"); return end; local rawMax=target:GetAttribute("MaxDistance"); local requestedMax=if typeof(rawMax)=="number" then rawMax else Config.DefaultDistance; local max=math.min(requestedMax,Config.MaxServerDistance); if (root.Position-point).Magnitude>max then self:_reject(player,"TooFar"); return end; if target:GetAttribute("RequiresLineOfSight")~=false then local origin=if head and head:IsA("BasePart") then head.Position else root.Position; local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character :: Model}; local hit=workspace:Raycast(origin,point-origin,params); if hit and not hit.Instance:IsDescendantOf(target) and not target:IsDescendantOf(hit.Instance) then self:_reject(player,"Blocked"); return end end; if target:GetAttribute("Exclusive") and self.Reserved[target] then self:_reject(player,"Reserved"); return end; local now=workspace:GetServerTimeNow(); if now<(self.Cooldowns[target] or 0) then self:_reject(player,"Cooldown"); return end; local def=Config.Definitions[id]; local token,err=self.States:Acquire(player,"Interacting",def.Locks); if not token then self:_reject(player,err or "Busy"); return end; self.Reserved[target]=player; self.Active[player]={token=token,target=target,room=room}; local cameraPoint=if def.UseTargetCamera==false then nil else target:FindFirstChild("CameraPoint",true); local approvalTime=workspace:GetServerTimeNow(); self.Remote:FireClient(player,{kind="Started",token=token,animationKey=def.AnimationKey,duration=def.Duration,cameraPoint=cameraPoint,startTime=approvalTime}); if Config.TimingDebug then print(`[InteractionTiming] {id} input={if typeof(clientInputTime)=="number" then serverReceived-clientInputTime else -1} serverReceived={serverReceived} approved={approvalTime} hold={target:GetAttribute("HoldDuration")} cooldown={target:GetAttribute("Cooldown")} enabled={target:GetAttribute("Enabled")} mode={target:GetAttribute("ObjectMotionMode")} drawerTween={target:GetAttribute("DrawerTweenTime")}`) end; task.delay(def.CommitTime,function() local a=self.Active[player]; if not a or a.token~=token or not target.Parent or not self.States:IsAlive(player) then return end; local handler=self.Handlers[id]; if handler then local ok,e=pcall(handler,player,target); if not ok then warn("[InteractionService] ",e) end end; self.Noise:EmitInteraction(player,point,def.NoiseRadius,room) end); task.delay(def.Duration,function() self:_finish(player,token,"Completed") end)
end
function S._finish(self:any,p:Player,token:string,reason:string) local a=self.Active[p]; if not a or a.token~=token then return end; self.Active[p]=nil; if self.Reserved[a.target]==p then self.Reserved[a.target]=nil end; local cooldown=a.target:GetAttribute("Cooldown"); self.Cooldowns[a.target]=workspace:GetServerTimeNow()+(if typeof(cooldown)=="number" then cooldown else 0); self.States:Release(p,token); self.Remote:FireClient(p,{kind=reason,token=token}) end
function S.CancelPlayer(self:any,p:Player,reason:string) local a=self.Active[p]; if a then self:_finish(p,a.token,"Cancelled"); self:_reject(p,reason) end end
function S.CancelRoom(self:any,index:number,reason:string) for p,a in self.Active do if a.room==index then self:CancelPlayer(p,reason) end end end
function S.Start(self:any,request:RemoteEvent)
	request.OnServerEvent:Connect(function(player,target,id,clientInputTime) self:_request(player,target,id,clientInputTime) end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt:ProximityPrompt,player:Player)
		local cursor:Instance?=prompt.Parent
		while cursor and cursor~=workspace do
			local id=cursor:GetAttribute("InteractionId")
			if typeof(id)=="string" then
				local roomCursor:Instance?=cursor
				while roomCursor and roomCursor~=workspace do
					local roomIndex=roomCursor:GetAttribute("RoomIndex")
					if typeof(roomIndex)=="number" then cursor:SetAttribute("RoomIndex",roomIndex); break end
					roomCursor=roomCursor.Parent
				end
				if not CollectionService:HasTag(cursor,"Interactable") then CollectionService:AddTag(cursor,"Interactable") end
				if Config.Debug then print(`[InteractionService] prompt {prompt:GetFullName()} requested {id} by {player.Name}`) end
				self:_request(player,cursor,id); return
			end
			cursor=cursor.Parent
		end
		if Config.Debug then warn(`[InteractionService] prompt {prompt:GetFullName()} has no ancestor with InteractionId`) end
	end)
	Players.PlayerRemoving:Connect(function(player) self:CancelPlayer(player,"Leaving"); self.Buckets[player]=nil end)
end
return S
