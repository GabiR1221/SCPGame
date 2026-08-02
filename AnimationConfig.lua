--!strict
-- ModuleScript: ReplicatedStorage/Shared/AnimationConfig
-- Replace 0 with animations owned by the experience owner/group before testing.
return table.freeze({
	FadeIn=.18, FadeOut=.16, MinSpeed=.55, MaxSpeed=1.65,
	Animations=table.freeze({
		Idle={Id="rbxassetid://507766666",Priority=Enum.AnimationPriority.Idle,Looped=true,AuthoredSpeed=1},
		Walk={Id="rbxassetid://80554633026720",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=10},
		Run={Id="rbxassetid://80554633026720",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=17},
		Jump={Id="rbxassetid://507765000",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},
		Fall={Id="rbxassetid://507767968",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=1},
		Land={Id="rbxassetid://507767968",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},
		CrouchIdle={Id="rbxassetid://128077439819112",Priority=Enum.AnimationPriority.Idle,Looped=true,AuthoredSpeed=1},
		CrouchWalk={Id="rbxassetid://139089965654151",Priority=Enum.AnimationPriority.Movement,Looped=true,AuthoredSpeed=6},
		OpenDrawer={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		PullLever={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		IntroLook={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action3,Looped=false,AuthoredSpeed=1},
	})
})
