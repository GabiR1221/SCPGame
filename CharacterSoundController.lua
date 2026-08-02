--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CharacterSoundController
-- Roblox's character sound controller creates Running independently of Animate.
local Players = game:GetService("Players")

local Config = table.freeze({
	DefaultCharacterSounds = table.freeze({SuppressedNames = table.freeze({Running = true})}),
})

local Controller = {}
Controller.__index = Controller

type PlayerRecord = {Connections: {RBXScriptConnection}, CharacterConnections: {RBXScriptConnection}}

function Controller.new(): any
	return setmetatable({Records = {} :: {[Player]: PlayerRecord}}, Controller)
end

local function suppress(instance: Instance)
	local parent=instance.Parent
	if not instance:IsA("Sound") or instance.Name~="Running" or not Config.DefaultCharacterSounds.SuppressedNames.Running or parent==nil or parent.Name~="HumanoidRootPart" or not parent:IsA("BasePart") then return end
	instance:Stop()
	instance.SoundId = ""
end

function Controller._character(self: any, player: Player, character: Model)
	local record: PlayerRecord? = self.Records[player]
	if record == nil then return end
	for _, connection in record.CharacterConnections do connection:Disconnect() end
	table.clear(record.CharacterConnections)
	local function observe(instance:Instance)
		local parent=instance.Parent
		if not instance:IsA("Sound") or instance.Name~="Running" or not Config.DefaultCharacterSounds.SuppressedNames.Running or parent==nil or parent.Name~="HumanoidRootPart" or not parent:IsA("BasePart") then return end
		local sound:Sound=instance
		suppress(sound)
		table.insert(record.CharacterConnections,sound:GetPropertyChangedSignal("SoundId"):Connect(function() if sound.SoundId~="" then suppress(sound) end end))
		table.insert(record.CharacterConnections,sound:GetPropertyChangedSignal("Playing"):Connect(function() if sound.Playing then suppress(sound) end end))
	end
	for _, descendant in character:GetDescendants() do observe(descendant) end
	table.insert(record.CharacterConnections, character.DescendantAdded:Connect(observe))
end

function Controller._remove(self: any, player: Player)
	local record: PlayerRecord? = self.Records[player]
	if record == nil then return end
	for _, connection in record.Connections do connection:Disconnect() end
	for _, connection in record.CharacterConnections do connection:Disconnect() end
	self.Records[player] = nil
end

function Controller._player(self: any, player: Player)
	self:_remove(player)
	local record: PlayerRecord = {Connections = {}, CharacterConnections = {}}
	self.Records[player] = record
	table.insert(record.Connections, player.CharacterAdded:Connect(function(character) self:_character(player, character) end))
	table.insert(record.Connections, player.CharacterRemoving:Connect(function()
		for _, connection in record.CharacterConnections do connection:Disconnect() end
		table.clear(record.CharacterConnections)
	end))
	local character = player.Character
	if character ~= nil then self:_character(player, character) end
end

function Controller.Start(self: any)
	Players.PlayerAdded:Connect(function(player) self:_player(player) end)
	Players.PlayerRemoving:Connect(function(player) self:_remove(player) end)
	for _, player in Players:GetPlayers() do self:_player(player) end
end

return Controller
