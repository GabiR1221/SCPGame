--!strict
-- ModuleScript: ServerScriptService/Services/LootService
local CollectionService=game:GetService("CollectionService")
local Players=game:GetService("Players")
local ServerStorage=game:GetService("ServerStorage")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Config:any=require(ReplicatedStorage.Shared.LootConfig).DrawerLoot
local S={}; S.__index=S
type PickupRecord={Drawer:Instance,RoomIndex:number,ToolId:string,Claimed:boolean}
local function hash(seed:number,room:number,index:number,id:string):number local value=(seed*1103515245+room*1664525+index*1013904223)%2147483647; for i=1,#id do value=(value*33+string.byte(id,i))%2147483647 end; return math.max(1,value) end
function S.new(tools:any,hiding:any):any return setmetatable({Tools=tools,Hiding=hiding,Pickups={} :: {[Instance]:PickupRecord},Rooms={} :: {[number]:{Instance}},Rates={} :: {[Player]:number}},S) end
function S._spawn(self:any,room:any,drawer:Instance,definition:any):boolean
	local spawnValue=drawer:FindFirstChild("LootSpawn",true); local drawerPart=drawer:FindFirstChild("Drawer",true)
	if not spawnValue or not spawnValue:IsA("Attachment") then warn(`[LootService] {drawer:GetFullName()} is loot-enabled but has no LootSpawn Attachment`); return false end
	if not drawerPart or not drawerPart:IsA("BasePart") then warn(`[LootService] {drawer:GetFullName()} is loot-enabled but has no Drawer BasePart`); return false end
	local templates=ServerStorage:FindFirstChild("PickupTemplates"); local template=if templates then templates:FindFirstChild(definition.PickupTemplate) else nil; if not template or not template:IsA("Model") then warn(`[LootService] Missing ServerStorage.PickupTemplates.{definition.PickupTemplate} Model`); return false end
	local clone=template:Clone(); clone.Name="WorldPickup"; local root=clone:FindFirstChild("PickupRoot",true); if not root or not root:IsA("BasePart") then clone:Destroy(); warn(`[LootService] {template:GetFullName()} needs PickupRoot BasePart`); return false end; clone.PrimaryPart=root
	local parts:{BasePart}={}; for _,item in clone:GetDescendants() do if item:IsA("LuaSourceContainer") then item:Destroy() elseif item:IsA("BasePart") then item.Anchored=true; item.CanCollide=false; item.CanTouch=false; item.CanQuery=true; item.Massless=true; table.insert(parts,item) end end
	clone:PivotTo(spawnValue.WorldCFrame); clone.Parent=drawer
	-- Weld every visual part, not only PickupRoot. Otherwise unwelded visuals
	-- fall through the drawer as soon as they are unanchored and appear missing.
	for _,part in parts do if part~=root then local visualWeld=Instance.new("WeldConstraint"); visualWeld.Part0=root; visualWeld.Part1=part; visualWeld.Parent=part end end
	local drawerWeld=Instance.new("WeldConstraint"); drawerWeld.Part0=drawerPart; drawerWeld.Part1=root; drawerWeld.Parent=root
	for _,part in parts do part.Anchored=false end
	clone:SetAttribute("InteractionId","PickupTool"); clone:SetAttribute("InteractionText","Pick up"); clone:SetAttribute("Enabled",drawer:GetAttribute("Opened")==true); clone:SetAttribute("RoomIndex",room.Index)
	CollectionService:AddTag(clone,"Interactable"); self.Pickups[clone]={Drawer=drawer,RoomIndex=room.Index,ToolId=definition.ToolId,Claimed=false}; table.insert(self.Rooms[room.Index],clone)
	if Config.Debug.PrintRolls then print(`[LootService] spawned {definition.ToolId} in {drawer:GetFullName()}`) end; return true
end
function S.RegisterRoom(self:any,room:any)
	if self.Rooms[room.Index] then return end; self.Rooms[room.Index]={}; if not Config.Enabled or room.Index<Config.MinimumRoom or room.Index>Config.MaximumRoom then return end
	local drawers:{Instance}={}; for _,value in room.Model:GetDescendants() do if value:GetAttribute("CanSpawnLoot")==true then if typeof(value:GetAttribute("LootIndex"))=="number" then table.insert(drawers,value) else warn(`[LootService] {value:GetFullName()} has CanSpawnLoot=true but no numeric LootIndex`) end end end; table.sort(drawers,function(a,b) return (a:GetAttribute("LootIndex") :: number)<(b:GetAttribute("LootIndex") :: number) end)
	if Config.Debug.PrintRolls then print(`[LootService] room={room.Index} discovered {#drawers} loot drawer(s)`) end
	local spawned=0; for _,drawer in drawers do if spawned>=Config.MaximumToolSpawnsPerRoom then break end; local index=drawer:GetAttribute("LootIndex") :: number; local random=Random.new(hash(room.Seed,room.Index,index,Config.PoolId)); local chanceRoll=random:NextNumber(); local passed=Config.Debug.ForceSpawn or chanceRoll<=Config.BaseSpawnChance; if Config.Debug.PrintRolls then print(`[LootService] room={room.Index} drawer={index} roll={chanceRoll} chance={Config.BaseSpawnChance} passed={passed}`) end; if passed then local eligible={}; local total=0; for _,entry:any in Config.Pool do if room.Index>=entry.MinimumRoom and room.Index<=entry.MaximumRoom and entry.Weight>0 then total+=entry.Weight; table.insert(eligible,entry) end end; if total>0 then local roll=random:NextNumber()*total; local selected=nil; for _,entry:any in eligible do roll-=entry.Weight; if roll<=0 then selected=entry; break end end; if selected and self:_spawn(room,drawer,selected) then spawned+=1 end end end end
end
function S.SetDrawerOpen(self:any,drawer:Instance,open:boolean) local pickup=drawer:FindFirstChild("WorldPickup"); if pickup and self.Pickups[pickup] then pickup:SetAttribute("Enabled",open) end end
function S.Collect(self:any,player:Player,pickup:Instance)
	local now=workspace:GetServerTimeNow(); if now<(self.Rates[player] or 0) then if Config.Debug.PrintRolls then warn(`[LootService] pickup rejected for {player.Name}: RateLimited`) end; return end
	local record:PickupRecord?=self.Pickups[pickup]
	if not record or record.Claimed or not pickup:IsDescendantOf(workspace) or record.Drawer:GetAttribute("Opened")~=true or self.Hiding:IsHidden(player) then return end
	self.Rates[player]=now+.25
	local character=player.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
	local reason:string?=nil
	if not humanoid or humanoid.Health<=0 then reason="NotAlive" elseif self.Tools:GetToolCount(player)>=Config.MaxBackpackTools then reason="InventoryFull" elseif not Config.AllowDuplicateOwnedTools and self.Tools:HasTool(player,record.ToolId) then reason="DuplicateTool" end
	if reason then if Config.Debug.PrintRolls then warn(`[LootService] pickup rejected for {player.Name}: {reason}`) end; return end
	record.Claimed=true; pickup:SetAttribute("Enabled",false); local success,grantReason=self.Tools:GiveTool(player,record.ToolId,{AllowDuplicate=Config.AllowDuplicateOwnedTools,AutoEquip=Config.AutoEquipOnPickup}); if success then self.Pickups[pickup]=nil; pickup:Destroy() else if Config.Debug.PrintRolls then warn(`[LootService] ToolService refused {record.ToolId} for {player.Name}: {grantReason or "Unknown"}`) end; record.Claimed=false; if record.Drawer:GetAttribute("Opened")==true then pickup:SetAttribute("Enabled",true) end end
end
function S.UnregisterRoom(self:any,room:any) local list=self.Rooms[room.Index]; if not list then return end; for _,pickup in list do self.Pickups[pickup]=nil; if pickup.Parent then pickup:Destroy() end end; self.Rooms[room.Index]=nil end
function S.Start(self:any) Players.PlayerRemoving:Connect(function(player) self.Rates[player]=nil end) end
return S
