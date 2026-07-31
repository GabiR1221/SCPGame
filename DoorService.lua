--Modulescript in Services folder in ServerScriptService
--!strict
local CollectionService=game:GetService("CollectionService")
local Players=game:GetService("Players")
local DoorService={}; DoorService.__index=DoorService
function DoorService.new(runManager:any,tracker:any,remote:RemoteEvent,generatedRooms:Folder): any return setmetatable({RunManager=runManager,Tracker=tracker,Remote=remote,GeneratedRooms=generatedRooms,Connections={} :: {[ProximityPrompt]: RBXScriptConnection},Busy={} :: {[Instance]: boolean}},DoorService) end
function DoorService._roomFor(_self:any,instance:Instance):Model? local cursor:Instance?=instance; while cursor do if cursor:IsA("Model") and typeof(cursor:GetAttribute("RoomIndex"))=="number" then return cursor end; cursor=cursor.Parent end; return nil end
function DoorService._tryOpen(self:any,player:Player,door:Instance)
	if not player:IsDescendantOf(Players) or self.Busy[door] then return end
	local run=self.RunManager:GetState(); local roomModel=self:_roomFor(door); if not run or not roomModel then return end
	if not run.IsReady then warn("[DoorService] ignored prompt because the run did not finish pre-generating; check the earlier RoomSelector/RoomGenerator error"); return end
	local index=roomModel:GetAttribute("RoomIndex")::number
	if index~=run.CurrentRoomIndex then return end
	local rootInstance=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local root: BasePart?=if rootInstance and rootInstance:IsA("BasePart") then rootInstance else nil
	local foundDoorPart=if door:IsA("BasePart") then door else door:FindFirstChildWhichIsA("BasePart")
	local doorPart: BasePart?=if foundDoorPart and foundDoorPart:IsA("BasePart") then foundDoorPart else nil
	if not root or not doorPart or (root.Position-doorPart.Position).Magnitude>16 then return end
	self.Busy[door]=true; door:SetAttribute("Opened",true)
	local ok,err=pcall(function() self.RunManager:Advance(player,index); self.Remote:FireAllClients(index,true) end)
	if not ok then self.Busy[door]=nil; door:SetAttribute("Opened",false); warn(`[DoorService] {err}`) end
end
function DoorService._bind(self:any,door:Instance)
	-- CollectionService also returns tagged template instances in ServerStorage. Only
	-- runtime clones inside GeneratedRooms are interactive and should be connected.
	if not door:IsDescendantOf(self.GeneratedRooms) then return end
	local doorContainer: Instance=door
	local prompt: ProximityPrompt?
	if door:IsA("ProximityPrompt") then
		-- Be forgiving if Tag Editor accidentally tagged the prompt instead of its Part.
		prompt=door; if door.Parent then doorContainer=door.Parent end
	else
		local found=door:FindFirstChildWhichIsA("ProximityPrompt",true)
		if found and found:IsA("ProximityPrompt") then prompt=found end
	end
	if not prompt then warn(`[DoorService] generated tagged door {door:GetFullName()} needs a descendant ProximityPrompt`); return end
	if self.Connections[prompt] then return end
	self.Connections[prompt]=prompt.Triggered:Connect(function(player) self:_tryOpen(player,doorContainer) end)
end
function DoorService.Start(self:any)
	for _,door in CollectionService:GetTagged("Door") do self:_bind(door) end
	CollectionService:GetInstanceAddedSignal("Door"):Connect(function(door) task.defer(function() self:_bind(door) end) end)
	self.GeneratedRooms.DescendantAdded:Connect(function(instance) if CollectionService:HasTag(instance,"Door") then task.defer(function() self:_bind(instance) end) end end)
	CollectionService:GetInstanceRemovedSignal("Door"):Connect(function(instance)
		local prompt=if instance:IsA("ProximityPrompt") then instance else instance:FindFirstChildWhichIsA("ProximityPrompt",true)
		if prompt and prompt:IsA("ProximityPrompt") then local connection: RBXScriptConnection?=self.Connections[prompt]; if connection then connection:Disconnect() end; self.Connections[prompt]=nil end
		self.Busy[instance]=nil
	end)
end
return DoorService
