--!strict
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.RoomConstants)

local Registry = {}
Registry.__index = Registry
local REQUIRED: {[string]: string} = {
	RoomId = "string", Theme = "string", Category = "string", Weight = "number", MinDepth = "number", MaxDepth = "number",
	Difficulty = "number", CooldownRooms = "number", MaxConsecutive = "number", EntranceType = "string", ExitType = "string",
	IsUnique = "boolean", IsSpecial = "boolean", CanBeDark = "boolean", AllowsEntities = "boolean",
}

function Registry.new(config: any): any
	return setmetatable({ Config = config, Templates = {} :: {[string]: any}, Errors = {} :: {string} }, Registry)
end

local function childPart(model: Model, name: string, errors: {string}): BasePart?
	local object = model:FindFirstChild(name)
	if not object or not object:IsA("BasePart") then table.insert(errors, `missing {name} BasePart`); return nil end
	return object
end

function Registry._validate(self: any, model: Model): ({string}, any)
	local errors = {}
	local attributes = model:GetAttributes()
	for name, expected in REQUIRED do
		if typeof(attributes[name]) ~= expected then table.insert(errors, `{name} must be {expected}`) end
	end
	if typeof(attributes.Weight) == "number" and (attributes.Weight <= 0 or attributes.Weight ~= attributes.Weight or math.abs(attributes.Weight) == math.huge) then table.insert(errors, "Weight must be finite and > 0") end
	if typeof(attributes.RoomId) == "string" and attributes.RoomId == "" then table.insert(errors, "RoomId cannot be empty") end
	if typeof(attributes.Theme) == "string" and attributes.Theme == "" then table.insert(errors, "Theme cannot be empty") end
	if typeof(attributes.Category) == "string" and attributes.Category == "" then table.insert(errors, "Category cannot be empty") end
	if typeof(attributes.CooldownRooms) == "number" and attributes.CooldownRooms < 0 then table.insert(errors, "CooldownRooms cannot be negative") end
	if typeof(attributes.MaxConsecutive) == "number" and attributes.MaxConsecutive < 1 then table.insert(errors, "MaxConsecutive must be at least 1") end
	if typeof(attributes.MinDepth) == "number" and typeof(attributes.MaxDepth) == "number" then
		if attributes.MinDepth ~= attributes.MinDepth or attributes.MaxDepth ~= attributes.MaxDepth or math.abs(attributes.MinDepth) == math.huge or math.abs(attributes.MaxDepth) == math.huge then
			table.insert(errors, "MinDepth and MaxDepth must be finite numbers")
		elseif attributes.MinDepth < 0 or attributes.MaxDepth < 0 then
			table.insert(errors, `MinDepth and MaxDepth cannot be negative (received MinDepth={attributes.MinDepth}, MaxDepth={attributes.MaxDepth})`)
		elseif attributes.MinDepth % 1 ~= 0 or attributes.MaxDepth % 1 ~= 0 then
			table.insert(errors, `MinDepth and MaxDepth must be whole room indexes (received MinDepth={attributes.MinDepth}, MaxDepth={attributes.MaxDepth})`)
		elseif attributes.MinDepth > attributes.MaxDepth then
			table.insert(errors, `MinDepth exceeds MaxDepth (received MinDepth={attributes.MinDepth}, MaxDepth={attributes.MaxDepth}); edit the Model attributes while Play mode is stopped`)
		end
	end
	local entrance = childPart(model, Constants.EntranceName, errors)
	local exit = childPart(model, Constants.ExitName, errors)
	local bounds = childPart(model, Constants.BoundsName, errors)
	if bounds and not bounds.CanQuery then table.insert(errors, "Bounds.CanQuery must be true so overlap validation can detect other room Bounds") end
	local connectorParts: {[string]: BasePart?} = { Entrance = entrance, Exit = exit }
	for label, part in connectorParts do
		if part and not part:FindFirstChild(Constants.ConnectorName) then table.insert(errors, `{label} is missing Connector Attachment`)
		elseif part then
			local connector = part:FindFirstChild(Constants.ConnectorName)
			if not connector or not connector:IsA("Attachment") then table.insert(errors, `{label}.Connector must be an Attachment`) end
		end
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") and not descendant.Anchored then table.insert(errors, `{descendant:GetFullName()} is unanchored`) end
	end
	local entranceType, exitType = attributes.EntranceType, attributes.ExitType
	local compatibility = self.Config.ConnectorCompatibility
	if typeof(entranceType) == "string" and compatibility[entranceType] == nil then table.insert(errors, `unknown EntranceType {entranceType}`) end
	if typeof(exitType) == "string" and compatibility[exitType] == nil then table.insert(errors, `unknown ExitType {exitType}`) end
	return errors, attributes
end

function Registry.Scan(self: any): (boolean, {string})
	table.clear(self.Templates); table.clear(self.Errors)
	local root = ServerStorage:FindFirstChild("RoomTemplates")
	if not root then table.insert(self.Errors, "ServerStorage.RoomTemplates does not exist"); return false, self.Errors end
	local seenIds: {[string]: Model}={}
	for _, object in root:GetDescendants() do
		if not object:IsA("Model") then continue end
		-- A template is a top-level Model anywhere below RoomTemplates; nested Models are room contents.
		local ancestor = object.Parent
		local nestedInModel = false
		while ancestor and ancestor ~= root do if ancestor:IsA("Model") then nestedInModel = true; break end; ancestor = ancestor.Parent end
		if nestedInModel then continue end
		local errors: {string}, a: any = self:_validate(object)
		local id = a and a.RoomId
		if typeof(id) == "string" then
			if seenIds[id] then table.insert(errors, `duplicate RoomId {id}; first used by {seenIds[id]:GetFullName()}`) else seenIds[id]=object end
		end
		if #errors > 0 then
			for _, message in errors do table.insert(self.Errors, `{object:GetFullName()}: {message}`) end
			continue
		end
		self.Templates[id :: string] = { Id=id, Model=object, Theme=a.Theme, Category=a.Category, Weight=a.Weight, MinDepth=a.MinDepth, MaxDepth=a.MaxDepth,
			Difficulty=a.Difficulty, CooldownRooms=a.CooldownRooms, MaxConsecutive=a.MaxConsecutive, EntranceType=a.EntranceType, ExitType=a.ExitType,
			IsUnique=a.IsUnique, IsSpecial=a.IsSpecial, CanBeDark=a.CanBeDark, AllowsEntities=a.AllowsEntities, Attributes=a }
	end
	if next(self.Templates) == nil then table.insert(self.Errors, "RoomTemplates contains no valid template Models") end
	for _, message in self.Errors do warn("[RoomRegistry] " .. message) end
	return #self.Errors == 0, self.Errors
end
function Registry.GetAll(self: any): {any} local result: {any} = {}; for _, v in self.Templates do table.insert(result, v) end; table.sort(result, function(a: any,b: any): boolean return a.Id < b.Id end); return result end
function Registry.Get(self: any,id: string): any? return self.Templates[id] end
return Registry
