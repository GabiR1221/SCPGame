--!strict
-- ModuleScript: StarterPlayer/StarterPlayerScripts/Controllers/LookPoseReplicationController

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if player == nil then error("LookPoseReplicationController must run on the client") end
local LocalPlayer: Player = player
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CharacterConfig"))
local PoseJointUtil = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("PoseJointUtil"))
local FirstPerson = require(script.Parent:WaitForChild("FirstPersonController"))

type PoseJoint = Motor6D | AnimationConstraint
type RemoteState = {
	Character: Model?, Waist: PoseJoint?, Neck: PoseJoint?, TargetPitch: number,
	SmoothedPitch: number, LastUpdate: number, Sequence: number, NextResolve: number,
}

local Controller = {}
local states: {[Player]: RemoteState} = {}
local remote: UnreliableRemoteEvent? = nil
local lastSentPitch = 0
local lastSentAt = 0
local sendAccumulator = 0

local function newState(): RemoteState
	return {Character=nil, Waist=nil, Neck=nil, TargetPitch=0, SmoothedPitch=0, LastUpdate=0, Sequence=0, NextResolve=0}
end

local function clearJoints(state: RemoteState)
	local waist = state.Waist
	local neck = state.Neck
	if waist and waist.Parent then waist.Transform = CFrame.identity end
	if neck and neck.Parent then neck.Transform = CFrame.identity end
	state.Waist = nil; state.Neck = nil; state.Character = nil
end

local function resolve(playerToResolve: Player, state: RemoteState)
	local activeCharacter = playerToResolve.Character
	local waist = state.Waist
	local neck = state.Neck
	if activeCharacter == state.Character and waist and waist.Parent and neck and neck.Parent then return end
	local now = os.clock()
	if activeCharacter == state.Character and now < state.NextResolve then return end
	state.NextResolve = now + 1
	if activeCharacter == nil then clearJoints(state); return end
	clearJoints(state)
	local joints = PoseJointUtil.Resolve(activeCharacter, false)
	state.Character = activeCharacter; state.Waist = joints.Waist; state.Neck = joints.Neck
end

local function resetRemoteLayers()
	for _, state in states do
		local waist = state.Waist
		local neck = state.Neck
		if waist and waist.Parent then waist.Transform = CFrame.identity end
		if neck and neck.Parent then neck.Transform = CFrame.identity end
	end
end

local function applyRemoteLayers(dt: number)
	local localCharacter = LocalPlayer.Character
	local localRoot = if localCharacter then localCharacter:FindFirstChild("HumanoidRootPart") else nil
	local now = os.clock()
	for remotePlayer, state in states do
		resolve(remotePlayer, state)
		local activeCharacter = state.Character
		local root = if activeCharacter then activeCharacter:FindFirstChild("HumanoidRootPart") else nil
		local inRange = true
		if localRoot and localRoot:IsA("BasePart") and root and root:IsA("BasePart") then
			inRange = (root.Position - localRoot.Position).Magnitude <= Config.LookPoseReplication.MaximumRenderDistance
		end
		local target = if now - state.LastUpdate > Config.LookPoseReplication.RemotePoseTimeout then 0 else state.TargetPitch
		state.SmoothedPitch += (target - state.SmoothedPitch) * (1 - math.exp(-Config.LookPoseReplication.RemoteSmoothSpeed * dt))
		if inRange then
			local waist = state.Waist
			local neck = state.Neck
			if waist and waist.Parent then waist.Transform *= CFrame.Angles(state.SmoothedPitch * Config.LookBend.PitchSign * Config.LookBend.WaistWeight, 0, 0) end
			if neck and neck.Parent then neck.Transform *= CFrame.Angles(state.SmoothedPitch * Config.LookBend.PitchSign * Config.LookBend.NeckWeight, 0, 0) end
		end
	end
end

local function send(dt: number)
	if not Config.LookPoseReplication.Enabled then return end
	sendAccumulator += dt
	local interval = 1 / Config.LookPoseReplication.SendRate
	if sendAccumulator < interval then return end
	sendAccumulator %= interval
	local pitch: number = if FirstPerson:IsEnabled() then FirstPerson:GetLookPitch() else 0
	local now = os.clock()
	if math.abs(pitch - lastSentPitch) < Config.LookPoseReplication.MinimumPitchDelta
		and now - lastSentAt < Config.LookPoseReplication.HeartbeatInterval then return end
	local activeRemote = remote
	if activeRemote == nil then return end
	activeRemote:FireServer(pitch)
	lastSentPitch = pitch; lastSentAt = now
end

function Controller.Start()
	local remoteInstance = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LookPoseUpdate")
	if not remoteInstance:IsA("UnreliableRemoteEvent") then error("LookPoseUpdate must be an UnreliableRemoteEvent") end
	remote = remoteInstance
	for _, otherPlayer in Players:GetPlayers() do if otherPlayer ~= LocalPlayer then states[otherPlayer] = newState() end end
	Players.PlayerAdded:Connect(function(otherPlayer: Player) if otherPlayer ~= LocalPlayer then states[otherPlayer] = newState() end end)
	Players.PlayerRemoving:Connect(function(otherPlayer: Player) local state = states[otherPlayer]; if state then clearJoints(state); states[otherPlayer] = nil end end)
	remoteInstance.OnClientEvent:Connect(function(otherPlayer: Player, pitch: number, sequence: number)
		if otherPlayer == LocalPlayer or typeof(pitch) ~= "number" or typeof(sequence) ~= "number" then return end
		local state = states[otherPlayer]
		if state == nil or sequence <= state.Sequence then return end
		state.Sequence = sequence; state.TargetPitch = math.clamp(pitch, -Config.LookBend.MaximumPitch, Config.LookBend.MaximumPitch); state.LastUpdate = os.clock()
	end)
	LocalPlayer:GetAttributeChangedSignal("FirstPersonEnabled"):Connect(function()
		if LocalPlayer:GetAttribute("FirstPersonEnabled") == false then remoteInstance:FireServer(0); lastSentPitch = 0; lastSentAt = os.clock() end
	end)
	RunService.PreAnimation:Connect(resetRemoteLayers)
	RunService.PreSimulation:Connect(applyRemoteLayers)
	RunService.Heartbeat:Connect(send)
end

return Controller
