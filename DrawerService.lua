--!strict
-- ModuleScript: ServerScriptService/Services/DrawerService
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local AnimationConfig:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local Service={}; Service.__index=Service
type ActiveRecord={Kind:string,Generation:number,Tween:Tween?,Cancel:(()->())?}
function Service.new(loot:any?,objectAnimation:any?):any return setmetatable({Loot=loot,ObjectAnimation=objectAnimation,Active={} :: {[Instance]:ActiveRecord},Closed={} :: {[Instance]:CFrame},Generations={} :: {[Instance]:number},ModeWarnings={} :: {[Instance]:boolean}},Service) end
local function setPrompt(target:Instance,enabled:boolean) local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true); if prompt then prompt.Enabled=enabled end end
function Service._finish(self:any,target:Instance,generation:number,opening:boolean)
	local active:ActiveRecord?=self.Active[target]; if active==nil or active.Generation~=generation or not target.Parent then return end
	self.Active[target]=nil; target:SetAttribute("Opened",opening); target:SetAttribute("InteractionId",if opening then "CloseDrawer" else "OpenDrawer"); target:SetAttribute("InteractionText",if opening then "Close" else "Open"); target:SetAttribute("Enabled",true); setPrompt(target,true); if self.Loot then self.Loot:SetDrawerOpen(target,opening) end
	if AnimationConfig.ObjectAnimationDebug then print(`[DrawerService] complete target={target:GetFullName()} opened={opening} generation={generation}`) end
end
function Service._mode(self:any,target:Instance,animationKey:string):string
	local raw=target:GetAttribute("ObjectMotionMode")
	if raw=="Animation" or raw=="AttachmentTween" then return raw end
	local canAnimate=false; if self.ObjectAnimation then canAnimate=self.ObjectAnimation.CanPlay(target,animationKey) end
	local selected=if canAnimate then "Animation" else "AttachmentTween"
	if AnimationConfig.ObjectAnimationDebug and not self.ModeWarnings[target] then self.ModeWarnings[target]=true; warn(`[DrawerService] {target:GetFullName()} has no ObjectMotionMode; selected {selected}`) end
	return selected
end
function Service.Toggle(self:any,_player:Player,target:Instance)
	if self.Active[target] then return end
	local drawerValue=target:FindFirstChild("Drawer",true); local openValue=target:FindFirstChild("OpenPoint",true)
	if not drawerValue or not drawerValue:IsA("BasePart") or not openValue or not openValue:IsA("Attachment") then warn(`[DrawerService] {target:GetFullName()} requires a Drawer BasePart and OpenPoint Attachment`); return end
	local drawer:BasePart=drawerValue; local openPoint:Attachment=openValue
	if self.Closed[target]==nil then self.Closed[target]=drawer.CFrame end
	local opening=target:GetAttribute("Opened")~=true; local animationKey=if opening then "DrawerOpen" else "DrawerClose"
	local mode=self:_mode(target,animationKey); self.Generations[target]=(self.Generations[target] or 0)+1; local generation=self.Generations[target]
	target:SetAttribute("Enabled",false); setPrompt(target,false)
	if mode=="Animation" and self.ObjectAnimation then
		local result=self.ObjectAnimation.Play(target,animationKey,0)
		if result then
			self.Active[target]={Kind="Animation",Generation=generation,Cancel=result.Cancel}
			if AnimationConfig.ObjectAnimationDebug then print(`[DrawerService] target={target:GetFullName()} direction={if opening then "Open" else "Close"} mode=Animation key={animationKey} initialLength={result.InitialLength} duration={result.Duration} generation={generation}`) end
			task.delay(result.Duration,function() self:_finish(target,generation,opening) end); return
		end
		warn(`[DrawerService] {target:GetFullName()} requested Animation mode but {animationKey} could not play; falling back to AttachmentTween`)
	end
	local closedPoint=target:FindFirstChild("ClosedPoint",true); local destination:CFrame
	if opening then destination=openPoint.WorldCFrame elseif closedPoint and closedPoint:IsA("Attachment") then destination=closedPoint.WorldCFrame else destination=self.Closed[target] end
	local durationValue=target:GetAttribute("DrawerTweenTime"); local duration=if typeof(durationValue)=="number" then math.clamp(durationValue,.05,3) else .55
	drawer.Anchored=true; local tween=TweenService:Create(drawer,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=destination}); self.Active[target]={Kind="AttachmentTween",Generation=generation,Tween=tween}
	if AnimationConfig.ObjectAnimationDebug then print(`[DrawerService] target={target:GetFullName()} direction={if opening then "Open" else "Close"} mode=AttachmentTween key=none initialLength=0 duration={duration} generation={generation}`) end
	tween.Completed:Once(function(state) if state==Enum.PlaybackState.Completed then self:_finish(target,generation,opening) end end); tween:Play()
end
function Service.CleanupRoom(self:any,room:any)
	for target,record in self.Active do if target:IsDescendantOf(room.Model) then self.Generations[target]=(self.Generations[target] or 0)+1; local activeTween:Tween?=record.Tween; if activeTween then activeTween:Cancel() end; local cancel:(()->())?=record.Cancel; if cancel then cancel() end; self.Active[target]=nil end end
	for target in self.Closed do if target:IsDescendantOf(room.Model) then self.Closed[target]=nil end end
end
return Service
