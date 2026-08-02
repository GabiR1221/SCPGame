--!strict
-- ModuleScript: ServerScriptService/Services/LookPoseService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterConfig"))

type RateState = {LastAccepted: number, Sequence: number}
local rates: {[Player]: RateState} = {}
local Service = {}

local function acceptRate(player: Player, now: number): RateState?
	local existing = rates[player]
	local rate: RateState
	if existing then rate = existing else rate = {LastAccepted=-math.huge, Sequence=0}; rates[player] = rate end
	if now - rate.LastAccepted < 1 / Config.LookPoseReplication.MaximumAcceptedUpdatesPerSecond then return nil end
	rate.LastAccepted = now
	return rate
end

function Service.Start(remote: UnreliableRemoteEvent)
	remote.OnServerEvent:Connect(function(player: Player, value: unknown)
		if not Config.LookPoseReplication.Enabled or typeof(value) ~= "number" then return end
		if value ~= value or value <= -math.huge or value >= math.huge then return end
		local activeCharacter = player.Character
		local humanoid = if activeCharacter then activeCharacter:FindFirstChildOfClass("Humanoid") else nil
		if activeCharacter == nil or humanoid == nil or humanoid.Health <= 0 then return end
		local rate = acceptRate(player, os.clock())
		if rate == nil then return end
		local sequence: number = rate.Sequence + 1
		rate.Sequence = sequence
		local pitch = math.clamp(value, -Config.LookBend.MaximumPitch, Config.LookBend.MaximumPitch)
		remote:FireAllClients(player, pitch, sequence)
	end)
	Players.PlayerRemoving:Connect(function(player: Player) rates[player] = nil end)
end

return Service
