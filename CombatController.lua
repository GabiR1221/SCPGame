--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CombatController
local ContextActionService=game:GetService("ContextActionService")
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local remotes=ReplicatedStorage:WaitForChild("Remotes")
local combatRequestInstance=remotes:WaitForChild("CombatRequest")
local combatStateInstance=remotes:WaitForChild("CombatStateChanged")
assert(combatRequestInstance:IsA("RemoteEvent"),"ReplicatedStorage.Remotes.CombatRequest must be a RemoteEvent")
assert(combatStateInstance:IsA("RemoteEvent"),"ReplicatedStorage.Remotes.CombatStateChanged must be a RemoteEvent")
local CombatRequest=combatRequestInstance :: RemoteEvent
local CombatStateChanged=combatStateInstance :: RemoteEvent
local Controller={}; Controller.__index=Controller
function Controller.new(animation:any):any return setmetatable({Animation=animation,MenuOpen=false,Equipped=false},Controller) end
function Controller.SetMenuOpen(self:any,value:boolean) self.MenuOpen=value end
function Controller.Start(self:any)
	-- createTouchButton=true gives phone/tablet players temporary test controls.
	ContextActionService:BindAction("ToggleCombatPower",function(_n,s,_i) if s==Enum.UserInputState.Begin and not self.MenuOpen then CombatRequest:FireServer("Toggle") end; return Enum.ContextActionResult.Sink end,true,Enum.KeyCode.Q,Enum.KeyCode.ButtonY)
	ContextActionService:BindAction("FireCombatPower",function(_n,s,_i) if s~=Enum.UserInputState.Begin or self.MenuOpen or not self.Equipped then return Enum.ContextActionResult.Pass end; local camera=Workspace.CurrentCamera; if camera then CombatRequest:FireServer("Fire",camera.CFrame.LookVector) end; return Enum.ContextActionResult.Sink end,true,Enum.UserInputType.MouseButton1,Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("ToggleCombatPower","Gun")
	ContextActionService:SetTitle("FireCombatPower","Fire")
	ContextActionService:SetPosition("ToggleCombatPower",UDim2.fromScale(.72,.58))
	ContextActionService:SetPosition("FireCombatPower",UDim2.fromScale(.78,.76))
	CombatStateChanged.OnClientEvent:Connect(function(action:string,animationKey:string?,idleKey:string?) if action=="Equipped" then self.Equipped=true; self.Animation:ClearToolAnimations(); self.Animation:SetPowerIdle(idleKey); self.Animation:PlayPowerAction(animationKey or "") elseif action=="Unequipped" then self.Equipped=false; self.Animation:ClearPowerAnimations(); if animationKey then self.Animation:PlayPowerAction(animationKey) end elseif action=="Fired" and animationKey then self.Animation:PlayPowerAction(animationKey) end end)
end
return Controller
