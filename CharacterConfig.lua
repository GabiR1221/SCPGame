--!strict
-- ModuleScript: ReplicatedStorage/Shared/CharacterConfig
return table.freeze({
	WalkSpeed = 16, RunSpeed = 24, CrouchSpeed = 5.5, JumpPower = 42, UseJumpPower = true,
	CrouchHipHeightOffset = -1.15, CrouchToggleCooldown = 0.15,
	TestingAllowFirstPersonToggle = true,
	Camera = table.freeze({DefaultFov=70, FirstPersonForwardOffset=0.1, DownwardForwardBonus=.58, FirstPersonVerticalOffset=.14, HeadBobEnabled=true, ShakeEnabled=true, HeadBobAmount=0.035, HeadBobFrequency=9}),
	FirstPersonBody = table.freeze({ForwardOffset=.28,DownwardForwardBonus=.24,ForwardSign=-1,AlignCharacterYaw=true,HorizontalDirectionEpsilon=.001,DebugInterval=.5}),
	-- The active R15 rig's local X rotation follows camera LookVector.Y.
	-- Keep the sign configurable for projects that use differently oriented rigs.
	LookBend = table.freeze({Enabled=true, MaximumPitch=math.rad(55), WaistWeight=.65, NeckWeight=.35, SmoothSpeed=14, PitchSign=1}),
	LookPoseReplication = table.freeze({Enabled=true, SendRate=15, MinimumPitchDelta=math.rad(1), HeartbeatInterval=.3, RemoteSmoothSpeed=12, RemotePoseTimeout=.75, MaximumAcceptedUpdatesPerSecond=25, MaximumRenderDistance=180}),
	-- The eye offset follows the animated/bent Head. Conservative asymmetric
	-- clearance keeps the camera ahead of the chest without changing its rotation.
	PoseAwareCamera = table.freeze({Enabled=true, EyeLocalOffset=Vector3.new(0,.14,-.45), BaseForwardClearance=.17, DownForwardBonus=.34, UpForwardBonus=.28, DownVerticalCompensation=.08, UpVerticalCompensation=.1, PositionSmoothSpeed=24, PreventWallClipping=true, WallPadding=.08, WallCollisionRadius=.35, WallCollisionAnchorLocalOffset=Vector3.new(0,1.4,0), UseSyntheticHeadBob=false}),
	CollisionCapsule = table.freeze({Enabled=true,CollisionGroup="PlayerCapsule",Radius=1.5,CylinderHeight=3,CenterOffset=Vector3.new(0, 1.3, 0),Transparency=1,DebugVisible=true}),
	Debug = false,
})
