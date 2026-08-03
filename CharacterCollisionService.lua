--!strict
-- ModuleScript: ServerScriptService/Services/CharacterCollisionService
local Players=game:GetService("Players")
local PhysicsService=game:GetService("PhysicsService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config=require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterConfig"))
local Service={}; Service.__index=Service

type PlayerRecord={Connections:{RBXScriptConnection},CharacterConnections:{RBXScriptConnection}}

local function configureVisualPart(part:BasePart)
	part.CanCollide=false
	part.CanTouch=false
end

local function weld(root:BasePart,part:BasePart)
	local constraint=Instance.new("WeldConstraint")
	constraint.Part0=root; constraint.Part1=part; constraint.Parent=part
end

function Service.new():any
	return setmetatable({Records={} :: {[Player]:PlayerRecord}},Service)
end

function Service._cleanupCharacter(self:any,player:Player)
	local record:PlayerRecord?=self.Records[player]; if record==nil then return end
	for _,connection in record.CharacterConnections do connection:Disconnect() end
	table.clear(record.CharacterConnections)
end

function Service._createPart(_self:any,name:string,shape:Enum.PartType,size:Vector3,cframe:CFrame,parent:Model):Part
	local part=Instance.new("Part"); part.Name=name; part.Shape=shape; part.Size=size; part.CFrame=cframe
	part.Transparency=if Config.CollisionCapsule.DebugVisible then .65 else Config.CollisionCapsule.Transparency
	part.Color=Color3.fromRGB(255,170,0); part.Material=Enum.Material.SmoothPlastic
	part.Anchored=false; part.Massless=true; part.CanCollide=true; part.CanTouch=false; part.CanQuery=false
	part.CastShadow=false; part.CollisionGroup=Config.CollisionCapsule.CollisionGroup
	part.CustomPhysicalProperties=PhysicalProperties.new(.01,0,0,0,0)
	part:SetAttribute("CharacterCollisionCapsulePart",true); part.Parent=parent; return part
end

function Service._character(self:any,player:Player,character:Model)
	self:_cleanupCharacter(player); if not Config.CollisionCapsule.Enabled then return end
	local record:PlayerRecord?=self.Records[player]; if record==nil then return end
	local rootValue=character:WaitForChild("HumanoidRootPart",10); local humanoidValue=character:WaitForChild("Humanoid",10)
	if not rootValue or not rootValue:IsA("BasePart") or not humanoidValue or not humanoidValue:IsA("Humanoid") then warn(`[CharacterCollisionService] {player.Name} is missing HumanoidRootPart or Humanoid`); return end
	local root:BasePart=rootValue
	local old=character:FindFirstChild("CollisionCapsule"); if old then old:Destroy() end
	local capsule=Instance.new("Model"); capsule.Name="CollisionCapsule"; capsule:SetAttribute("CharacterCollisionCapsule",true); capsule.Parent=character
	local radius:number=Config.CollisionCapsule.Radius; local height:number=Config.CollisionCapsule.CylinderHeight; local offset:Vector3=Config.CollisionCapsule.CenterOffset
	local center=root.CFrame*CFrame.new(offset)
	local cylinder=self:_createPart("Body",Enum.PartType.Cylinder,Vector3.new(height,radius*2,radius*2),center*CFrame.Angles(0,0,math.pi*.5),capsule)
	local top=self:_createPart("Top",Enum.PartType.Ball,Vector3.one*(radius*2),center*CFrame.new(0,height*.5,0),capsule)
	local bottom=self:_createPart("Bottom",Enum.PartType.Ball,Vector3.one*(radius*2),center*CFrame.new(0,-height*.5,0),capsule)
	for _,part in {cylinder,top,bottom} do weld(root,part) end
	for _,descendant in character:GetDescendants() do if descendant:IsA("BasePart") and descendant:GetAttribute("CharacterCollisionCapsulePart")~=true then configureVisualPart(descendant) end end
	table.insert(record.CharacterConnections,character.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") and descendant:GetAttribute("CharacterCollisionCapsulePart")~=true then configureVisualPart(descendant) end
	end))
	table.insert(record.CharacterConnections,character.AncestryChanged:Connect(function(_,parent) if parent==nil then self:_cleanupCharacter(player) end end))
end

function Service._player(self:any,player:Player)
	self:_remove(player); local record:PlayerRecord={Connections={},CharacterConnections={}}; self.Records[player]=record
	table.insert(record.Connections,player.CharacterAdded:Connect(function(character) self:_character(player,character) end))
	table.insert(record.Connections,player.CharacterRemoving:Connect(function() self:_cleanupCharacter(player) end))
	local character=player.Character; if character then task.defer(function() self:_character(player,character) end) end
end

function Service._remove(self:any,player:Player)
	local record:PlayerRecord?=self.Records[player]; if record==nil then return end
	self:_cleanupCharacter(player); for _,connection in record.Connections do connection:Disconnect() end; self.Records[player]=nil
end

function Service.Start(self:any)
	pcall(function() PhysicsService:RegisterCollisionGroup(Config.CollisionCapsule.CollisionGroup) end)
	PhysicsService:CollisionGroupSetCollidable(Config.CollisionCapsule.CollisionGroup,Config.CollisionCapsule.CollisionGroup,false)
	Players.PlayerAdded:Connect(function(player) self:_player(player) end); Players.PlayerRemoving:Connect(function(player) self:_remove(player) end)
	for _,player in Players:GetPlayers() do self:_player(player) end
end

return Service
