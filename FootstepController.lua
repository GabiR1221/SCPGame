--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/FootstepController
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ContentProvider=game:GetService("ContentProvider")
local SoundService=game:GetService("SoundService")
local RunService=game:GetService("RunService")
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("FootstepConfig"))
local LocalPlayer=Players.LocalPlayer :: Player
local Controller={}; Controller.__index=Controller

type Pool={Sounds:{Sound},Next:number,Ready:boolean}

local function validId(id:string):boolean return id~="" and id~="rbxassetid://0" end

function Controller.new():any
	return setmetatable({Characters={} :: {[Model]:{RBXScriptConnection}},SoundCache={} :: {[string]:Pool},
		RaycastParams={} :: {[Model]:RaycastParams},LastStep={} :: {[Model]:number},LastMarker={} :: {[Model]:number},
		NextFallback={} :: {[Model]:number},FallbackAccumulator=0,ObservedTracks=setmetatable({}, {__mode="k"})},Controller)
end

function Controller._playId(self:any,parent:BasePart,id:string,volume:number,pitch:number):boolean
	local pool:Pool?=self.SoundCache[id]; if pool==nil then return false end
	local sounds=pool.Sounds
	if #sounds==0 then return false end
	for offset=0,#sounds-1 do
		local slot=((pool.Next+offset-1)%#sounds)+1; local sound=sounds[slot]
		if sound.IsLoaded then
			pool.Next=(slot%#sounds)+1; sound:Stop(); sound.TimePosition=0; sound.Parent=parent
			sound.Volume=Config.Volume*volume; sound.PlaybackSpeed=Random.new():NextNumber(Config.PitchMin,Config.PitchMax)*pitch; sound:Play(); return true
		end
	end
	return false
end

function Controller._tryList(self:any,parent:BasePart,ids:{string},volume:number,pitch:number):(boolean,string,boolean)
	if #ids==0 then return false,"",false end
	local start=math.random(1,#ids); local anyLoaded=false
	for offset=0,#ids-1 do local id=ids[((start+offset-1)%#ids)+1]; if validId(id) then local pool:Pool?=self.SoundCache[id]; if pool then for _,sound in pool.Sounds do if sound.IsLoaded then anyLoaded=true; break end end end; if self:_playId(parent,id,volume,pitch) then return true,id,true end end end
	return false,"",anyLoaded
end

function Controller._sound(self:any,parent:BasePart,requested:{string},kind:string,volume:number,pitch:number):(boolean,string,boolean,string)
	local played,id,requestedLoaded=self:_tryList(parent,requested,volume,pitch)
	if played then return true,id,true,"exact" end
	if Config.Preloading.UseLoadedFallback then
		local fallbackProfile:any=Config.Profiles[Config.Preloading.InitialFallbackProfile]
		local fallback:{string}=if fallbackProfile then fallbackProfile[kind] or fallbackProfile.Walk else {}
		local fallbackPlayed,fallbackId=self:_tryList(parent,fallback,volume,pitch)
		if fallbackPlayed then return true,fallbackId,requestedLoaded,"DefaultFallback" end
	end
	return false,"",requestedLoaded,"skipped-unloaded"
end

function Controller._debug(_self:any,character:Model,footName:string,hit:RaycastResult?,profile:string?,id:string,loaded:boolean,result:string)
	if not Config.Debug then return end
	if hit then print(`[Footstep] character={character.Name} foot={footName} hit={hit.Instance:GetFullName()} material={hit.Material.Name} profile={profile or "none"} id={id} loaded={loaded} result={result}`)
	else print(`[Footstep] character={character.Name} foot={footName} hit=none material=none profile=none id= loaded=false result={result}`) end
end

function Controller._step(self:any,character:Model,kind:string,foot:string?)
	local now=os.clock(); if kind~="Land" and now-(self.LastStep[character] or 0)<Config.MinimumStepInterval then return end
	local root=character:FindFirstChild("HumanoidRootPart"); local humanoid=character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.FloorMaterial==Enum.Material.Air then self:_debug(character,foot or "Root",nil,nil,"",false,"skipped-air-or-character"); return end
	local localCharacter=LocalPlayer.Character; local localRoot=if localCharacter then localCharacter:FindFirstChild("HumanoidRootPart") else nil
	if character~=localCharacter and localRoot and localRoot:IsA("BasePart") and (localRoot.Position-root.Position).Magnitude>Config.MaxDistance then return end
	local speed=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
	if kind~="Land" and speed<Config.MinHorizontalSpeed then return end
	local wantedName=if foot=="Left" then "LeftFoot" elseif foot=="Right" then "RightFoot" else "HumanoidRootPart"
	local wanted=character:FindFirstChild(wantedName); local originPart:BasePart=if wanted and wanted:IsA("BasePart") then wanted else root
	local params:RaycastParams?=self.RaycastParams[character]; if params==nil then return end
	local lift:number=Config.RayOriginLift; local hit=workspace:Raycast(originPart.Position+Vector3.new(0,lift,0),Vector3.new(0,-(Config.RayLength+lift),0),params)
	if hit==nil and originPart~=root then hit=workspace:Raycast(root.Position+Vector3.new(0,lift,0),Vector3.new(0,-(Config.RayLength+lift),0),params) end
	if hit==nil then self:_debug(character,wantedName,nil,nil,"",false,"skipped-no-floor"); return end
	local cursor:Instance?=hit.Instance; local override:string?=nil
	while cursor and cursor~=workspace do local value=cursor:GetAttribute("SurfaceProfile"); if typeof(value)=="string" then override=value; break end; cursor=cursor.Parent end
	local profile=if override and Config.Profiles[override] then override else Config.MaterialProfiles[hit.Material.Name] or "Default"
	local definition:any=Config.Profiles[profile]; if definition==nil then self:_debug(character,wantedName,hit,profile,"",false,"skipped-missing-profile"); return end
	local ids:{string}=definition[kind] or definition.Walk
	local played,id,loaded,result=self:_sound(originPart,ids,kind,definition.VolumeMultiplier,definition.PitchMultiplier)
	self:_debug(character,wantedName,hit,profile,id,loaded,result)
	if not played then return end
	self.LastStep[character]=now
	if kind~="Land" then self.NextFallback[character]=now+(Config.FallbackIntervals[kind] or Config.FallbackIntervals.Walk) end
end

function Controller._observe(self:any,character:Model)
	if self.Characters[character] then return end
	local bucket:{RBXScriptConnection}={}; self.Characters[character]=bucket
	local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={character}; params.IgnoreWater=false; self.RaycastParams[character]=params
	local humanoid=character:WaitForChild("Humanoid",5); if not humanoid or not humanoid:IsA("Humanoid") then return end
	local animator=humanoid:WaitForChild("Animator",5); if not animator or not animator:IsA("Animator") then return end
	local function observeTrack(track:AnimationTrack)
		if self.ObservedTracks[track] then return end; self.ObservedTracks[track]=true
		local names=if Config.MarkerStyle=="Separate" then {"FootstepLeft","FootstepRight"} else {"Footstep"}
		for _,markerName in names do table.insert(bucket,track:GetMarkerReachedSignal(markerName):Connect(function(value)
				if not track.IsPlaying or track.WeightCurrent<.15 then return end; self.LastMarker[character]=os.clock()
				local trackName=track.Name; local kind=if string.sub(trackName,1,10)=="CrouchWalk" then "Crouch" elseif string.sub(trackName,1,3)=="Run" then "Run" else "Walk"
				self:_step(character,kind,if markerName=="Footstep" then value elseif markerName=="FootstepLeft" then "Left" else "Right")
			end)) end
	end
	table.insert(bucket,animator.AnimationPlayed:Connect(observeTrack)); for _,track in animator:GetPlayingAnimationTracks() do observeTrack(track) end
	table.insert(bucket,humanoid.StateChanged:Connect(function(old,new) if old==Enum.HumanoidStateType.Freefall and new==Enum.HumanoidStateType.Landed then self:_step(character,"Land") end end))
	character.Destroying:Once(function() for _,connection in bucket do connection:Disconnect() end; self.Characters[character]=nil; self.RaycastParams[character]=nil; self.LastStep[character]=nil; self.LastMarker[character]=nil; self.NextFallback[character]=nil end)
end

function Controller._fallback(self:any,dt:number)
	if not Config.MarkerFallbackEnabled then return end; self.FallbackAccumulator+=dt; if self.FallbackAccumulator<Config.FallbackUpdateInterval then return end; self.FallbackAccumulator=0
	local now=os.clock()
	for character in self.Characters do
		local root=character:FindFirstChild("HumanoidRootPart"); local humanoid=character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health>0 and humanoid.FloorMaterial~=Enum.Material.Air then
			local speed=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
			if speed>=Config.MinHorizontalSpeed then local lastMarker=self.LastMarker[character]; if lastMarker and now-lastMarker<Config.MarkerFallbackSilenceTimeout then self.NextFallback[character]=now; continue end; local kind=if humanoid:GetAttribute("Crouched")==true then "Crouch" elseif speed>13 then "Run" else "Walk"; if now>=(self.NextFallback[character] or 0) then self:_step(character,kind,nil) end else self.NextFallback[character]=now end
		end
	end
end

function Controller._preloadIds(self:any,ids:{string})
	for startIndex=1,#ids,Config.PreloadBatchSize do
		local batch:{Instance}={}; local batchIds:{string}={}
		for index=startIndex,math.min(#ids,startIndex+Config.PreloadBatchSize-1) do local id=ids[index]; local pool:Pool?=self.SoundCache[id]; if pool then for _,sound in pool.Sounds do table.insert(batch,sound) end; table.insert(batchIds,id) end end
		local success=pcall(function() ContentProvider:PreloadAsync(batch) end)
		for _,id in batchIds do local pool:Pool?=self.SoundCache[id]; if pool then local ready=false; for _,sound in pool.Sounds do if sound.IsLoaded then ready=true; break end end; pool.Ready=success and ready end end
		if Config.Preloading.Debug then print(`[Footstep] preload batch assets={#batch} success={success}`) end; task.wait()
	end
end

function Controller._preload(self:any)
	local unique:{[string]:boolean}={}; local ordered:{string}={}
	for _,definition:any in Config.Profiles do for _,kind in {"Walk","Run","Crouch","Land"} do for _,id in definition[kind] do if validId(id) and not unique[id] and #ordered<Config.MaximumPreloadedSounds then unique[id]=true; table.insert(ordered,id) end end end end
	for _,id in ordered do local voices:{Sound}={}; for _=1,Config.VoicesPerSound do local sound=Instance.new("Sound"); sound.SoundId=id; sound.RollOffMaxDistance=Config.MaxDistance; sound.RollOffMinDistance=4; sound.RollOffMode=Enum.RollOffMode.InverseTapered; sound.Parent=SoundService; table.insert(voices,sound) end; self.SoundCache[id]={Sounds=voices,Next=1,Ready=false} end
	local fallbackSet:{[string]:boolean}={}; local fallbackIds:{string}={}; local rest:{string}={}; local fallback:any=Config.Profiles[Config.Preloading.InitialFallbackProfile]
	if fallback then for _,kind in {"Walk","Run","Crouch","Land"} do for _,id in fallback[kind] do if validId(id) and unique[id] and not fallbackSet[id] then fallbackSet[id]=true; table.insert(fallbackIds,id) end end end end
	for _,id in ordered do if not fallbackSet[id] then table.insert(rest,id) end end
	task.spawn(function() self:_preloadIds(fallbackIds); self:_preloadIds(rest) end)
	task.delay(Config.Preloading.MaximumInitialWait,function()
		if not Config.Preloading.Debug then return end
		local ready=false; for _,id in fallbackIds do local pool:Pool?=self.SoundCache[id]; if pool and pool.Ready then ready=true; break end end
		if not ready then warn("[Footstep] Default fallback audio was not ready before MaximumInitialWait; contacts will keep retrying without queuing stale sounds") end
	end)
end

function Controller.Start(self:any)
	self:_preload(); RunService.Heartbeat:Connect(function(dt) self:_fallback(dt) end)
	local function observePlayer(player:Player) player.CharacterAdded:Connect(function(character) self:_observe(character) end); if player.Character then self:_observe(player.Character) end end
	Players.PlayerAdded:Connect(observePlayer); for _,player in Players:GetPlayers() do observePlayer(player) end
end
return Controller
