--!strict
-- ModuleScript: ServerScriptService/Services/PropService
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config: any = require(ReplicatedStorage.Shared.PropConfig)
local Service = {}
Service.__index = Service

type PropDefinition = {
	Id: string,
	Category: string,
	Model: Model,
	MinimumRoom: number,
	MaximumRoom: number,
	AllowedThemes: string?,
	MinimumSpacing: number,
	WallInset: number,
	HidingCapacity: number,
	CanRepeat: boolean,
	CooldownRooms: number,
	AnchoringMode: string,
}
type PlacementBox = { CFrame: CFrame, Size: Vector3, PropId: string }
type FurnishOptions = { RequiredHidingSpots: number?, SafetyDemand: number? }
type Counts = { [string]: number }

local MODULUS = 2147483647
local function hash(seed: number, roomIndex: number, propIndex: number, poolId: string): number
	local value = (seed * 48271 + roomIndex * 69621 + propIndex * 104729) % MODULUS
	for index = 1, #poolId do value = (value * 31 + string.byte(poolId, index)) % MODULUS end
	return math.max(1, value)
end

local function numberAttribute(instance: Instance, name: string, fallback: number): number
	local value = instance:GetAttribute(name)
	return if typeof(value) == "number" then value else fallback
end

local function stringAttribute(instance: Instance, name: string, fallback: string): string
	local value = instance:GetAttribute(name)
	return if typeof(value) == "string" and value ~= "" then value else fallback
end

local function containsCsv(csv: string?, wanted: string): boolean
	if csv == nil or csv == "" then return true end
	for token in string.gmatch(csv, "[^,%s]+") do if token == wanted then return true end end
	return false
end

local function stableIndex(instance: Instance): number
	local configured = instance:GetAttribute("PropIndex")
	if typeof(configured) == "number" then return math.floor(configured) end
	local digits = string.match(instance.Name, "(%d+)$")
	return if digits then tonumber(digits) or 0 else 0
end

local function sortByPropIndex(result: {Instance}): {Instance}
	table.sort(result, function(a: Instance, b: Instance): boolean
		local ai, bi = stableIndex(a), stableIndex(b)
		if ai == bi then return a.Name < b.Name end
		return ai < bi
	end)
	return result
end

local function sortedChildren(root: Instance?): {Instance}
	local result: {Instance} = {}
	if root then for _, child in root:GetChildren() do table.insert(result, child) end end
	return sortByPropIndex(result)
end

-- Attachments require a BasePart parent in Studio, so slot Attachments are normally
-- descendants of invisible anchor Parts. A direct BasePart is also accepted as a
-- simpler slot, but an anchor containing an Attachment is not processed twice.
local function sortedSpawnLocations(root: Instance?): {Instance}
	local result: {Instance} = {}
	if root == nil then return result end
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("Attachment") then table.insert(result, descendant) end
	end
	for _, child in root:GetChildren() do
		if child:IsA("BasePart") and child:FindFirstChildWhichIsA("Attachment", true) == nil then table.insert(result, child) end
	end
	return sortByPropIndex(result)
end

local function worldCFrame(instance: Instance): CFrame?
	if instance:IsA("Attachment") then return instance.WorldCFrame end
	if instance:IsA("BasePart") then return instance.CFrame end
	return nil
end

-- Conservative oriented-box test. Roblox spatial queries ignore CanQuery=false clearance
-- parts, so validation is mathematical and works with invisible authoring helpers.
local function boxesOverlap(aCFrame: CFrame, aSize: Vector3, bCFrame: CFrame, bSize: Vector3): boolean
	local relative = aCFrame:ToObjectSpace(bCFrame)
	local center = relative.Position
	local bx, by, bz = relative.XVector, relative.YVector, relative.ZVector
	local a = aSize * 0.5
	local b = bSize * 0.5
	local epsilon = 0.0001
	local rotation = {
		{ bx.X, by.X, bz.X }, { bx.Y, by.Y, bz.Y }, { bx.Z, by.Z, bz.Z },
	}
	local absolute = {
		{ math.abs(bx.X) + epsilon, math.abs(by.X) + epsilon, math.abs(bz.X) + epsilon },
		{ math.abs(bx.Y) + epsilon, math.abs(by.Y) + epsilon, math.abs(bz.Y) + epsilon },
		{ math.abs(bx.Z) + epsilon, math.abs(by.Z) + epsilon, math.abs(bz.Z) + epsilon },
	}
	local av = { a.X, a.Y, a.Z }
	local bv = { b.X, b.Y, b.Z }
	local translation = { center.X, center.Y, center.Z }
	for i = 1, 3 do
		if math.abs(translation[i]) > av[i] + bv[1] * absolute[i][1] + bv[2] * absolute[i][2] + bv[3] * absolute[i][3] then return false end
	end
	for j = 1, 3 do
		local projected = math.abs(translation[1] * rotation[1][j] + translation[2] * rotation[2][j] + translation[3] * rotation[3][j])
		if projected > bv[j] + av[1] * absolute[1][j] + av[2] * absolute[2][j] + av[3] * absolute[3][j] then return false end
	end
	for i = 1, 3 do
		local i1, i2 = i % 3 + 1, (i + 1) % 3 + 1
		for j = 1, 3 do
			local j1, j2 = j % 3 + 1, (j + 1) % 3 + 1
			local projected = math.abs(translation[i2] * rotation[i1][j] - translation[i1] * rotation[i2][j])
			local radiusA = av[i1] * absolute[i2][j] + av[i2] * absolute[i1][j]
			local radiusB = bv[j1] * absolute[i][j2] + bv[j2] * absolute[i][j1]
			if projected > radiusA + radiusB then return false end
		end
	end
	return true
end

local function definitionFor(template: Model): PropDefinition?
	local primary = template.PrimaryPart
	local idValue, categoryValue = template:GetAttribute("PropId"), template:GetAttribute("Category")
	if not primary or typeof(idValue) ~= "string" or idValue == "" or typeof(categoryValue) ~= "string" or categoryValue == "" then
		warn(`[PropService] {template:GetFullName()} needs PrimaryPart, PropId, and Category`)
		return nil
	end
	local themesValue = template:GetAttribute("AllowedThemes")
	local allowedThemes: string? = if typeof(themesValue) == "string" then themesValue else nil
	local anchoringValue = template:GetAttribute("AnchoringMode")
	local anchoringMode = if template:FindFirstChildWhichIsA("AnimationController", true) then "Root" else "All"
	if anchoringValue ~= nil then
		if typeof(anchoringValue) == "string" and (anchoringValue == "All" or anchoringValue == "Root" or anchoringValue == "Preserve") then
			anchoringMode = anchoringValue
		else
			warn(`[PropService] {template:GetFullName()}.AnchoringMode must be the string All, Root, or Preserve; using {anchoringMode}`)
		end
	end
	local placementCount = 0
	for _, descendant in template:GetDescendants() do
		if descendant.Name == "PropPlacement" then
			if descendant:IsA("Attachment") then
				placementCount += 1
			else
				warn(`[PropService] {descendant:GetFullName()} is named PropPlacement but is not an Attachment`)
			end
		end
		if descendant:GetAttribute("AnchoringMode") ~= nil then
			warn(`[PropService] move AnchoringMode from {descendant:GetFullName()} to the PropTemplate Model {template:GetFullName()}`)
		end
	end
	if placementCount > 1 then
		warn(`[PropService] {template:GetFullName()} has {placementCount} PropPlacement Attachments; exactly one is allowed`)
		return nil
	end
	return {
		Id = idValue, Category = categoryValue, Model = template,
		MinimumRoom = numberAttribute(template, "MinimumRoom", 0), MaximumRoom = numberAttribute(template, "MaximumRoom", math.huge),
		AllowedThemes = allowedThemes, MinimumSpacing = math.max(0, numberAttribute(template, "MinimumSpacing", 0)),
		WallInset = math.max(0, numberAttribute(template, "WallInset", 0)), HidingCapacity = math.max(0, math.floor(numberAttribute(template, "HidingCapacity", 0))),
		CanRepeat = template:GetAttribute("CanRepeat") ~= false, CooldownRooms = math.max(0, math.floor(numberAttribute(template, "CooldownRooms", 0))),
		AnchoringMode = anchoringMode,
	}
end

function Service.new(): any
	return setmetatable({ Templates = {} :: {[string]: PropDefinition} }, Service)
end

function Service.Scan(self: any): boolean
	table.clear(self.Templates)
	local rootValue = ServerStorage:FindFirstChild("PropTemplates")
	local root: Folder
	if rootValue == nil then
		root = Instance.new("Folder"); root.Name = "PropTemplates"; root.Parent = ServerStorage
	elseif rootValue:IsA("Folder") then
		root = rootValue
	else
		warn("[PropService] ServerStorage.PropTemplates must be a Folder"); return false
	end
	local valid = true
	for _, child in root:GetChildren() do
		if child:IsA("Model") then
			local definition = definitionFor(child)
			if definition then
				if self.Templates[definition.Id] then warn(`[PropService] duplicate PropId {definition.Id}`); valid = false else self.Templates[definition.Id] = definition end
			else valid = false end
		end
	end
	return valid
end

local function recentProp(run: any, roomIndex: number, propId: string, cooldown: number): boolean
	for index = math.max(0, roomIndex - cooldown), roomIndex - 1 do
		local prior = run.ActiveRooms[index]
		if prior and prior.GeneratedPropIds and table.find(prior.GeneratedPropIds, propId) then return true end
	end
	return false
end

function Service._choose(self: any, run: any, room: any, source: Instance, propIndex: number, poolId: string, counts: Counts, required: boolean): (PropDefinition?, number)
	local pool = Config.PropPools[poolId]
	local seed = hash(run.Seed, room.Index, propIndex, poolId)
	if pool == nil then if Config.RoomFurnishing.Debug then warn(`[PropService] unknown pool {poolId}`) end; return nil, seed end
	local allowedCategory = source:GetAttribute("AllowedCategory")
	local allowedPropIds = source:GetAttribute("AllowedPropIds")
	local weighted: {{Definition: PropDefinition, Weight: number}} = {}
	local total = if required or source:GetAttribute("AllowEmpty") == false then 0 else math.max(0, pool.EmptyWeight)
	for _, entry in pool.Entries do
		local definition = self.Templates[entry.PropId]
		if definition == nil or entry.Weight <= 0 or room.Index < definition.MinimumRoom or room.Index > definition.MaximumRoom then continue end
		if typeof(allowedCategory) == "string" and not containsCsv(allowedCategory, definition.Category) then continue end
		if typeof(allowedPropIds) == "string" and not containsCsv(allowedPropIds, definition.Id) then continue end
		local theme = stringAttribute(room.Model, "Theme", tostring(run.Theme))
		if not containsCsv(definition.AllowedThemes, theme) then continue end
		local current = counts[definition.Id] or 0
		local maximum = if typeof(entry.MaximumCopies) == "number" then entry.MaximumCopies else math.huge
		local categoryMaximum = if typeof(entry.MaximumCategoryCopies) == "number" then entry.MaximumCategoryCopies else math.huge
		if current >= maximum or (counts[`Category:{definition.Category}`] or 0) >= categoryMaximum or (not definition.CanRepeat and current > 0) then continue end
		if Config.RoomFurnishing.PreventExactDuplicates and current > 0 then continue end
		if definition.CooldownRooms > 0 and recentProp(run, room.Index, definition.Id, definition.CooldownRooms) then continue end
		local weight = entry.Weight * (if current > 0 then Config.RoomFurnishing.RepetitionPenalty ^ current else 1)
		if weight > 0 then total += weight; table.insert(weighted, { Definition = definition, Weight = weight }) end
	end
	if total <= 0 then return nil, seed end
	local roll = Random.new(seed):NextNumber() * total
	local emptyWeight = if required or source:GetAttribute("AllowEmpty") == false then 0 else math.max(0, pool.EmptyWeight)
	if roll < emptyWeight then return nil, seed end
	roll -= emptyWeight
	for _, candidate in weighted do roll -= candidate.Weight; if roll <= 0 then return candidate.Definition, seed end end
	return if #weighted > 0 then weighted[#weighted].Definition else nil, seed
end

local function footprint(model: Model, definition: PropDefinition): (CFrame, Vector3)
	local authored = model:FindFirstChild("PropFootprint", true)
	if authored and authored:IsA("BasePart") then return authored.CFrame, authored.Size + Vector3.new(definition.MinimumSpacing * 2, 0, definition.MinimumSpacing * 2) end
	local boxCFrame, boxSize = model:GetBoundingBox()
	return boxCFrame, boxSize + Vector3.new(definition.MinimumSpacing * 2, 0, definition.MinimumSpacing * 2)
end

local function placementReference(model: Model): (CFrame?, string)
	local authored = model:FindFirstChild("PropPlacement", true)
	if authored and authored:IsA("Attachment") then return authored.WorldCFrame, "PropPlacement" end
	local primary = model.PrimaryPart
	if primary then return primary.CFrame, "PrimaryPart" end
	return nil, "Missing"
end

local function applyAnchoring(model: Model, definition: PropDefinition)
	if definition.AnchoringMode == "All" then
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then descendant.Anchored = true end
		end
	elseif definition.AnchoringMode == "Root" then
		local primary = model.PrimaryPart
		if primary then primary.Anchored = true end
	end
end

local function placementReason(candidateCFrame: CFrame, candidateSize: Vector3, placed: {PlacementBox}, clearance: {BasePart}): string?
	for _, box in placed do if boxesOverlap(candidateCFrame, candidateSize, box.CFrame, box.Size) then return `overlaps prop {box.PropId}` end end
	for _, part in clearance do if boxesOverlap(candidateCFrame, candidateSize, part.CFrame, part.Size) then return `overlaps clearance {part.Name}` end end
	return nil
end

function Service._spawn(self: any, room: any, source: Instance, definition: PropDefinition, target: CFrame, propIndex: number, runtime: Folder, placed: {PlacementBox}, clearance: {BasePart}): (boolean, string?)
	local clone = definition.Model:Clone()
	clone.Name = string.format("Prop_%04d_%s", propIndex, definition.Id)
	-- Prop templates are data/rigs. Runtime behavior belongs to the existing server
	-- services; copied legacy scripts can bind the same prompt twice and must not run.
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then descendant:Destroy() end
	end
	-- Positive WallInset moves into the slot's local +Z wall direction. The author
	-- remains in control of that direction by rotating the slot Attachment. A
	-- PropPlacement Attachment decouples floor alignment from an animation root.
	local reference, referenceName = placementReference(clone)
	if reference == nil then clone:Destroy(); return false, "template has no placement reference" end
	-- Store the placement offset relative to the model pivot, then solve for the
	-- pivot which puts that exact Attachment at the authored slot CFrame.
	local pivotToReference = clone:GetPivot():ToObjectSpace(reference)
	local desiredReference = target * CFrame.new(0, 0, definition.WallInset)
	clone:PivotTo(desiredReference * pivotToReference:Inverse())
	applyAnchoring(clone, definition)
	if Config.RoomFurnishing.Debug then
		local actualReference = placementReference(clone)
		if actualReference then
			local positionError = (actualReference.Position - desiredReference.Position).Magnitude
			print(`[PropService] {clone.Name} placement={referenceName} anchor={definition.AnchoringMode} error={positionError}`)
		end
	end
	local boxCFrame, boxSize = footprint(clone, definition)
	local reason = placementReason(boxCFrame, boxSize, placed, clearance)
	if reason then clone:Destroy(); return false, reason end
	local authoredFootprint = clone:FindFirstChild("PropFootprint", true)
	-- Footprints are authoring/validation helpers, not runtime physics parts. In
	-- particular, an unwelded footprint must not fall or obtain network ownership.
	if authoredFootprint and authoredFootprint:IsA("BasePart") then authoredFootprint:Destroy() end
	clone:SetAttribute("GeneratedProp", true); clone:SetAttribute("GeneratedPropIndex", propIndex); clone:SetAttribute("GeneratedPropId", definition.Id)
	-- A prop template may put CanSpawnLoot on its root Model or on multiple nested
	-- drawers. Sort explicitly; clone/descendant creation order never determines loot RNG.
	local lootDrawers: {Instance} = {}
	if clone:GetAttribute("CanSpawnLoot") == true then table.insert(lootDrawers, clone) end
	for _, candidate in clone:GetDescendants() do if candidate:GetAttribute("CanSpawnLoot") == true then table.insert(lootDrawers, candidate) end end
	table.sort(lootDrawers, function(a: Instance, b: Instance): boolean
		local ai, bi = numberAttribute(a, "LootSubIndex", math.huge), numberAttribute(b, "LootSubIndex", math.huge)
		if ai == bi then return a:GetFullName() < b:GetFullName() end
		return ai < bi
	end)
	for ordinal, drawer in lootDrawers do drawer:SetAttribute("LootIndex", propIndex * 100 + ordinal) end
	clone.Parent = runtime
	table.insert(placed, { CFrame = boxCFrame, Size = boxSize, PropId = definition.Id })
	return true, nil
end

local function clearances(roomModel: Model): {BasePart}
	local result: {BasePart} = {}
	local explicit = roomModel:FindFirstChild("PropClearance")
	if explicit then for _, value in explicit:GetDescendants() do if value:IsA("BasePart") then table.insert(result, value) end end end
	-- These named helpers are protected even when an author forgot explicit boxes.
	for _, name in { "Entrance", "Exit", "PlayerRoomTrigger", "EntityPath", "DoorClearance", "MainPathClearance" } do
		local value = roomModel:FindFirstChild(name, true)
		if value and value:IsA("BasePart") and not table.find(result, value) then table.insert(result, value) end
	end
	return result
end

local function livingPlayerCount(): number
	local count = 0
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid == nil or humanoid.Health > 0 then count += 1 end
	end
	return math.max(1, count)
end

function Service.FurnishRoom(self: any, room: any, run: any, options: FurnishOptions?): ()
	room.GeneratedPropIds = {} :: {string}
	if not Config.RoomFurnishing.Enabled or room.Model:GetAttribute("AllowProceduralProps") == false then return end
	local spawns = room.Model:FindFirstChild("PropSpawns")
	if spawns == nil then return end
	local runtime = Instance.new("Folder"); runtime.Name = "RuntimeProps"; runtime.Parent = room.Model
	local placed: {PlacementBox}, protected = {}, clearances(room.Model)
	local counts: Counts = {}
	local budget = math.max(0, math.floor(numberAttribute(room.Model, "PropBudget", Config.RoomFurnishing.MaximumPropsPerRoom)))
	local spawned, lockers, drawers = 0, 0, 0
	local requiredSafety = 0
	if Config.Safety.Enabled and room.Model:GetAttribute("AllowSafetyProps") ~= false then
		local entityEligible = room.Model:GetAttribute("AllowsEntities") ~= false and room.Model:GetAttribute("EntityCapableProps") ~= false
		if not Config.Safety.OnlyGuaranteeInEntityRooms or entityEligible then
			requiredSafety = if options and typeof(options.RequiredHidingSpots) == "number" then math.max(0, math.floor(options.RequiredHidingSpots)) else Config.Safety.MinimumHidingSpotsPerPlayer
			if options and typeof(options.SafetyDemand) == "number" then requiredSafety = math.max(requiredSafety, math.floor(options.SafetyDemand)) end
			if Config.Safety.PlayerCountScaling then requiredSafety *= livingPlayerCount() end
		end
	end
	local function process(source: Instance, forcedPool: string?, required: boolean, ordinal: number, targetOverride: CFrame?): boolean
		if spawned >= budget then return false end
		local propIndex = stableIndex(source) * 100 + ordinal
		local defaultPool = stringAttribute(room.Model, "PropPoolId", Config.RoomFurnishing.DefaultPoolId)
		local poolId = forcedPool or stringAttribute(source, "PoolId", defaultPool)
		local definition, seed = self:_choose(run, room, source, propIndex, poolId, counts, required)
		if definition == nil then if Config.RoomFurnishing.Debug then print(`[PropService] room={room.Index} index={propIndex} pool={poolId} seed={seed} choice=Empty`) end; return false end
		local target = targetOverride or worldCFrame(source)
		if target == nil then if Config.RoomFurnishing.Debug then warn(`[PropService] {source:GetFullName()} must be an Attachment or BasePart`) end; return false end
		local ok, reason = self:_spawn(room, source, definition, target, propIndex, runtime, placed, protected)
		if not ok then if Config.RoomFurnishing.Debug then warn(`[PropService] room={room.Index} index={propIndex} rejected {definition.Id}: {reason}`) end; return false end
		spawned += 1; counts[definition.Id] = (counts[definition.Id] or 0) + 1; counts[`Category:{definition.Category}`] = (counts[`Category:{definition.Category}`] or 0) + 1
		lockers += definition.HidingCapacity; if definition.Category == "Drawer" then drawers += 1 end; table.insert(room.GeneratedPropIds, definition.Id)
		if Config.RoomFurnishing.Debug then print(`[PropService] room={room.Index} index={propIndex} pool={poolId} seed={seed} choice={definition.Id}`) end
		return true
	end
	local safetyRoot = spawns:FindFirstChild("SafetySlots")
	for ordinal, source in sortedSpawnLocations(safetyRoot) do if lockers >= requiredSafety then break end; process(source, Config.Safety.SafetyPoolId, true, ordinal, nil) end
	local slotsRoot = spawns:FindFirstChild("Slots")
	for ordinal, source in sortedSpawnLocations(slotsRoot) do process(source, nil, source:GetAttribute("Required") == true, ordinal, nil) end
	local zonesRoot = spawns:FindFirstChild("Zones")
	for _, source in sortedChildren(zonesRoot) do
		if not source:IsA("BasePart") then if Config.RoomFurnishing.Debug then warn(`[PropService] zone {source:GetFullName()} must be a BasePart`) end; continue end
		local maximum = math.max(0, math.floor(numberAttribute(source, "MaximumProps", 1)))
		local minimum = math.clamp(math.floor(numberAttribute(source, "MinimumProps", 0)), 0, maximum)
		for ordinal = 1, maximum do
			local propIndex = stableIndex(source) * 100 + ordinal
			local poolId = stringAttribute(source, "PoolId", Config.RoomFurnishing.DefaultZonePoolId)
			local random = Random.new(hash(run.Seed, room.Index, propIndex, poolId .. ":point"))
			local localPoint = Vector3.new((random:NextNumber() - 0.5) * source.Size.X, source.Size.Y * 0.5, (random:NextNumber() - 0.5) * source.Size.Z)
			local origin = source.CFrame:PointToWorldSpace(localPoint)
			local target = CFrame.fromMatrix(origin, source.CFrame.XVector, source.CFrame.YVector, source.CFrame.ZVector)
			if stringAttribute(source, "PlacementMode", "Floor") == "Floor" then
				local parameters = RaycastParams.new(); parameters.FilterType = Enum.RaycastFilterType.Exclude; parameters.FilterDescendantsInstances = { runtime, source }
				local hit = Workspace:Raycast(origin, -source.CFrame.YVector * (source.Size.Y + 16), parameters)
				if hit then target = CFrame.fromMatrix(hit.Position, source.CFrame.XVector, hit.Normal, -source.CFrame.XVector:Cross(hit.Normal)) elseif Config.RoomFurnishing.Debug then warn(`[PropService] zone {source.Name} point {ordinal} found no floor`) end
			end
			process(source, poolId, ordinal <= minimum, ordinal, target)
		end
	end
	if Config.RoomFurnishing.Debug then
		print(`[PropService] room={room.Index} template={room.TemplateId} players={livingPlayerCount()} safety={requiredSafety} spawned={spawned} lockers={lockers} drawers={drawers} decorative={spawned-drawers-lockers}`)
		if lockers < requiredSafety then warn(`[PropService] room {room.Index} has {lockers}/{requiredSafety} requested hiding capacity; EntityDirector remains the final fairness gate`) end
	end
end

return Service
