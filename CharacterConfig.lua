--!strict
-- ModuleScript: ReplicatedStorage/Shared/CharacterConfig
return table.freeze({
	WalkSpeed = 10, RunSpeed = 17, CrouchSpeed = 5.5, JumpPower = 42, UseJumpPower = true,
	CrouchHipHeightOffset = -1.15, CrouchToggleCooldown = 0.15,
	TestingAllowFirstPersonToggle = true,
	Camera = table.freeze({DefaultFov=70, FirstPersonForwardOffset=.62, DownwardForwardBonus=.58, FirstPersonVerticalOffset=.14, HeadBobEnabled=true, ShakeEnabled=true, HeadBobAmount=0.035, HeadBobFrequency=9}),
	FirstPersonBody = table.freeze({ForwardOffset=.28,DownwardForwardBonus=.24,ForwardSign=-1,AlignCharacterYaw=true,HorizontalDirectionEpsilon=.001,DebugInterval=.5}),
	-- The active R15 rig's local X rotation follows camera LookVector.Y.
	-- Keep the sign configurable for projects that use differently oriented rigs.
	LookBend = table.freeze({Enabled=true, MaximumPitch=math.rad(55), WaistWeight=.65, NeckWeight=.35, SmoothSpeed=14, PitchSign=1}),
	Debug = false,
})
