--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/CameraController

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
if player == nil then error("CameraController must run on the client") end
local LocalPlayer: Player = player
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterConfig"))
local FirstPerson = require(script.Parent:WaitForChild("FirstPersonController"))

local Controller = {}
local mode = "Gameplay"
local owner: string? = nil
local baseFov: number = Config.Camera.DefaultFov
local targetFov: number = Config.Camera.DefaultFov
local scriptCFrame: CFrame? = nil
local shake = Vector3.zero
local bobClock = 0
-- Smooth only the small eye-relative clearance offset. Smoothing the complete
-- world position makes the camera lag behind a rapidly bending Head, briefly
-- exposing the local neck during quick pitch reversals.
local smoothedEyeOffset: Vector3? = nil
local character: Model? = nil
local head: BasePart? = nil
local lastHorizontalForward = Vector3.new(0, 0, -1)
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function resetSmoothing()
	smoothedEyeOffset = nil
end

local function bindCharacter(newCharacter: Model?)
	character = newCharacter
	head = nil
	if newCharacter then
		local foundHead = newCharacter:FindFirstChild("Head")
		if foundHead and foundHead:IsA("BasePart") then head = foundHead end
	end
	raycastParams.FilterDescendantsInstances = if newCharacter then {newCharacter} else {}
	resetSmoothing()
end

local function horizontalForward(cameraCFrame: CFrame): Vector3
	local look = cameraCFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > Config.FirstPersonBody.HorizontalDirectionEpsilon then return flatLook.Unit end
	local right = cameraCFrame.RightVector
	local flatRight = Vector3.new(right.X, 0, right.Z)
	if flatRight.Magnitude > Config.FirstPersonBody.HorizontalDirectionEpsilon then
		return Vector3.new(flatRight.Z, 0, -flatRight.X).Unit
	end
	return lastHorizontalForward
end

local function poseAwarePosition(cameraCFrame: CFrame, dt: number): Vector3?
	if not Config.PoseAwareCamera.Enabled or not FirstPerson:IsEnabled() then resetSmoothing(); return nil end
	local activeCharacter = LocalPlayer.Character
	if activeCharacter == nil then resetSmoothing(); return nil end
	if activeCharacter ~= character then bindCharacter(activeCharacter) end
	local activeHead = head
	if activeHead == nil or activeHead.Parent == nil then
		local foundHead = activeCharacter:FindFirstChild("Head")
		if foundHead and foundHead:IsA("BasePart") then head = foundHead; activeHead = foundHead end
	end
	if activeHead == nil then resetSmoothing(); return nil end
	local pitch: number = math.clamp(FirstPerson:GetLookPitch(), -Config.LookBend.MaximumPitch, Config.LookBend.MaximumPitch)
	local downAmount = math.clamp(-pitch / Config.LookBend.MaximumPitch, 0, 1)
	local upAmount = math.clamp(pitch / Config.LookBend.MaximumPitch, 0, 1)
	lastHorizontalForward = horizontalForward(cameraCFrame)
	local eyePosition = activeHead.CFrame:PointToWorldSpace(Config.PoseAwareCamera.EyeLocalOffset)
	local clearance: number = Config.PoseAwareCamera.BaseForwardClearance
		+ Config.PoseAwareCamera.DownForwardBonus * downAmount
		+ Config.PoseAwareCamera.UpForwardBonus * upAmount
	local vertical: number = Config.PoseAwareCamera.DownVerticalCompensation * downAmount
		+ Config.PoseAwareCamera.UpVerticalCompensation * upAmount
	local targetOffset = lastHorizontalForward * clearance + Vector3.yAxis * vertical
	local previousOffset = smoothedEyeOffset
	local eyeOffset = if previousOffset
		then previousOffset:Lerp(targetOffset, 1 - math.exp(-Config.PoseAwareCamera.PositionSmoothSpeed * dt))
		else targetOffset
	smoothedEyeOffset = eyeOffset
	local desired = eyePosition + eyeOffset
	if Config.PoseAwareCamera.PreventWallClipping then
		raycastParams.FilterDescendantsInstances = {activeCharacter}
		local displacement = desired - eyePosition
		local hit = workspace:Raycast(eyePosition, displacement, raycastParams)
		if hit then
			local allowed = math.max(0, hit.Distance - Config.PoseAwareCamera.WallPadding)
			desired = eyePosition + displacement.Unit * allowed
		end
	end
	return desired
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if camera == nil then resetSmoothing(); return end
	camera.FieldOfView += (targetFov - camera.FieldOfView) * (1 - math.exp(-8 * dt))
	local scripted = scriptCFrame
	if scripted then
		resetSmoothing(); camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = scripted * CFrame.Angles(shake.X, shake.Y, shake.Z)
	elseif mode == "Gameplay" then
		camera.CameraType = Enum.CameraType.Custom
		local baseCFrame = camera.CFrame
		local position = poseAwarePosition(baseCFrame, dt)
		if position then camera.CFrame = CFrame.new(position) * baseCFrame.Rotation end
		if Config.PoseAwareCamera.UseSyntheticHeadBob and Config.Camera.HeadBobEnabled then
			local activeCharacter = LocalPlayer.Character
			local humanoid = if activeCharacter then activeCharacter:FindFirstChildOfClass("Humanoid") else nil
			if humanoid and humanoid.MoveDirection.Magnitude > .1 and humanoid.FloorMaterial ~= Enum.Material.Air then
				bobClock += dt * Config.Camera.HeadBobFrequency
				camera.CFrame *= CFrame.new(0, math.sin(bobClock) * Config.Camera.HeadBobAmount, 0)
			end
		end
		camera.CFrame *= CFrame.Angles(shake.X, shake.Y, shake.Z)
	end
	shake = shake:Lerp(Vector3.zero, 1 - math.exp(-12 * dt))
end

function Controller.new()
	return Controller
end
function Controller.Acquire(_self: unknown, requestedOwner: string, requestedMode: string): boolean
	if owner and owner ~= requestedOwner then return false end
	owner = requestedOwner; mode = requestedMode; resetSmoothing(); return true
end
function Controller.Release(self: unknown, requestedOwner: string)
	if owner ~= requestedOwner then return end
	owner = nil; Controller.Restore(self)
end
function Controller.SetScriptCFrame(_self: unknown, requestedOwner: string, value: CFrame?) if owner == requestedOwner then scriptCFrame = value end end
function Controller.SetFov(_self: unknown, requestedOwner: string, value: number) if not owner or owner == requestedOwner then targetFov = math.clamp(value, 30, 100) end end
function Controller.AddShake(_self: unknown, amount: Vector3) if Config.Camera.ShakeEnabled then shake += amount end end
function Controller.Restore(_self: unknown)
	mode = "Gameplay"; scriptCFrame = nil; targetFov = baseFov; resetSmoothing()
	local camera = workspace.CurrentCamera
	if camera then camera.CameraType = Enum.CameraType.Custom; local activeCharacter = LocalPlayer.Character; camera.CameraSubject = if activeCharacter then activeCharacter:FindFirstChildOfClass("Humanoid") else nil end
end
function Controller.Start(_self: unknown)
	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson; bindCharacter(LocalPlayer.Character)
	RunService:BindToRenderStep("CentralCamera", Enum.RenderPriority.Camera.Value + 2, step)
	LocalPlayer.CharacterAdded:Connect(function(newCharacter: Model) bindCharacter(newCharacter); owner = nil; Controller.Restore(Controller) end)
	LocalPlayer.CharacterRemoving:Connect(function() bindCharacter(nil); owner = nil; mode = "Death"; scriptCFrame = nil end)
end
function Controller.Destroy(_self: unknown) RunService:UnbindFromRenderStep("CentralCamera"); Controller.Restore(Controller) end

return Controller
