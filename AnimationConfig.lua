--!strict
-- ModuleScript: ReplicatedStorage/Shared/AnimationConfig
-- Replace 0 with animations owned by the experience owner/group before testing.
return table.freeze({
	FadeIn=.18, FadeOut=.16, MinSpeed=.55, MaxSpeed=1.65,
	InteractionTimingDebug=false, HidingDebug=false, StabilizeRootTranslationWhileHidden=true, RootTranslationTolerance=.05,
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
		LockerIdle={Id="rbxassetid://101403921204911",Priority=Enum.AnimationPriority.Action3,Looped=true,AuthoredSpeed=1},
		LockerExit={Id="rbxassetid://113984487264215",Priority=Enum.AnimationPriority.Action3,Looped=false,AuthoredSpeed=1},
		PullLever={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		IntroLook={Id="rbxassetid://109284362906915",Priority=Enum.AnimationPriority.Action3,Looped=false,AuthoredSpeed=1},
		-- Upper-body-only tool animations; replace zero IDs in Studio when ready.
		FlashlightIdle={Id="rbxassetid://90500203310017",Priority=Enum.AnimationPriority.Action,Looped=true,AuthoredSpeed=1},
		FlashlightEquip={Id="rbxassetid://110714371172299",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		FlashlightUnequip={Id="rbxassetid://118308237201245",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		FlashlightToggle={Id="rbxassetid://129785789637011",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		-- Upper-body character power animations. Replace placeholders in Studio.
		GunPowerEquip={Id="rbxassetid://105498606838598",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		GunPowerIdle={Id="rbxassetid://118836941177269",Priority=Enum.AnimationPriority.Action,Looped=true,AuthoredSpeed=1},
		GunPowerFire={Id="rbxassetid://91623108860478",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		GunPowerUnequip={Id="rbxassetid://112489189667532",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		-- These play only on ReplicatedStorage.ClientAssets.Viewmodels.Flashlight.
		FlashlightViewmodelEquip={Id="rbxassetid://0",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},
		FlashlightViewmodelIdle={Id="rbxassetid://0",Priority=Enum.AnimationPriority.Idle,Looped=true,AuthoredSpeed=1},
		FlashlightViewmodelToggle={Id="rbxassetid://0",Priority=Enum.AnimationPriority.Action2,Looped=false,AuthoredSpeed=1},
		FlashlightViewmodelUnequip={Id="rbxassetid://0",Priority=Enum.AnimationPriority.Action,Looped=false,AuthoredSpeed=1},

	}),
	ObjectAnimationDebug=false,
	-- Put prop-specific object clips in a named profile, then set the String
	-- attribute ObjectAnimationProfile on the outer prop Model. Child drawers
	-- inherit it, so identical drawer rigs can all reuse the same two clips.
	ObjectAnimationProfiles=table.freeze({
		DrawerDefault=table.freeze({
			DrawerOpen={Id="rbxassetid://104925566814206",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
			DrawerClose={Id="rbxassetid://138834454142354",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		}),
		LockerDefault=table.freeze({
			LockerEnter={Id="rbxassetid://72838676764108",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
			LockerIdle={Id="rbxassetid://101403921204911",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
			LockerExit={Id="rbxassetid://113984487264215",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		}),
		MiniLockerDefault=table.freeze({
			DrawerOpen={Id="rbxassetid://98847798087797",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
			DrawerClose={Id="rbxassetid://89897250628835",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		}),

	}),
	ObjectAnimations=table.freeze({
		-- Drawer clips intentionally require an explicit prop profile. This prevents
		-- an unrelated rig from playing legacy drawer clips and flying off-origin.
		DrawerOpen={Id="rbxassetid://104925566814206",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		DrawerClose={Id="rbxassetid://138834454142354",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.55,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		LockerEnterObject={Id="rbxassetid://84722822165057",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.7,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
		LockerExitObject={Id="rbxassetid://115991174612221",Priority=Enum.AnimationPriority.Action,Looped=false,Duration=.65,LengthTimeout=.25,FinalFrameEpsilon=.001,HoldLeadTime=.05},
	})
})
