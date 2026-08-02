--!strict
-- ModuleScript: ReplicatedStorage/Shared/CharacterTypes
export type PrimaryState = "Normal" | "Interacting" | "Cutscene" | "Disabled" | "Dead"
export type LockCategory = "Movement" | "Jump" | "Interaction" | "Camera" | "Rotation" | "Inventory"
export type InteractionMessage = {kind: string, token: string?, reason: string?, animationKey: string?, duration: number?, cameraPoint: Attachment?}
return {}
