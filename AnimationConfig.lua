--!strict
-- ModuleScript: ReplicatedStorage/Shared/AnimationConfig
-- Replace 0 with animations owned by the experience owner/group before testing.
return table.freeze({
	FadeIn=.18, FadeOut=.16, MinSpeed=.55, MaxSpeed=1.65,
	DirectionalMovement=table.freeze({Enabled=true,DirectionSwitchThreshold=.12,DirectionHysteresis=.15,MinimumDirectionalSpeed=.5}),
	Animations=table.freeze({
		Idle={Id="rbxassetid://507766666",Priority=Enum.AnimationPriority.Idle,Looped=true,AuthoredSpeed=1},
		Walk={Id="rbxassetid://80554633026720",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		-- Replace these zero IDs with experience-owned directional animations.
		-- WalkForward intentionally falls back to Walk until an ID is supplied.
		WalkForward={Id="rbxassetid://80554633026720",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		WalkBackward={Id="rbxassetid://136286851518587",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		WalkLeft={Id="rbxassetid://127839508272111",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		WalkRight={Id="rbxassetid://119771283826332",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		Run={Id="rbxassetid://80554633026720",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		Jump={Id="rbxassetid://507765000",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},
		Fall={Id="rbxassetid://507767968",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		Land={Id="rbxassetid://507767968",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},
		CrouchIdle={Id="rbxassetid://128077439819112",Priority=Enum.AnimationPriority.Idle,Looped=true,AuthoredSpeed=1},
		CrouchWalk={Id="rbxassetid://139089965654151",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=6},
		OpenDrawer={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		CloseDrawer={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		LockerEnter={Id="rbxassetid://72838676764108",Priority=Enum.AnimationPriority.Action3,Looped=false,AuthoredSpeed=1},
		LockerIdle={Id="rbxassetid://101403921204911",Priority=Enum.AnimationPriority.Action,Looped=true,AuthoredSpeed=1},
		LockerExit={Id="rbxassetid://113984487264215",Priority=Enum.AnimationPriority.Action3,Looped=false,AuthoredSpeed=1},
		PullLever={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		IntroLook={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action3,Looped=false,AuthoredSpeed=1},
		-- Upper-body-only tool animations; replace zero IDs in Studio when ready.
		FlashlightIdle={Id="rbxassetid://90500203310017",Priority=Enum.AnimationPriority.Action,Looped=true,AuthoredSpeed=1},
		FlashlightEquip={Id="rbxassetid://110714371172299",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		FlashlightUnequip={Id="rbxassetid://118308237201245",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		FlashlightToggle={Id="rbxassetid://129785789637011",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		-- These play only on ReplicatedStorage.ClientAssets.Viewmodels.Flashlight.
		FlashlightViewmodelEquip={Id="rbxassetid://110714371172299",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},
		FlashlightViewmodelIdle={Id="rbxassetid://90500203310017",Priority=Enum.AnimationPriority.Idle,Looped=true,AuthoredSpeed=1},
		FlashlightViewmodelToggle={Id="rbxassetid://129785789637011",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		FlashlightViewmodelUnequip={Id="rbxassetid://118308237201245",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},

	}),
	ObjectAnimationDebug=false,
	ObjectAnimations=table.freeze({
		DrawerOpen={Id="rbxassetid://88542616058118",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		DrawerClose={Id="rbxassetid://115769042595557",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		LockerEnterObject={Id="rbxassetid://99308891064081",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.7,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		LockerExitObject={Id="rbxassetid://85426657586918",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.65,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
	})
})
