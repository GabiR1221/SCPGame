--!strict
-- ModuleScript: ReplicatedStorage/Shared/UpgradeConfig
return table.freeze({
	Testing=table.freeze({SelectedTreeId="Gun",StartingCoins=100,Debug=true}),
	Trees=table.freeze({
		Gun=table.freeze({
			DisplayName="Gun",
			Upgrades=table.freeze({
				RapidFireI=table.freeze({DisplayName="Rapid Fire I",Price=25,MaxLevel=1,Prerequisites=table.freeze({}),Effects=table.freeze({FireCooldownMultiplier=.2})}),
			}),
		}),
	}),
})
