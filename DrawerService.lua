--!strict
-- ModuleScript: ServerScriptService/Services/DrawerService
local TweenService=game:GetService("TweenService")
local Service={}; Service.__index=Service
function Service.new(loot:any?):any return setmetatable({Loot=loot,Active={} :: {[Instance]:Tween},Closed={} :: {[Instance]:CFrame}},Service) end

function Service.Toggle(self:any,_player:Player,target:Instance)
	if self.Active[target] then return end
	local drawerValue=target:FindFirstChild("Drawer",true); local openValue=target:FindFirstChild("OpenPoint",true)
	if not drawerValue or not drawerValue:IsA("BasePart") or not openValue or not openValue:IsA("Attachment") then warn(`[DrawerService] {target:GetFullName()} requires a Drawer BasePart and OpenPoint Attachment`); return end
	local drawer:BasePart=drawerValue; local openPoint:Attachment=openValue
	if self.Closed[target]==nil then self.Closed[target]=drawer.CFrame end
	local opening=target:GetAttribute("Opened")~=true
	local closedPoint=target:FindFirstChild("ClosedPoint",true)
	local destination:CFrame
	if opening then destination=openPoint.WorldCFrame elseif closedPoint and closedPoint:IsA("Attachment") then destination=closedPoint.WorldCFrame else destination=self.Closed[target] end
	drawer.Anchored=true; target:SetAttribute("Enabled",false)
	local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true); if prompt then prompt.Enabled=false end
	local durationValue=target:GetAttribute("DrawerTweenTime"); local duration=if typeof(durationValue)=="number" then math.clamp(durationValue,.05,3) else .55
	local tween=TweenService:Create(drawer,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=destination}); self.Active[target]=tween
	tween.Completed:Once(function(state) if self.Active[target]~=tween then return end; self.Active[target]=nil; if state==Enum.PlaybackState.Completed and target.Parent then target:SetAttribute("Opened",opening); target:SetAttribute("InteractionId",if opening then "CloseDrawer" else "OpenDrawer"); target:SetAttribute("InteractionText",if opening then "Close" else "Open"); target:SetAttribute("Enabled",true); if prompt then prompt.Enabled=true end; if self.Loot then self.Loot:SetDrawerOpen(target,opening) end end end); tween:Play()
end
function Service.CleanupRoom(self:any,room:any) for target,tween in self.Active do if target:IsDescendantOf(room.Model) then tween:Cancel(); self.Active[target]=nil end end; for target in self.Closed do if target:IsDescendantOf(room.Model) then self.Closed[target]=nil end end end
return Service
