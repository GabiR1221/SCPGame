--localscript in StarterPlayerScripts in Controllers folder
--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
-- Streaming-safe: server messages contain state only; the room may stream in later.
ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DoorStateChanged").OnClientEvent:Connect(function(_roomIndex:number,_opened:boolean)
	-- Subscribe cosmetic UI/camera effects here. Never award or generate gameplay here.
end)
