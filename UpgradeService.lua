--!strict
-- ModuleScript: ServerScriptService/Services/UpgradeService
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local shared=ReplicatedStorage:WaitForChild("Shared")
local upgradeConfigModule=shared:WaitForChild("UpgradeConfig")
assert(upgradeConfigModule:IsA("ModuleScript"),"ReplicatedStorage.Shared.UpgradeConfig must be a ModuleScript")
local Config:any=require(upgradeConfigModule)
local Service={}; Service.__index=Service
type Record={TreeId:string,Coins:number,Owned:{[string]:number}}

function Service.new(request:RemoteEvent,stateRemote:RemoteEvent):any
	return setmetatable({Request=request,StateRemote=stateRemote,Records={} :: {[Player]:Record}},Service)
end
function Service._snapshot(self:any,player:Player):any
	local record:Record?=self.Records[player]; if not record then return nil end
	local owned:{[string]:number}={}; for id,level in record.Owned do owned[id]=level end
	return {TreeId=record.TreeId,Coins=record.Coins,Owned=owned}
end
function Service._publish(self:any,player:Player,message:string?) self.StateRemote:FireClient(player,self:_snapshot(player),message) end
function Service._add(self:any,player:Player)
	local treeId:string=Config.Testing.SelectedTreeId
	if Config.Trees[treeId]==nil then warn(`[UpgradeService] unknown testing tree {treeId}; player has no purchasable tree`) end
	self.Records[player]={TreeId=treeId,Coins=math.max(0,math.floor(Config.Testing.StartingCoins)),Owned={}}
	player:SetAttribute("SelectedUpgradeTree",treeId); player:SetAttribute("RunCoins",self.Records[player].Coins); self:_publish(player)
end
function Service.Purchase(self:any,player:Player,upgradeId:unknown)
	if typeof(upgradeId)~="string" or #upgradeId>64 then if Config.Testing.Debug then warn(`[UpgradeService] rejected malformed purchase request from {player.Name}`) end; return end
	if upgradeId=="__Sync" then self:_publish(player); return end
	local record:Record?=self.Records[player]; if not record then return end
	local tree:any=Config.Trees[record.TreeId]; local upgrade:any=if tree then tree.Upgrades[upgradeId] else nil
	if not upgrade then self:_publish(player,"InvalidUpgrade"); return end
	local current=record.Owned[upgradeId] or 0; local maxLevel=upgrade.MaxLevel or 1
	if current>=maxLevel then self:_publish(player,"AlreadyOwned"); return end
	for _,requiredId:string in upgrade.Prerequisites do if (record.Owned[requiredId] or 0)<=0 then self:_publish(player,"MissingPrerequisite"); return end end
	if record.Coins<upgrade.Price then self:_publish(player,"NotEnoughCoins"); return end
	record.Coins-=upgrade.Price; record.Owned[upgradeId]=current+1; player:SetAttribute("RunCoins",record.Coins); self:_publish(player,"Purchased")
	if Config.Testing.Debug then print(`[UpgradeService] {player.Name} purchased {upgradeId}; coins={record.Coins}`) end
end
function Service.GetTreeId(self:any,player:Player):string? local r:Record?=self.Records[player]; return if r then r.TreeId else nil end
function Service.GetEffects(self:any,player:Player):{[string]:number}
	local result:{[string]:number}={}
	local record:Record?=self.Records[player]
	if not record then return result end
	local tree:any=Config.Trees[record.TreeId]
	if not tree then return result end
	for id,level in record.Owned do
		local upgrade:any=tree.Upgrades[id]
		if upgrade then
			for effect,value in upgrade.Effects do
				if typeof(value)=="number" then
					if string.find(effect,"Multiplier",1,true) then
						result[effect]=(result[effect] or 1)*(value^level)
					else
						result[effect]=(result[effect] or 0)+(value*level)
					end
				end
			end
		end
	end
	return result
end
function Service.Start(self:any)
	self.Request.OnServerEvent:Connect(function(player:Player,id:unknown) self:Purchase(player,id) end)
	Players.PlayerAdded:Connect(function(player) self:_add(player) end); Players.PlayerRemoving:Connect(function(player) self.Records[player]=nil end)
	for _,player in Players:GetPlayers() do self:_add(player) end
end
return Service
