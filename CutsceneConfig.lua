--!strict
-- ModuleScript: ReplicatedStorage/Shared/CutsceneConfig
return table.freeze({ResolveTimeout=5, Definitions=table.freeze({
	TestIntro={Duration=3,Locks={"Movement","Jump","Interaction","Camera","Rotation"},CharacterAnimationKey="IntroLook",OneShot=false,SkipPolicy="None",RoomScoped=true,
		Camera={{Time=0,Point="Start",Fov=70},{Time=1.5,Point="Focus",Fov=58},{Time=3,Point="End",Fov=70}}},
})})
