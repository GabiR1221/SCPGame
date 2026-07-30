--[[ Scripted by coolcapidog
Channel ->> https://www.youtube.com/c/coolcapidog
Don't change anything except you know how to script.
]]
local PlaceID = 0
local MaxPlayerCount = 4

local TeleportService = game:GetService("TeleportService")

script.Parent:WaitForChild("GuiPart").Touched:Connect(function(touchpart)
	if game.Players:FindFirstChild(touchpart.Parent.Name) then
		if not script.PlayersWillTeleport:FindFirstChild(touchpart.Parent.Name) and script.Parent.GuiPart.CountGui.PlayerCount.Text ~= MaxPlayerCount.."/"..MaxPlayerCount then
			touchpart.Parent:SetPrimaryPartCFrame(script.Parent.ElevatorTeleportPart.CFrame)
			local Plr = game.Players:FindFirstChild(touchpart.Parent.Name)
			local ExitScreenGui = script.ExitScreenGui:Clone()
			ExitScreenGui.Parent = Plr.PlayerGui
			ExitScreenGui.camscript.Disabled = false
			local PlayerValue = Instance.new("ObjectValue")
			PlayerValue.Name = touchpart.Parent.Name
			PlayerValue.Value = Plr
			PlayerValue.Parent = script.PlayersWillTeleport
			ExitScreenGui.ExitButton.MouseButton1Click:Connect(function()
				ExitScreenGui:Destroy()
				local camscript2 = script.camscript2:Clone()
				camscript2.Parent = Plr.PlayerGui
				camscript2.Disabled = false
				touchpart.Parent:SetPrimaryPartCFrame(script.Parent.TeleportOut.CFrame)
				PlayerValue:Destroy()
			end)
		end
	end
end)

while true do
	script.PlayersWillTeleport:ClearAllChildren()
	local timer = 30
	repeat
		wait(1)
		timer -= 1
		local plrs = 0
		for i, plr in pairs(script.PlayersWillTeleport:GetChildren()) do
			plrs += 1
		end
		script.Parent.GuiPart.TimerGui.Timer.Text = timer
		script.Parent.GuiPart.CountGui.PlayerCount.Text = plrs.."/"..MaxPlayerCount
	until timer == 0
	local PlayersWillTeleport = {}
	local PlayersCount = 0
	for i, plr in pairs(script.PlayersWillTeleport:GetChildren()) do
		if plr.Value ~= nil then
			table.insert(PlayersWillTeleport, plr.Value)
			PlayersCount += 1
		end
	end
	if PlayersCount > 0 then
		local ServerCode = TeleportService:ReserveServer(PlaceID)
		TeleportService:TeleportToPrivateServer(PlaceID, ServerCode, PlayersWillTeleport)
	end
end
