--!strict
local Players=game:GetService("Players")
local CollectionService=game:GetService("CollectionService")
local Tracker={}; Tracker.__index=Tracker
function Tracker.new(lifecycle:any,config:any): any return setmetatable({Lifecycle=lifecycle,Config=config,Indexes={} :: {[Player]: number},CharacterConnections={} :: {[Player]: RBXScriptConnection},Run=nil :: any?},Tracker) end
function Tracker.SetRun(self:any,run:any?) self.Run=run end
function Tracker._clear(self:any,player:Player)
	local old=self.Indexes[player]
	if self.Run and old and self.Run.ActiveRooms[old] then self.Lifecycle:PlayerExited(self.Run.ActiveRooms[old],player) end
	self.Indexes[player]=nil; player:SetAttribute("RoomIndex",nil)
end
function Tracker._set(self:any,player:Player,index:number)
	local old=self.Indexes[player]; if old==index then return end
	if self.Run and old and self.Run.ActiveRooms[old] then self.Lifecycle:PlayerExited(self.Run.ActiveRooms[old],player) end
	self.Indexes[player]=index; player:SetAttribute("RoomIndex",index)
	if self.Run and self.Run.ActiveRooms[index] then self.Lifecycle:PlayerEntered(self.Run.ActiveRooms[index],player) end
end
function Tracker.Start(self:any)
	local function added(player:Player)
		self:_set(player,if self.Run then self.Run.CurrentRoomIndex else 0)
		self.CharacterConnections[player]=player.CharacterAdded:Connect(function(character) self:_set(player,if self.Run then self.Run.CurrentRoomIndex else 0); local humanoidInstance=character:WaitForChild("Humanoid"); if not humanoidInstance:IsA("Humanoid") then return end; humanoidInstance.Died:Once(function() self:_clear(player) end) end)
	end
	for _,p in Players:GetPlayers() do added(p) end; Players.PlayerAdded:Connect(added); Players.PlayerRemoving:Connect(function(p) self:_clear(p); local c=self.CharacterConnections[p]; if c then c:Disconnect() end; self.CharacterConnections[p]=nil end)
	local function bind(trigger:Instance)
		if not trigger:IsA("BasePart") then return end
		trigger.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character or not character:IsA("Model") then return end
			local player=Players:GetPlayerFromCharacter(character); if not player then return end
			local cursor:Instance?=trigger
			while cursor do
				local index=cursor:GetAttribute("RoomIndex"); if typeof(index)=="number" then self:MarkEntered(player,index); return end
				cursor=cursor.Parent
			end
		end)
	end
	for _,trigger in CollectionService:GetTagged("RoomTrigger") do bind(trigger) end
	CollectionService:GetInstanceAddedSignal("RoomTrigger"):Connect(bind)
end
function Tracker.MarkEntered(self:any,player:Player,index:number) if not self.Run or not self.Run.ActiveRooms[index] then return end; self:_set(player,index) end
function Tracker.GetLowestActive(self:any,defaultIndex:number):number
	local lowest: number?=nil
	for player,index in self.Indexes do
		local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
		if player.Parent==Players and humanoid and humanoid.Health>0 then lowest=math.min(lowest or index,index) end
	end
	return lowest or defaultIndex
end
return Tracker
