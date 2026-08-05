--!strict
-- ModuleScript: ReplicatedStorage/Shared/ObjectAnimationUtil
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local AnimationConfig:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local Util={}
local cache:{[Animator]:{[string]:AnimationTrack}}={}
local activeByAnimator:{[Animator]:{Track:AnimationTrack,Generation:number}}={}
local generations:{[Animator]:number}={}
export type Result={Track:AnimationTrack,Duration:number,InitialLength:number,Generation:number,Cancel:()->()}
local function definitionFor(key:string):any? local definitions:any=AnimationConfig.ObjectAnimations; return if definitions then definitions[key] else nil end
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
function Util.CanPlay(target:Instance,key:string):boolean
	local definition=definitionFor(key); if definition==nil or definition.Id=="" or definition.Id=="rbxassetid://0" then return false end
	return animatorFor(target)~=nil
end
local function resolvedDuration(track:AnimationTrack,definition:any): (number,number)
	local initial=track.Length
	local fallback=if typeof(definition.Duration)=="number" then math.max(.05,definition.Duration) else 1
	local timeout=if typeof(definition.LengthTimeout)=="number" then math.clamp(definition.LengthTimeout,0,.5) else .25
	local deadline=os.clock()+timeout
	while track.Length<=0 and os.clock()<deadline do RunService.Heartbeat:Wait() end
	local loaded=track.Length
	return if loaded>0 then loaded else fallback, initial
end
function Util.Play(target:Instance,key:string,fadeTime:number?):Result?
	local definition=definitionFor(key); if definition==nil or definition.Id=="" or definition.Id=="rbxassetid://0" then return nil end
	local animator=animatorFor(target); if animator==nil then return nil end
	Util.Prepare(target)
	local animatorCache=cache[animator]; if animatorCache==nil then animatorCache={}; cache[animator]=animatorCache end
	local cachedTrack:AnimationTrack?=animatorCache[key]
	local activeTrack:AnimationTrack
	if cachedTrack==nil then
		local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=definition.Id
		local loadedTrack=animator:LoadAnimation(animation); animation:Destroy(); loadedTrack.Name=key; loadedTrack.Priority=definition.Priority; loadedTrack.Looped=definition.Looped; animatorCache[key]=loadedTrack; activeTrack=loadedTrack
	else activeTrack=cachedTrack end
	generations[animator]=(generations[animator] or 0)+1; local generation=generations[animator]
	local previous=activeByAnimator[animator]; if previous and previous.Track~=activeTrack then previous.Track:Stop(0) end
	activeByAnimator[animator]={Track=activeTrack,Generation=generation}
	if activeTrack.IsPlaying then activeTrack:Stop(0) end
	activeTrack:AdjustSpeed(1); activeTrack.TimePosition=0; activeTrack:Play(if fadeTime~=nil then fadeTime else 0)
	local duration,initialLength=resolvedDuration(activeTrack,definition)
	if activeTrack.Looped==false then
		local finalEpsilon=if typeof(definition.FinalFrameEpsilon)=="number" then math.clamp(definition.FinalFrameEpsilon,.001,.05) else .001
		local holdLeadTime=if typeof(definition.HoldLeadTime)=="number" then math.clamp(definition.HoldLeadTime,.01,.2) else .05
		local holdTrack=activeTrack; local holdGeneration=generation; local holdTime=math.max(0,duration-holdLeadTime)
		task.delay(holdTime,function()
			local active=activeByAnimator[animator]; if active==nil or active.Generation~=holdGeneration or active.Track~=holdTrack or not holdTrack.IsPlaying then return end
			holdTrack.TimePosition=math.max(0,(if holdTrack.Length>0 then holdTrack.Length else duration)-finalEpsilon); holdTrack:AdjustSpeed(0)
		end)
	end
	local function cancel() local active=activeByAnimator[animator]; if active and active.Generation==generation and active.Track==activeTrack then activeTrack:Stop(0); activeByAnimator[animator]=nil end end
	return {Track=activeTrack,Duration=duration,InitialLength=initialLength,Generation=generation,Cancel=cancel}
end
return Util
