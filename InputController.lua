--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/InputController
local ContextActionService=game:GetService("ContextActionService")
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local LocalPlayer=Players.LocalPlayer :: Player
local CrouchRequest=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CrouchRequest") :: RemoteEvent

local Controller={}
local function crouchAction(_name:string,state:Enum.UserInputState,_input:InputObject):Enum.ContextActionResult
	if state~=Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local character=LocalPlayer.Character; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid then CrouchRequest:FireServer(humanoid:GetAttribute("Crouched")~=true) end
	return Enum.ContextActionResult.Sink
end

function Controller.Start(firstPerson:any)
	ContextActionService:BindAction("ToggleCrouch",crouchAction,true,Enum.KeyCode.C,Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("ToggleCrouch","Crouch")
	ContextActionService:BindAction("ToggleFirstPersonTest",function(_name:string,state:Enum.UserInputState,_input:InputObject)
		if state==Enum.UserInputState.Begin then firstPerson:ToggleForTesting(); return Enum.ContextActionResult.Sink end
		return Enum.ContextActionResult.Pass
	end,false,Enum.KeyCode.V)
end
return Controller
