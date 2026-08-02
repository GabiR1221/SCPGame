--!strict
-- ModuleScript: ReplicatedStorage/Shared/InteractionConfig
return table.freeze({
	Debug=true,
	ScanDistance=12, DefaultDistance=8, MaxServerDistance=16, RequestBurst=4, RequestRefillPerSecond=2,
	Definitions=table.freeze({
		OpenDrawer={AnimationKey="OpenDrawer",Duration=1.2,CommitTime=.3,Locks={"Movement","Jump","Interaction","Rotation"},NoiseRadius=22},
		PullLever={AnimationKey="PullLever",Duration=1.5,CommitTime=.75,Locks={"Movement","Jump","Interaction","Rotation"},NoiseRadius=28},
		PressButton={AnimationKey=nil,Duration=.35,CommitTime=.1,Locks={"Interaction"},NoiseRadius=12},
	})
})
