--!strict
-- ModuleScript: ReplicatedStorage/Shared/ObjectAnimationUtil
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local AnimationConfig:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local Util={}
local cache:{[Animator]:{[string]:AnimationTrack}}={}
local activeByAnimator:{[Animator]:AnimationTrack}={}
local function animatorFor(target:Instance):Animator?
	local controller=target:FindFirstChildOfClass("AnimationController")
	if controller==nil then
		local descendant=target:FindFirstChildWhichIsA("AnimationController",true)
		if descendant then controller=descendant end
	end
	if controller==nil then return nil end
	local animator=controller:FindFirstChildOfClass("Animator")
	if animator then return animator end
	local created=Instance.new("Animator"); created.Parent=controller; return created
end
local function namedBasePart(target:Instance,name:string):BasePart?
	local value=target:FindFirstChild(name,true)
	if value and value:IsA("BasePart") then return value end
	return nil
end
local function objectRoot(target:Instance):BasePart?
	local rootName=target:GetAttribute("ObjectAnimationRootName")
	if typeof(rootName)=="string" then
		local configured=namedBasePart(target,rootName)
		if configured then return configured end
	end
	if target:IsA("Model") then
		local primary=target.PrimaryPart
		if primary then return primary end
	end
	return namedBasePart(target,"Root") or namedBasePart(target,"AnimationRoot") or namedBasePart(target,"Collision") or namedBasePart(target,"CollisionPart")
end
function Util.Prepare(target:Instance)
	local root=objectRoot(target)
	if root==nil then return end
	root.Anchored=true
	root.AssemblyLinearVelocity=Vector3.zero
	root.AssemblyAngularVelocity=Vector3.zero
end
function Util.Play(target:Instance,key:string,fadeTime:number?):AnimationTrack?
	local definitions:any=AnimationConfig.ObjectAnimations
	local definition:any=if definitions then definitions[key] else nil
	if definition==nil or definition.Id=="" or definition.Id=="rbxassetid://0" then return nil end
	local animator=animatorFor(target); if animator==nil then return nil end
	Util.Prepare(target)
	local animatorCache=cache[animator]
	if animatorCache==nil then animatorCache={}; cache[animator]=animatorCache end
	local cachedTrack:AnimationTrack?=animatorCache[key]
	local activeTrack:AnimationTrack
	if cachedTrack==nil then
		local animation=Instance.new("Animation"); animation.Name=key; animation.AnimationId=definition.Id
		local loadedTrack=animator:LoadAnimation(animation); animation:Destroy(); loadedTrack.Name=key; loadedTrack.Priority=definition.Priority; loadedTrack.Looped=definition.Looped; animatorCache[key]=loadedTrack; activeTrack=loadedTrack
	else
		activeTrack=cachedTrack
	end
	local previous=activeByAnimator[animator]
	if previous and previous~=activeTrack then previous:Stop(0) end
	activeByAnimator[animator]=activeTrack
	if activeTrack.IsPlaying then activeTrack:Stop(0) end
	activeTrack:AdjustSpeed(1)
	activeTrack.TimePosition=0; activeTrack:Play(if fadeTime~=nil then fadeTime else 0)
	if activeTrack.Looped==false and activeTrack.Length>0 then
		local holdTrack=activeTrack
		task.delay(math.max(0,activeTrack.Length-.03),function()
			if activeByAnimator[animator]~=holdTrack or not holdTrack.IsPlaying then return end
			holdTrack.TimePosition=math.max(0,holdTrack.Length-.03)
			holdTrack:AdjustSpeed(0)
		end)
	end
	return activeTrack
end
return Util
