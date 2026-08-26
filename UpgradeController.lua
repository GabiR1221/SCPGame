--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/UpgradeController
local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ContextActionService=game:GetService("ContextActionService")
local RunService=game:GetService("RunService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local LocalPlayer=Players.LocalPlayer
assert(LocalPlayer,"UpgradeController must run as a LocalScript")
local shared=ReplicatedStorage:WaitForChild("Shared")
local upgradeConfigModule=shared:WaitForChild("UpgradeConfig")
assert(upgradeConfigModule:IsA("ModuleScript"),"ReplicatedStorage.Shared.UpgradeConfig must be a ModuleScript")
local Config:any=require(upgradeConfigModule)
local remotes=ReplicatedStorage:WaitForChild("Remotes")
local purchaseInstance=remotes:WaitForChild("UpgradePurchaseRequest")
local stateInstance=remotes:WaitForChild("UpgradeStateChanged")
assert(purchaseInstance:IsA("RemoteEvent"),"ReplicatedStorage.Remotes.UpgradePurchaseRequest must be a RemoteEvent")
assert(stateInstance:IsA("RemoteEvent"),"ReplicatedStorage.Remotes.UpgradeStateChanged must be a RemoteEvent")
local UpgradePurchaseRequest=purchaseInstance :: RemoteEvent
local UpgradeStateChanged=stateInstance :: RemoteEvent
local Controller={}; Controller.__index=Controller
function Controller.new(onMenuChanged:(boolean)->()):any return setmetatable({Gui=nil :: ScreenGui?,State=nil :: any?,Connections={} :: {RBXScriptConnection},BoundNodes={} :: {[GuiObject]:boolean},OnMenuChanged=onMenuChanged},Controller) end
function Controller._setStatus(_self:any,node:GuiObject,text:string)
	local status=node:FindFirstChild("StatusLabel")
	if status and status:IsA("TextLabel") then status.Text=text end
end
function Controller._requestPurchase(self:any,node:GuiObject,id:string)
	self:_setStatus(node,"Purchasing...")
	if Config.Testing.Debug then print(`[UpgradeController] requesting upgrade {id}`) end
	UpgradePurchaseRequest:FireServer(id)
end
function Controller._bindNode(self:any,item:Instance)
	if not item:IsA("GuiObject") or self.BoundNodes[item] then return end
	local id=item:GetAttribute("UpgradeId")
	if typeof(id)~="string" or id=="" then
		-- A node named exactly like a configured upgrade is accepted as a safe
		-- Studio fallback, while the warning tells the author how to fix the UI.
		for _,tree:any in Config.Trees do
			if tree.Upgrades[item.Name] then id=item.Name; item:SetAttribute("UpgradeId",id); warn(`[UpgradeController] {item:GetFullName()} was missing its UpgradeId String attribute; inferred "{id}" from its name`) break end
		end
	end
	if typeof(id)~="string" or id=="" then return end
	self.BoundNodes[item]=true; item.Active=true
	if Config.Testing.Debug then print(`[UpgradeController] bound {item:GetFullName()} to upgrade {id}`) end
	if not item:IsA("GuiButton") then
		warn(`[UpgradeController] {item:GetFullName()} is a {item.ClassName}; use an ImageButton or TextButton. Compatibility click handling is active for now.`)
	end
end
function Controller._activateAt(self:any,playerGui:PlayerGui,main:Instance,position:Vector2)
	for _,hit:GuiObject in playerGui:GetGuiObjectsAtPosition(math.floor(position.X),math.floor(position.Y)) do
		local cursor:Instance?=hit
		while cursor and cursor~=main do
			if cursor:IsA("GuiObject") and self.BoundNodes[cursor] then
				local id=cursor:GetAttribute("UpgradeId")
				if typeof(id)=="string" and cursor.Active then self:_requestPurchase(cursor,id) end
				return
			end
			cursor=cursor.Parent
		end
	end
end
function Controller._render(self:any)
	local gui:ScreenGui?=self.Gui; local state=self.State; if not gui or not state then return end; local main=gui:FindFirstChild("MainFrame"); if not main then return end
	local coins=main:FindFirstChild("CoinsLabel"); if coins and coins:IsA("TextLabel") then coins.Text=`Coins: {state.Coins}` end; local tree:any=Config.Trees[state.TreeId]; local title=main:FindFirstChild("TreeTitle"); if title and title:IsA("TextLabel") then title.Text=if tree then tree.DisplayName else state.TreeId end
	for _,item in main:GetDescendants() do local id=item:GetAttribute("UpgradeId"); if typeof(id)=="string" and item:IsA("GuiObject") then local definition=if tree then tree.Upgrades[id] else nil; local level=state.Owned[id] or 0; local owned=level>0; item.Active=definition~=nil and not owned; item:SetAttribute("Purchased",owned); item:SetAttribute("UpgradeLevel",level); if definition then item:SetAttribute("ConfiguredPrice",definition.Price) end; local nameLabel=item:FindFirstChild("NameLabel"); if nameLabel and nameLabel:IsA("TextLabel") and definition then nameLabel.Text=definition.DisplayName elseif item:IsA("TextButton") and definition then item.Text=`{definition.DisplayName} - {definition.Price}` end; local price=item:FindFirstChild("PriceLabel"); if price and price:IsA("TextLabel") and definition then price.Text=tostring(definition.Price) end; local status=item:FindFirstChild("StatusLabel"); if status and status:IsA("TextLabel") then status.Text=if owned then "Purchased" else "Available" end end end
end
function Controller.SetOpen(self:any,open:boolean)
	local gui:ScreenGui?=self.Gui
	if not gui or gui.Enabled==open then return end
	gui.Enabled=open
	if open then
		self.PreviousCameraMode=LocalPlayer.CameraMode
		LocalPlayer.CameraMode=Enum.CameraMode.Classic
		RunService:BindToRenderStep("UpgradeMenuMouse",Enum.RenderPriority.Last.Value,function()
			UserInputService.MouseBehavior=Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled=true
		end)
	else
		RunService:UnbindFromRenderStep("UpgradeMenuMouse")
		local previous:Enum.CameraMode?=self.PreviousCameraMode
		LocalPlayer.CameraMode=previous or Enum.CameraMode.LockFirstPerson
		self.PreviousCameraMode=nil
		UserInputService.MouseBehavior=Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled=false
	end
	self.OnMenuChanged(open)
end
function Controller.Start(self:any)
	local playerGui=LocalPlayer:WaitForChild("PlayerGui",10)
	if not playerGui or not playerGui:IsA("PlayerGui") then warn("[UpgradeController] LocalPlayer.PlayerGui is missing"); return end
	local found=if playerGui then playerGui:WaitForChild("UpgradeTreeGui",10) else nil
	if not found or not found:IsA("ScreenGui") then
		warn("[UpgradeController] StarterGui.UpgradeTreeGui must be a ScreenGui that clones directly into PlayerGui; upgrade UI disabled")
	else
		self.Gui=found
		self:SetOpen(false)
		local main=found:FindFirstChild("MainFrame")
		if not main then
			warn("[UpgradeController] UpgradeTreeGui.MainFrame is missing")
		else
			for _,item in main:GetDescendants() do self:_bindNode(item) end
			table.insert(self.Connections,main.DescendantAdded:Connect(function(item:Instance) self:_bindNode(item) end))
			table.insert(self.Connections,UserInputService.InputBegan:Connect(function(input:InputObject)
				if not found.Enabled then return end
				if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then self:_activateAt(playerGui,main,Vector2.new(input.Position.X,input.Position.Y)) end
			end))
			local close=main:FindFirstChild("CloseButton")
			if close and close:IsA("GuiButton") then
				table.insert(self.Connections,close.Activated:Connect(function()
					self:SetOpen(false)
				end))
			end
		end
	end
	ContextActionService:BindAction("ToggleUpgradeTree",function(_name:string,state:Enum.UserInputState,_input:InputObject):Enum.ContextActionResult
		if state==Enum.UserInputState.Begin then local gui:ScreenGui?=self.Gui; if gui then self:SetOpen(not gui.Enabled) end end
		return Enum.ContextActionResult.Sink
	end,true,Enum.KeyCode.V)
	ContextActionService:SetTitle("ToggleUpgradeTree","Upgrades")
	ContextActionService:SetPosition("ToggleUpgradeTree",UDim2.fromScale(.12,.45))
	UpgradeStateChanged.OnClientEvent:Connect(function(state:any,message:string?) self.State=state; local gui:ScreenGui?=self.Gui; if gui and message then gui:SetAttribute("LastPurchaseResult",message) end; self:_render(); if message and Config.Testing.Debug then print(`[UpgradeController] server result: {message}`) end; if message and message~="Purchased" then warn(`[UpgradeController] purchase rejected: {message}`) end end)
	UpgradePurchaseRequest:FireServer("__Sync")
end
return Controller
