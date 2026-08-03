--!strict
-- ModuleScript: ServerScriptService/Services/ToolService
local Players=game:GetService("Players")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config:any=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("ToolConfig"))
local Service={}; Service.__index=Service

type RateRecord={WindowStart:number,Count:number}
type PrimaryResult={ResultingActive:boolean,Commit:()->()}
type PrimaryHandler=(any,Player,Tool,any)->PrimaryResult?
type Approval={ToolId:string,Owner:Player}

local function resolvePath(root:Instance,path:{string}):Instance?
	local current:Instance?=root
	for _,name in path do
		local snapshot=current; if snapshot==nil then return nil end
		current=snapshot:FindFirstChild(name)
	end
	return current
end

function Service.new(states:any,request:RemoteEvent,stateChanged:RemoteEvent):any
	local self=setmetatable({States=states,Request=request,StateChanged=stateChanged,Templates=nil,
		Approved=setmetatable({}, {__mode="k"}) :: {[Tool]:Approval},Cooldowns={} :: {[Player]:{[Tool]:number}},
		Rates={} :: {[Player]:RateRecord},Generations=setmetatable({}, {__mode="k"}),
		Connections={} :: {[Player]:{RBXScriptConnection}},Handlers={} :: {[string]:PrimaryHandler}},Service)
	self:RegisterPrimaryHandler("Flashlight",function(service:any,_player:Player,tool:Tool,definition:any):PrimaryResult?
		local light=resolvePath(tool,definition.LightPath)
		if not light or not light:IsA("SpotLight") then return nil end
		local active=tool:GetAttribute("Active")==true; local resulting=not active
		return {ResultingActive=resulting,Commit=function() tool:SetAttribute("Active",resulting); light.Enabled=resulting end}
	end)
	return self
end

function Service.RegisterPrimaryHandler(self:any,toolId:string,handler:PrimaryHandler)
	if Config.Tools[toolId]==nil then error(`[ToolService] Cannot register unconfigured ToolId {toolId}`) end
	self.Handlers[toolId]=handler
end

function Service._validateStructure(_self:any,tool:Tool,toolId:string,warnOnFailure:boolean):boolean
	local definition:any=Config.Tools[toolId]
	local function invalid(message:string):boolean if warnOnFailure then warn(`[ToolService] {tool:GetFullName()}: {message}`) end; return false end
	if definition==nil then return invalid(`ToolId "{toolId}" has no ToolConfig entry`) end
	if tool.Name~=definition.TemplateName then return invalid(`expected Tool.Name "{definition.TemplateName}"`) end
	if tool:GetAttribute("ToolId")~=toolId then return invalid(`missing or incorrect ToolId attribute (expected "{toolId}")`) end
	if not tool.RequiresHandle then return invalid("RequiresHandle must be true") end
	if tool.CanBeDropped then return invalid("CanBeDropped must be false") end
	local handle=tool:FindFirstChild("Handle"); if not handle or not handle:IsA("BasePart") then return invalid("missing BasePart named Handle") end
	local attachment=handle:FindFirstChild("LightAttachment"); if not attachment or not attachment:IsA("Attachment") then return invalid("missing Handle.LightAttachment Attachment") end
	local light=attachment:FindFirstChild("SpotLight"); if not light or not light:IsA("SpotLight") then return invalid("missing Handle.LightAttachment.SpotLight") end
	local defaults:any=definition.LightDefaults
	if warnOnFailure and light.Enabled then return invalid("SpotLight.Enabled must start false in the template") end
	if light.Brightness<=0 then return invalid("SpotLight.Brightness must be greater than zero") end
	if light.Range<=0 then return invalid("SpotLight.Range must be greater than zero") end
	if light.Angle<=0 or light.Angle>180 then return invalid("SpotLight.Angle must be greater than 0 and no more than 180") end
	if defaults and light.Face~=defaults.Face then return invalid(`SpotLight.Face must be {defaults.Face.Name} for the configured lens convention`) end
	return true
end

function Service._applyLightDefaults(_self:any,light:SpotLight,definition:any)
	local defaults:any=definition.LightDefaults; if defaults==nil then return end
	light.Face=defaults.Face; light.Brightness=defaults.Brightness; light.Range=defaults.Range
	light.Angle=defaults.Angle; light.Shadows=defaults.Shadows; light.Color=defaults.Color; light.Enabled=false
end

function Service._disable(self:any,tool:Tool,toolId:string)
	self.Generations[tool]=(self.Generations[tool] or 0)+1
	local definition:any=Config.Tools[toolId]; if definition==nil then return end
	local light=resolvePath(tool,definition.LightPath); tool:SetAttribute("Active",false)
	if light and light:IsA("SpotLight") then light.Enabled=false end
end

function Service._registerClone(self:any,tool:Tool,toolId:string,owner:Player)
	self.Approved[tool]={ToolId=toolId,Owner=owner}; self.Generations[tool]=0
	tool.Unequipped:Connect(function() local definition:any=Config.Tools[toolId]; if definition and definition.TurnOffWhenUnequipped then self:_disable(tool,toolId) end end)
	tool.Destroying:Connect(function() self.Generations[tool]=(self.Generations[tool] or 0)+1; self.Approved[tool]=nil end)
end

function Service._give(self:any,player:Player,toolId:string)
	local definition:any=Config.Tools[toolId]; if definition==nil then return end
	local character=player.Character; local backpack=player:FindFirstChildOfClass("Backpack")
	if backpack==nil then return end
	for _,container in {backpack,character} do if container then for _,child in container:GetChildren() do if child:IsA("Tool") and child:GetAttribute("ToolId")==toolId then return end end end end
	local templates:Folder?=self.Templates; if templates==nil then return end
	local template=templates:FindFirstChild(definition.TemplateName)
	if not template or not template:IsA("Tool") then warn(`[ToolService] Missing Tool template ServerStorage.ToolTemplates.{definition.TemplateName}`); return end
	if not self:_validateStructure(template,toolId,true) then return end
	local clone=template:Clone(); clone:SetAttribute("Active",false)
	local light=resolvePath(clone,definition.LightPath); if light and light:IsA("SpotLight") then self:_applyLightDefaults(light,definition) end
	self:_registerClone(clone,toolId,player); clone.Parent=backpack
end

function Service._rateAllowed(self:any,player:Player):boolean
	local now=workspace:GetServerTimeNow(); local record:RateRecord?=self.Rates[player]
	if record==nil or now-record.WindowStart>=Config.RemoteRateLimit.Window then self.Rates[player]={WindowStart=now,Count=1}; return true end
	record.Count+=1; return record.Count<=Config.RemoteRateLimit.MaximumRequests
end

function Service._stillValid(self:any,player:Player,tool:Tool,toolId:string):boolean
	local character=player.Character
	local approval:Approval?=self.Approved[tool]
	if character==nil or tool.Parent~=character or approval==nil or approval.ToolId~=toolId or approval.Owner~=player or not self.States:CanUseTools(player) or not self:_validateStructure(tool,toolId,false) then return false end
	local definition:any=Config.Tools[toolId]; local light=if definition then resolvePath(tool,definition.LightPath) else nil
	if not light or not light:IsA("SpotLight") then return false end
	local attachment=light.Parent; if not attachment or not attachment:IsA("Attachment") then return false end
	local lightPart=attachment.Parent
	return lightPart~=nil and lightPart:IsA("BasePart") and lightPart:IsDescendantOf(workspace)
end

function Service._primary(self:any,player:Player,value:Instance)
	if not self:_rateAllowed(player) or not value:IsA("Tool") then return end
	local tool:Tool=value; local toolIdValue=tool:GetAttribute("ToolId")
	if typeof(toolIdValue)~="string" then return end
	local toolId:string=toolIdValue; local definition:any=Config.Tools[toolId]
	if definition==nil or not self:_stillValid(player,tool,toolId) then return end
	local perPlayer=self.Cooldowns[player] or {}; self.Cooldowns[player]=perPlayer
	local now=workspace:GetServerTimeNow(); if now<(perPlayer[tool] or 0) then return end
	local handler:PrimaryHandler?=self.Handlers[toolId]; if handler==nil then return end
	local result=handler(self,player,tool,definition); if result==nil then return end
	local approvedResult:PrimaryResult=result
	perPlayer[tool]=now+definition.PrimaryCooldown
	local generation=(self.Generations[tool] or 0)+1; self.Generations[tool]=generation
	self.StateChanged:FireClient(player,{Kind="PrimaryApproved",Tool=tool,ToolId=toolId,AnimationKey=definition.PrimaryAnimation,ServerStartTime=now,ResultingActive=approvedResult.ResultingActive})
	task.delay(definition.PrimaryCommitTime,function()
		if self.Generations[tool]~=generation or not self:_stillValid(player,tool,toolId) then return end
		approvedResult.Commit()
	end)
end

function Service._player(self:any,player:Player)
	self.Connections[player]={}
	table.insert(self.Connections[player],player.CharacterAdded:Connect(function(character)
		local humanoid=character:WaitForChild("Humanoid",10)
		if humanoid and humanoid:IsA("Humanoid") then table.insert(self.Connections[player],humanoid.Died:Connect(function()
				for tool,approval in self.Approved do if tool:IsDescendantOf(character) then self:_disable(tool,approval.ToolId) end end
			end)) end
		task.defer(function() for toolId,definition:any in Config.Tools do if definition.GiveOnSpawnForTesting then self:_give(player,toolId) end end end)
	end))
	if player.Character then task.defer(function() for toolId,definition:any in Config.Tools do if definition.GiveOnSpawnForTesting then self:_give(player,toolId) end end end) end
end

function Service.Start(self:any)
	local existing=ServerStorage:FindFirstChild("ToolTemplates")
	if existing and not existing:IsA("Folder") then error("ServerStorage.ToolTemplates must be a Folder") end
	if not existing then existing=Instance.new("Folder"); existing.Name="ToolTemplates"; existing.Parent=ServerStorage end
	self.Templates=existing :: Folder
	for toolId,definition:any in Config.Tools do local template=existing:FindFirstChild(definition.TemplateName); if not template then warn(`[ToolService] Missing template for configured ToolId {toolId}: ServerStorage.ToolTemplates.{definition.TemplateName}`) elseif not template:IsA("Tool") then warn(`[ToolService] {template:GetFullName()} must be a Tool`) else self:_validateStructure(template,toolId,true) end end
	self.Request.OnServerEvent:Connect(function(player:Player,action:unknown,value:unknown) if action~="Primary" or typeof(value)~="Instance" then return end; self:_primary(player,value :: Instance) end)
	Players.PlayerAdded:Connect(function(player) self:_player(player) end)
	Players.PlayerRemoving:Connect(function(player) for _,connection in self.Connections[player] or {} do connection:Disconnect() end; self.Connections[player]=nil; self.Cooldowns[player]=nil; self.Rates[player]=nil end)
	for _,player in Players:GetPlayers() do self:_player(player) end
end
return Service
