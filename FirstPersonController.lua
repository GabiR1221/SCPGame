--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/FirstPersonController

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config: any = require(
	ReplicatedStorage
		:WaitForChild("Shared")
		:WaitForChild("CharacterConfig")
)

local LocalPlayer = Players.LocalPlayer :: Player

local Controller = {}
Controller.__index = Controller

local visibleParts: {[BasePart]: boolean} = {}

local characterConnections: {RBXScriptConnection} = {}
local lifecycleConnections: {RBXScriptConnection} = {}
local poseConnections: {RBXScriptConnection} = {}

local waist: Motor6D? = nil
local neck: Motor6D? = nil
local rootMotor: Motor6D? = nil

local humanoid: Humanoid? = nil
local rootPart: BasePart? = nil

local originalAutoRotate: boolean? = nil

local smoothedPitch = 0
local desiredBodyOffset = 0

local lastCameraForward = Vector3.new(0, 0, -1)
local nextDebugOutput = 0

local function findMotor(character: Model, name: string): Motor6D?
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Name == name then
			return descendant
		end
	end

	return nil
end

local function disconnectConnections(connections: {RBXScriptConnection})
	for _, connection in connections do
		connection:Disconnect()
	end

	table.clear(connections)
end

-- The flattened camera LookVector is normally authoritative.
--
-- When the camera is looking nearly straight up or down, its flattened
-- LookVector becomes too small to normalize reliably. In that situation,
-- the flattened RightVector is used to preserve the camera's horizontal yaw.
local function getHorizontalCameraForward(
	cameraCFrame: CFrame,
	fallback: Vector3
): Vector3
	local epsilon: number =
		Config.FirstPersonBody.HorizontalDirectionEpsilon

	local look = cameraCFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)

	if flatLook.Magnitude > epsilon then
		return flatLook.Unit
	end

	local right = cameraCFrame.RightVector
	local flatRight = Vector3.new(right.X, 0, right.Z)

	if flatRight.Magnitude > epsilon then
		return Vector3.new(
			flatRight.Z,
			0,
			-flatRight.X
		).Unit
	end

	local flatFallback = Vector3.new(
		fallback.X,
		0,
		fallback.Z
	)

	if flatFallback.Magnitude > epsilon then
		return flatFallback.Unit
	end

	return Vector3.new(0, 0, -1)
end

function Controller.new(): any
	return setmetatable({
		Enabled = true,
	}, Controller)
end

function Controller._restoreAutoRotate(_self: any)
	local activeHumanoid = humanoid
	local savedAutoRotate = originalAutoRotate

	originalAutoRotate = nil

	if activeHumanoid == nil then
		return
	end

	if activeHumanoid.Parent == nil then
		return
	end

	if savedAutoRotate == nil then
		return
	end

	activeHumanoid.AutoRotate = savedAutoRotate
end

function Controller._claimAutoRotate(self: any)
	if not self.Enabled then
		return
	end

	if not Config.FirstPersonBody.AlignCharacterYaw then
		return
	end

	local activeHumanoid = humanoid

	if activeHumanoid == nil then
		return
	end

	if activeHumanoid.Parent == nil then
		return
	end

	if originalAutoRotate == nil then
		originalAutoRotate = activeHumanoid.AutoRotate
	end

	-- This controller is the sole character-yaw owner during first person.
	activeHumanoid.AutoRotate = false
end

function Controller.SetEnabled(self: any, enabled: boolean)
	if self.Enabled and not enabled then
		self:_restoreAutoRotate()
	end

	self.Enabled = enabled

	LocalPlayer:SetAttribute(
		"FirstPersonEnabled",
		enabled
	)

	LocalPlayer.CameraMode =
		if enabled
		then Enum.CameraMode.LockFirstPerson
		else Enum.CameraMode.Classic

	if enabled then
		self:_claimAutoRotate()
		return
	end

	LocalPlayer.CameraMinZoomDistance = 0.5
	LocalPlayer.CameraMaxZoomDistance = 18

	smoothedPitch = 0
	desiredBodyOffset = 0

	self:_resetPose()
end

function Controller.ToggleForTesting(self: any)
	if not Config.TestingAllowFirstPersonToggle then
		return
	end

	self:SetEnabled(not self.Enabled)
end

function Controller._updateBody(self: any, dt: number)
	for part: BasePart in visibleParts do
		if part.Parent == nil then
			visibleParts[part] = nil
			continue
		end

		local isAccessoryPart =
			part:FindFirstAncestorOfClass("Accessory") ~= nil

		local hideInFirstPerson =
			part.Name == "Head"
			or isAccessoryPart

		part.LocalTransparencyModifier =
			if self.Enabled and hideInFirstPerson
			then 1
			else 0
	end

	if not self.Enabled then
		return
	end

	local camera = workspace.CurrentCamera

	if camera == nil then
		return
	end

	local cameraCFrame = camera.CFrame
	local look = cameraCFrame.LookVector

	local safeLookY = math.clamp(
		look.Y,
		-1,
		1
	)

	local pitch = math.clamp(
		math.asin(safeLookY),
		-Config.LookBend.MaximumPitch,
		Config.LookBend.MaximumPitch
	)

	local pitchAlpha = math.min(
		1,
		Config.LookBend.SmoothSpeed * dt
	)

	smoothedPitch +=
		(pitch - smoothedPitch) * pitchAlpha

	local downward = math.max(
		0,
		-look.Y
	)

	desiredBodyOffset =
		(
			Config.FirstPersonBody.ForwardOffset
			+ Config.FirstPersonBody.DownwardForwardBonus
			* downward
		)
		* Config.FirstPersonBody.ForwardSign

	if not Config.FirstPersonBody.AlignCharacterYaw then
		return
	end

	-- Snapshot mutable optional module references.
	-- Luau can safely narrow these local variables.
	local activeRoot = rootPart
	local activeHumanoid = humanoid

	if activeRoot == nil then
		return
	end

	if activeRoot.Parent == nil then
		return
	end

	if activeHumanoid == nil then
		return
	end

	if activeHumanoid.Parent == nil then
		return
	end

	self:_claimAutoRotate()

	local desiredForward =
		getHorizontalCameraForward(
			cameraCFrame,
			lastCameraForward
		)

	lastCameraForward = desiredForward

	activeRoot.CFrame = CFrame.lookAt(
		activeRoot.Position,
		activeRoot.Position + desiredForward,
		Vector3.yAxis
	)

	if not Config.Debug then
		return
	end

	local currentTime = os.clock()

	if currentTime < nextDebugOutput then
		return
	end

	nextDebugOutput =
		currentTime
		+ Config.FirstPersonBody.DebugInterval

	local rootLook = activeRoot.CFrame.LookVector

	local flatActualForward = Vector3.new(
		rootLook.X,
		0,
		rootLook.Z
	)

	local actualForward: Vector3

	if flatActualForward.Magnitude
		> Config.FirstPersonBody.HorizontalDirectionEpsilon
	then
		actualForward = flatActualForward.Unit
	else
		actualForward = desiredForward
	end

	local cameraYaw = math.deg(
		math.atan2(
			-desiredForward.X,
			-desiredForward.Z
		)
	)

	local rootYaw = math.deg(
		math.atan2(
			-actualForward.X,
			-actualForward.Z
		)
	)

	local alignmentDot =
		desiredForward:Dot(actualForward)

	print(
		`[FirstPerson] `
			.. `cameraForward={desiredForward}, `
			.. `rootForward={actualForward}, `
			.. `dot={alignmentDot}, `
			.. `cameraYaw={cameraYaw}, `
			.. `rootYaw={rootYaw}, `
			.. `AutoRotate={activeHumanoid.AutoRotate}`
	)
end

function Controller._resetPose(_self: any)
	local activeWaist = waist
	local activeNeck = neck
	local activeRootMotor = rootMotor

	if activeWaist ~= nil then
		activeWaist.Transform = CFrame.identity
	end

	if activeNeck ~= nil then
		activeNeck.Transform = CFrame.identity
	end

	if activeRootMotor ~= nil then
		activeRootMotor.Transform = CFrame.identity
	end
end

function Controller._applyPose(self: any)
	if not self.Enabled then
		return
	end

	local activeWaist = waist
	local activeNeck = neck
	local activeRootMotor = rootMotor

	if Config.LookBend.Enabled then
		if activeWaist ~= nil then
			activeWaist.Transform *= CFrame.Angles(
				smoothedPitch
					* Config.LookBend.WaistWeight,
				0,
				0
			)
		end

		if activeNeck ~= nil then
			activeNeck.Transform *= CFrame.Angles(
				smoothedPitch
					* Config.LookBend.NeckWeight,
				0,
				0
			)
		end
	end

	if activeRootMotor ~= nil then
		activeRootMotor.Transform *= CFrame.new(
			0,
			0,
			desiredBodyOffset
		)
	end
end

function Controller._releaseCharacter(self: any)
	self:_restoreAutoRotate()
	self:_resetPose()

	disconnectConnections(characterConnections)

	-- Restore local visibility before forgetting the parts.
	for part: BasePart in visibleParts do
		if part.Parent ~= nil then
			part.LocalTransparencyModifier = 0
		end
	end

	table.clear(visibleParts)

	waist = nil
	neck = nil
	rootMotor = nil

	humanoid = nil
	rootPart = nil

	originalAutoRotate = nil

	smoothedPitch = 0
	desiredBodyOffset = 0
	nextDebugOutput = 0
end

function Controller._bindCharacter(
	self: any,
	character: Model
)
	self:_releaseCharacter()

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			visibleParts[descendant] = true
		end
	end

	waist = findMotor(character, "Waist")
	neck = findMotor(character, "Neck")

	rootMotor =
		findMotor(character, "Root")
		or findMotor(character, "RootJoint")

	local foundRoot =
		character:FindFirstChild("HumanoidRootPart")

	if foundRoot ~= nil
		and foundRoot:IsA("BasePart")
	then
		rootPart = foundRoot
	else
		rootPart = nil
	end

	humanoid =
		character:FindFirstChildOfClass("Humanoid")

	local camera = workspace.CurrentCamera

	if camera ~= nil then
		lastCameraForward =
			getHorizontalCameraForward(
				camera.CFrame,
				lastCameraForward
			)
	end

	self:_claimAutoRotate()

	if Config.Debug then
		local activeWaist = waist
		local activeNeck = neck
		local activeRootMotor = rootMotor
		local activeRoot = rootPart
		local activeHumanoid = humanoid

		print(
			`[FirstPerson] `
				.. `Waist={if activeWaist then activeWaist:GetFullName() else "missing"}, `
				.. `Neck={if activeNeck then activeNeck:GetFullName() else "missing"}, `
				.. `RootMotor={if activeRootMotor then activeRootMotor:GetFullName() else "missing"}, `
				.. `RootPart={if activeRoot then activeRoot:GetFullName() else "missing"}, `
				.. `Humanoid={if activeHumanoid then activeHumanoid:GetFullName() else "missing"}`
		)
	end

	table.insert(
		characterConnections,
		character.DescendantAdded:Connect(
			function(descendant: Instance)
				if descendant:IsA("BasePart") then
					visibleParts[descendant] = true
				end
			end
		)
	)

	table.insert(
		characterConnections,
		character.DescendantRemoving:Connect(
			function(descendant: Instance)
				if descendant:IsA("BasePart") then
					visibleParts[descendant] = nil
					descendant.LocalTransparencyModifier = 0
				end
			end
		)
	)
end

function Controller.Start(self: any)
	self:SetEnabled(true)

	RunService:BindToRenderStep(
		"FirstPersonVisibleBody",
		Enum.RenderPriority.Camera.Value + 2,
		function(dt: number)
			self:_updateBody(dt)
		end
	)

	table.insert(
		poseConnections,
		RunService.PreAnimation:Connect(function()
			self:_resetPose()
		end)
	)

	table.insert(
		poseConnections,
		RunService.PreSimulation:Connect(function()
			self:_applyPose()
		end)
	)

	table.insert(
		lifecycleConnections,
		LocalPlayer.CharacterAdded:Connect(
			function(character: Model)
				self:_bindCharacter(character)
				self:SetEnabled(self.Enabled)
			end
		)
	)

	table.insert(
		lifecycleConnections,
		LocalPlayer.CharacterRemoving:Connect(
			function(character: Model)
				local activeRoot = rootPart

				if activeRoot == nil then
					self:_releaseCharacter()
					return
				end

				if activeRoot:IsDescendantOf(character) then
					self:_releaseCharacter()
				end
			end
		)
	)

	local currentCharacter = LocalPlayer.Character

	if currentCharacter ~= nil then
		self:_bindCharacter(currentCharacter)
	end
end

function Controller.Destroy(self: any)
	RunService:UnbindFromRenderStep(
		"FirstPersonVisibleBody"
	)

	self:_releaseCharacter()

	disconnectConnections(poseConnections)
	disconnectConnections(lifecycleConnections)
end

return Controller
