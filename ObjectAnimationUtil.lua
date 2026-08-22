--!strict
-- ModuleScript: ReplicatedStorage/Shared/ObjectAnimationUtil
local ContentProvider=game:GetService("ContentProvider")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local AnimationConfig:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local Util={}
local cache:{[Animator]:{[string]:AnimationTrack}}={}
local activeByAnimator:{[Animator]:{Track:AnimationTrack,Generation:number}}={}
local generations:{[Animator]:number}={}
export type Result={Track:AnimationTrack,Duration:number,InitialLength:number,Generation:number,Cancel:()->()}
local function profileNameFor(target:Instance):string?
	local cursor:Instance?=target
	while cursor~=nil do
		local value=cursor:GetAttribute("ObjectAnimationProfile")
		if typeof(value)=="string" and value~="" then return value end
		cursor=cursor.Parent
	end
	return nil
end
local function definitionFor(target:Instance,key:string):any?
	local profileName=profileNameFor(target)
	if profileName~=nil then
		local profiles:any=AnimationConfig.ObjectAnimationProfiles
		local profile=if profiles then profiles[profileName] else nil
		return if profile then profile[key] else nil
	end
	local definitions:any=AnimationConfig.ObjectAnimations
	return if definitions then definitions[key] else nil
end
local function validId(definition:any?):boolean return definition~=nil and definition.Id~="" and definition.Id~="rbxassetid://0" end
local function animatorFor(target:Instance):Animator?
	local controller=target:FindFirstChildOfClass("AnimationController")
	if controller==nil then local descendant=target:FindFirstChildWhichIsA("AnimationController",true); if descendant then controller=descendant end end
	if controller==nil then return nil end
	local animator=controller:FindFirstChildOfClass("Animator"); if animator then return animator end
	local created=Instance.new("Animator"); created.Parent=controller; return created
end
local function namedBasePart(target:Instance,name:string):BasePart? local value=target:FindFirstChild(name,true); if value and value:IsA("BasePart") then return value end; return nil end
local function objectRoot(target:Instance):BasePart?
	local rootName=target:GetAttribute("ObjectAnimationRootName"); if typeof(rootName)=="string" then local configured=namedBasePart(target,rootName); if configured then return configured end end
	if target:IsA("Model") then local primary=target.PrimaryPart; if primary then return primary end end
	return namedBasePart(target,"Root") or namedBasePart(target,"AnimationRoot") or namedBasePart(target,"Collision") or namedBasePart(target,"CollisionPart")
end
function Util.Prepare(target:Instance) local root=objectRoot(target); if root==nil then return end; root.Anchored=true; root.AssemblyLinearVelocity=Vector3.zero; root.AssemblyAngularVelocity=Vector3.zero end
local function cachedTrack(target:Instance,key:string):AnimationTrack?
	local definition=definitionFor(target,key); if not validId(definition) then return nil end
	local animator=animatorFor(target); if animator==nil then return nil end
	local animatorCache=cache[animator]; if animatorCache==nil then animatorCache={}; cache[animator]=animatorCache end
	local profileName=profileNameFor(target) or "Default"
	local cacheKey=profileName..":"..key
	local track=animatorCache[cacheKey]
	if track==nil then local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=definition.Id; track=animator:LoadAnimation(animation); animation:Destroy(); track.Name=key; track.Priority=definition.Priority; track.Looped=definition.Looped; animatorCache[cacheKey]=track end
	return track
end
function Util.CanPlay(target:Instance,key:string):boolean return cachedTrack(target,key)~=nil end
function Util.PreloadTarget(target:Instance,keys:{string})
	task.spawn(function()
		local animations:{Instance}={}
		for _,key in keys do local definition=definitionFor(target,key); if validId(definition) then local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=definition.Id; table.insert(animations,animation); cachedTrack(target,key) end end
		if #animations>0 then local ok,err=pcall(function() ContentProvider:PreloadAsync(animations) end); if not ok and AnimationConfig.ObjectAnimationDebug then warn(`[ObjectAnimationUtil] preload failed for {target:GetFullName()}: {err}`) end end
		for _,animation in animations do animation:Destroy() end
	end)
end
function Util.Play(target:Instance,key:string,fadeTime:number?):Result?
	local definition=definitionFor(target,key); if not validId(definition) then return nil end
	local animator=animatorFor(target); if animator==nil then return nil end
	local activeTrack=cachedTrack(target,key); if activeTrack==nil then return nil end
	-- Loading a track does not necessarily start Roblox's lazy clip resolution.
	-- Start it once before waiting for Length, then rewind and restart from frame
	-- zero. Waiting before Play caused the first interaction in a fresh server to
	-- consume only the fallback duration while displaying no movement.
	Util.Prepare(target)
	if activeTrack.IsPlaying then activeTrack:Stop(0) end
	activeTrack:AdjustSpeed(1); activeTrack.TimePosition=0; activeTrack:Play(0)
	local lengthTimeout=if typeof(definition.LengthTimeout)=="number" then math.clamp(definition.LengthTimeout,0,.5) else .25
	local deadline=os.clock()+lengthTimeout
	while activeTrack.Length<=0 and os.clock()<deadline do RunService.Heartbeat:Wait() end
	generations[animator]=(generations[animator] or 0)+1; local generation=generations[animator]
	local previous=activeByAnimator[animator]; if previous and previous.Track~=activeTrack then previous.Track:Stop(0) end
	activeByAnimator[animator]={Track=activeTrack,Generation=generation}
	activeTrack:Stop(0)
	activeTrack:AdjustSpeed(1); activeTrack.TimePosition=0; activeTrack:Play(if fadeTime~=nil then fadeTime else 0)
	local fallback=if typeof(definition.Duration)=="number" then math.max(.05,definition.Duration) else 1
	local initialLength=activeTrack.Length; local duration=if initialLength>0 then initialLength else fallback
	if activeTrack.Looped==false then
		local finalEpsilon=if typeof(definition.FinalFrameEpsilon)=="number" then math.clamp(definition.FinalFrameEpsilon,.001,.05) else .001
		local holdLeadTime=if typeof(definition.HoldLeadTime)=="number" then math.clamp(definition.HoldLeadTime,.01,.2) else .05
		local holdTrack=activeTrack; local holdGeneration=generation; local holdTime=math.max(0,duration-holdLeadTime)
		task.delay(holdTime,function() local active=activeByAnimator[animator]; if active==nil or active.Generation~=holdGeneration or active.Track~=holdTrack or not holdTrack.IsPlaying then return end; holdTrack.TimePosition=math.max(0,(if holdTrack.Length>0 then holdTrack.Length else duration)-finalEpsilon); holdTrack:AdjustSpeed(0) end)
	end
	local function cancel() local active=activeByAnimator[animator]; if active and active.Generation==generation and active.Track==activeTrack then activeTrack:Stop(0); activeByAnimator[animator]=nil end end
	return {Track=activeTrack,Duration=duration,InitialLength=initialLength,Generation=generation,Cancel=cancel}
end
return Util
