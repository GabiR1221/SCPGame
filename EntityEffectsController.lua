--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/EntityEffectsController
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local C={}; C.__index=C
function C.new(camera:any):any return setmetatable({Camera=camera},C) end
function C.Start(self:any) local event=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EntityEvent") :: RemoteEvent; event.OnClientEvent:Connect(function(message:any) local id=message.WarningSoundId; if typeof(id)=="string" and id~="rbxassetid://0" then local sound=Instance.new("Sound"); sound.SoundId=id; sound.Parent=workspace.CurrentCamera; sound:Play(); sound.Ended:Once(function() sound:Destroy() end) end; self.Camera:AddShake(Vector3.new(.015,.01,0)) end) end
return C
