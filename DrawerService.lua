--!strict
-- ModuleScript: ServerScriptService/Services/DrawerService
local TweenService=game:GetService("TweenService")
local Service={}; Service.__index=Service
function Service.new():any return setmetatable({Active={} :: {[Instance]:Tween}},Service) end

function Service.Open(self:any,_player:Player,target:Instance)
	if target:GetAttribute("Opened")==true or self.Active[target] then return end
	local drawerValue=target:FindFirstChild("Drawer",true); local openValue=target:FindFirstChild("OpenPoint",true)
	if not drawerValue or not drawerValue:IsA("BasePart") or not openValue or not openValue:IsA("Attachment") then warn(`[DrawerService] {target:GetFullName()} requires a Drawer BasePart and OpenPoint Attachment`); return end
	local drawer:BasePart=drawerValue; local openPoint:Attachment=openValue
	drawer.Anchored=true; target:SetAttribute("Opened",true); target:SetAttribute("Enabled",false)
	local prompt=target:FindFirstChildWhichIsA("ProximityPrompt",true); if prompt then prompt.Enabled=false end
	local durationValue=target:GetAttribute("DrawerTweenTime"); local duration=if typeof(durationValue)=="number" then math.clamp(durationValue,.05,3) else .55
	local tween=TweenService:Create(drawer,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=openPoint.WorldCFrame}); self.Active[target]=tween
	tween.Completed:Once(function() self.Active[target]=nil end); tween:Play()
end
return Service
