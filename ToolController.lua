--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/ToolController
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local LocalPlayer=Players.LocalPlayer :: Player
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ToolConfig"))
local Remotes=ReplicatedStorage:WaitForChild("Remotes")
local Request=Remotes:WaitForChild("ToolActionRequest") :: RemoteEvent
local StateChanged=Remotes:WaitForChild("ToolStateChanged") :: RemoteEvent
local Controller={}; Controller.__index=Controller

type ToolRecord={Connections:{RBXScriptConnection}}

function Controller.new(animationController:any,viewmodelController:any):any
	return setmetatable({Animation=animationController,Viewmodel=viewmodelController,Records={} :: {[Tool]:ToolRecord},
		ContainerConnections={} :: {RBXScriptConnection},Equipped=nil,Generation=0},Controller)
end

function Controller._unregister(self:any,tool:Tool)
	local record:ToolRecord?=self.Records[tool]; if record==nil then return end
	for _,connection in record.Connections do connection:Disconnect() end
	self.Records[tool]=nil
	if self.Equipped==tool then self.Generation+=1; self.Equipped=nil; self.Animation:ClearToolAnimations(); self.Viewmodel:Clear() end
end

function Controller._equipped(self:any,tool:Tool,toolId:string,definition:any)
	if tool.Parent~=LocalPlayer.Character then return end
	local previous:Tool?=self.Equipped; if previous and previous~=tool then self.Animation:ClearToolAnimations() end
	self.Generation+=1; local generation:number=self.Generation; self.Equipped=tool
	self.Viewmodel:SetEquippedTool(tool,toolId)
	self.Animation:ClearToolAnimations(); local track:AnimationTrack?=self.Animation:PlayToolAction(definition.EquipAnimation)
	local delayTime:number=definition.EquipFallbackDuration
	if track and track.Length>0 then delayTime=math.min(track.Length,2) end
	task.delay(delayTime,function()
		local equipped:Tool?=self.Equipped
		if self.Generation~=generation or equipped~=tool or tool.Parent~=LocalPlayer.Character then return end
		self.Animation:SetToolIdle(definition.IdleAnimation)
		self.Viewmodel:SetIdle(definition.Viewmodel.IdleAnimation)
	end)
end

function Controller._unequipped(self:any,tool:Tool,definition:any)
	if self.Equipped~=tool then return end
	self.Generation+=1; self.Equipped=nil; self.Animation:ClearToolAnimations()
	self.Viewmodel:Unequip(tool)
	self.Animation:PlayToolAction(definition.UnequipAnimation)
end

function Controller._register(self:any,instance:Instance)
	if not instance:IsA("Tool") or self.Records[instance] then return end
	local toolIdValue=instance:GetAttribute("ToolId"); if typeof(toolIdValue)~="string" then return end
	local toolId:string=toolIdValue; local definition:any=Config.Tools[toolId]; if definition==nil then return end
	local tool:Tool=instance; local record:ToolRecord={Connections={}}; self.Records[tool]=record
	table.insert(record.Connections,tool.Equipped:Connect(function() self:_equipped(tool,toolId,definition) end))
	table.insert(record.Connections,tool.Unequipped:Connect(function() self:_unequipped(tool,definition) end))
	table.insert(record.Connections,tool.Activated:Connect(function()
		local equipped:Tool?=self.Equipped
		if equipped~=tool or tool.Parent~=LocalPlayer.Character or tool:GetAttribute("ToolId")~=toolId then return end
		Request:FireServer("Primary",tool)
	end))
	table.insert(record.Connections,tool.AncestryChanged:Connect(function()
		task.defer(function()
			local backpack=LocalPlayer:FindFirstChildOfClass("Backpack"); local character=LocalPlayer.Character
			if (backpack==nil or not tool:IsDescendantOf(backpack)) and (character==nil or not tool:IsDescendantOf(character)) then self:_unregister(tool) end
		end)
	end))
	if tool.Parent==LocalPlayer.Character then self:_equipped(tool,toolId,definition) end
end

function Controller._observeContainer(self:any,container:Instance)
	table.insert(self.ContainerConnections,container.ChildAdded:Connect(function(child) self:_register(child) end))
	for _,child in container:GetChildren() do self:_register(child) end
end

function Controller._rebind(self:any)
	for _,connection in self.ContainerConnections do connection:Disconnect() end; table.clear(self.ContainerConnections)
	self.Generation+=1; self.Equipped=nil; self.Animation:ClearToolAnimations()
	self.Viewmodel:Clear()
	local backpack=LocalPlayer:WaitForChild("Backpack",10); if backpack then self:_observeContainer(backpack) end
	local character=LocalPlayer.Character; if character then self:_observeContainer(character) end
end

function Controller.Start(self:any)
	LocalPlayer.CharacterAdded:Connect(function() task.defer(function() self:_rebind() end) end)
	LocalPlayer.CharacterRemoving:Connect(function() self:_rebind() end)
	StateChanged.OnClientEvent:Connect(function(message:any)
		if typeof(message)~="table" or message.Kind~="PrimaryApproved" then return end
		local toolValue:unknown=message.Tool; if typeof(toolValue)~="Instance" or not toolValue:IsA("Tool") then return end
		local equipped:Tool?=self.Equipped; if equipped~=toolValue or toolValue.Parent~=LocalPlayer.Character then return end
		local toolIdValue=toolValue:GetAttribute("ToolId"); if typeof(toolIdValue)~="string" or message.ToolId~=toolIdValue then return end
		local definition:any=Config.Tools[toolIdValue]; if definition==nil or message.AnimationKey~=definition.PrimaryAnimation then return end
		self.Animation:PlayToolAction(definition.PrimaryAnimation)
		self.Viewmodel:PlayAction(definition.Viewmodel.PrimaryAnimation)
	end)
	self:_rebind()
end
return Controller
