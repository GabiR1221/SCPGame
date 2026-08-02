--!strict
-- ModuleScript: ReplicatedStorage/Shared/PoseJointUtil

export type PoseJoint = Motor6D | AnimationConstraint
export type PoseJoints = {
	Waist: PoseJoint?,
	Neck: PoseJoint?,
	Root: PoseJoint?,
}

local Util = {}

function Util.GetConnectedParts(joint: PoseJoint): (BasePart?, BasePart?)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1
	end

	local attachment0 = joint.Attachment0
	local attachment1 = joint.Attachment1
	local parent0 = if attachment0 then attachment0.Parent else nil
	local parent1 = if attachment1 then attachment1.Parent else nil
	return if parent0 and parent0:IsA("BasePart") then parent0 else nil,
		if parent1 and parent1:IsA("BasePart") then parent1 else nil
end

local function hasRelationship(joint: PoseJoint, firstName: string, secondName: string): boolean
	local first, second = Util.GetConnectedParts(joint)
	if first == nil or second == nil then
		return false
	end
	return (first.Name == firstName and second.Name == secondName)
		or (first.Name == secondName and second.Name == firstName)
end

function Util.Find(
	character: Model,
	names: {string},
	firstPartName: string,
	secondPartName: string
): PoseJoint?
	for _, name in names do
		for _, descendant in character:GetDescendants() do
			if descendant.Name == name then
				if descendant:IsA("Motor6D") then
					return descendant
				elseif descendant:IsA("AnimationConstraint") then
					return descendant
				end
			end
		end
	end

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") then
			if hasRelationship(descendant, firstPartName, secondPartName) then
				return descendant
			end
		elseif descendant:IsA("AnimationConstraint") then
			if hasRelationship(descendant, firstPartName, secondPartName) then
				return descendant
			end
		end
	end
	return nil
end

function Util.Resolve(character: Model, includeRoot: boolean): PoseJoints
	return {
		Waist = Util.Find(character, {"Waist"}, "LowerTorso", "UpperTorso"),
		Neck = Util.Find(character, {"Neck"}, "UpperTorso", "Head"),
		Root = if includeRoot
			then Util.Find(character, {"Root", "RootJoint"}, "HumanoidRootPart", "LowerTorso")
			else nil,
	}
end

function Util.Describe(label: string, joint: PoseJoint?): string
	if joint == nil then
		return `{label}: missing`
	end
	local first, second = Util.GetConnectedParts(joint)
	local firstPath = if first then first:GetFullName() else "missing endpoint 0"
	local secondPath = if second then second:GetFullName() else "missing endpoint 1"
	return `{label}: class={joint.ClassName}, path={joint:GetFullName()}, endpoints=({firstPath}) -> ({secondPath})`
end

return Util
