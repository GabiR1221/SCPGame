--!strict
-- ModuleScript: ReplicatedStorage/Shared/PowerConfig
return table.freeze({
	Gun=table.freeze({
		TemplateName="Gun",Damage=25,Range=120,FireCooldown=1,MaximumAimDirectionMagnitude=1.01,
		HandGripAttachmentName="RightGripAttachment",GunGripAttachmentName="GripAttachment",
		BulletTemplateName="GunBullet",BulletForwardAttachmentName="ForwardAttachment",BulletSpeed=240,MaximumBulletLifetime=3,
		BulletOrientationOffset=CFrame.new(),
		GripCFrame=CFrame.new(), EquipAnimation="GunPowerEquip",IdleAnimation="GunPowerIdle",
		FireAnimation="GunPowerFire",UnequipAnimation="GunPowerUnequip",
	}),
})
