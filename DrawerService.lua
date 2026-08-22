--!strict
-- ModuleScript: ServerScriptService/Services/DrawerService
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationConfig: any = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("AnimationConfig"))
local InteractionConfig: any = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("InteractionConfig"))

local DrawerService = {}
DrawerService.__index = DrawerService

type ActiveRecord = {
	Kind: string,
	Generation: number,
	Tween: Tween?,
	Cancel: (() -> ())?,
}

type ObjectAnimationApi = {
	CanPlay: (Instance, string) -> boolean,
	Play: (Instance, string, number?) -> any?,
	PreloadTarget: (Instance, { string }) -> (),
}

function DrawerService.new(loot: any?, objectAnimation: ObjectAnimationApi?): any
	return setmetatable({
		Loot = loot,
		ObjectAnimation = objectAnimation,
		Active = {} :: { [Instance]: ActiveRecord },
		Closed = {} :: { [Instance]: CFrame },
		Generations = {} :: { [Instance]: number },
		ModeWarnings = {} :: { [Instance]: boolean },
	}, DrawerService)
end

-- A furniture prop can contain several drawer Models. Never let a parent
-- interactable borrow parts, attachments, or prompts from a nested interactable.
local function isOwnedBy(target: Instance, value: Instance): boolean
	local cursor = value.Parent
	while cursor ~= nil and cursor ~= target do
		if typeof(cursor:GetAttribute("InteractionId")) == "string" then return false end
		cursor = cursor.Parent
	end
	return cursor == target
end

local function findOwned(target: Instance, predicate: (Instance) -> boolean): Instance?
	for _, value in target:GetDescendants() do
		if predicate(value) and isOwnedBy(target, value) then return value end
	end
	return nil
end

local function promptFor(target: Instance): ProximityPrompt?
	local value = findOwned(target, function(candidate: Instance): boolean return candidate:IsA("ProximityPrompt") end)
	return if value ~= nil then value :: ProximityPrompt else nil
end

local function namedOwned(target: Instance, name: string): Instance?
	return findOwned(target, function(candidate: Instance): boolean return candidate.Name == name end)
end

local function setPrompt(target: Instance, enabled: boolean)
	local prompt = promptFor(target)
	if prompt ~= nil then
		prompt.Enabled = enabled
		local text = target:GetAttribute("InteractionText")
		if typeof(text) == "string" and text ~= "" then prompt.ActionText = text end
	end
end

local function configurePromptMount(target: Instance)
	local prompt = promptFor(target)
	if prompt == nil then
		warn(`[DrawerService] {target:GetFullName()} has no owned ProximityPrompt; parent one to its moving handle or to an Attachment inside that handle`)
		return
	end
	local mount = prompt.Parent
	local validMount = mount ~= nil and (mount:IsA("BasePart") or (mount:IsA("Attachment") and mount.Parent ~= nil and mount.Parent:IsA("BasePart")))
	if not validMount then
		warn(`[DrawerService] {prompt:GetFullName()} must be parented to the moving handle BasePart/MeshPart or to an Attachment inside it`)
	end
	-- Keep Roblox's displayed activation radius consistent with the authoritative
	-- server distance. The server still performs distance and line-of-sight checks.
	local rawDistance = target:GetAttribute("MaxDistance")
	local targetDistance = if typeof(rawDistance) == "number" then rawDistance else InteractionConfig.DefaultDistance
	prompt.MaxActivationDistance = math.min(prompt.MaxActivationDistance, math.max(0, targetDistance), InteractionConfig.MaxServerDistance)
end

function DrawerService._finish(self: any, target: Instance, generation: number, opening: boolean)
	local active: ActiveRecord? = self.Active[target]
	if active == nil or active.Generation ~= generation or target.Parent == nil then
		return
	end

	self.Active[target] = nil
	target:SetAttribute("Opened", opening)
	target:SetAttribute("InteractionId", if opening then "CloseDrawer" else "OpenDrawer")
	target:SetAttribute("InteractionText", if opening then "Close" else "Open")
	target:SetAttribute("Enabled", true)
	setPrompt(target, true)

	local loot: any = self.Loot
	if loot ~= nil then
		loot:SetDrawerOpen(target, opening)
	end

	if AnimationConfig.ObjectAnimationDebug then
		print(`[DrawerService] complete target={target:GetFullName()} opened={opening} generation={generation}`)
	end
end

function DrawerService._mode(self: any, target: Instance, animationKey: string): string
	local raw = target:GetAttribute("ObjectMotionMode")
	if raw == "Animation" or raw == "AttachmentTween" then
		return raw
	end

	local objectAnimation: ObjectAnimationApi? = self.ObjectAnimation
	local canAnimate = false
	if objectAnimation ~= nil then
		canAnimate = objectAnimation.CanPlay(target, animationKey)
	end

	-- A rigged drawer is always an animation drawer, even while its profile is
	-- misconfigured. Treating a missing clip as a tween caused the misleading
	-- Drawer BasePart warning and could attempt invalid nil casts.
	local hasController = findOwned(target, function(candidate: Instance): boolean return candidate:IsA("AnimationController") end) ~= nil
	local selected = if hasController or canAnimate then "Animation" else "AttachmentTween"
	if AnimationConfig.ObjectAnimationDebug and self.ModeWarnings[target] ~= true then
		self.ModeWarnings[target] = true
		warn(`[DrawerService] {target:GetFullName()} has no ObjectMotionMode; selected {selected}`)
	end
	return selected
end

function DrawerService.RegisterRoom(self: any, room: any)
	for _, value: Instance in room.Model:GetDescendants() do
		local interactionId = value:GetAttribute("InteractionId")
		if interactionId == "OpenDrawer" or interactionId == "CloseDrawer" then
			-- Normalize authored state so every nested drawer begins independently.
			local opened = value:GetAttribute("Opened") == true
			value:SetAttribute("InteractionId", if opened then "CloseDrawer" else "OpenDrawer")
			value:SetAttribute("InteractionText", if opened then "Close" else "Open")
			if value:GetAttribute("Enabled") == nil then value:SetAttribute("Enabled", true) end
			-- Cabinet geometry surrounding a child drawer commonly blocks a ray to
			-- the handle. Drawers default to distance validation unless the author
			-- explicitly opts into strict line-of-sight with true.
			if value:GetAttribute("RequiresLineOfSight") == nil then value:SetAttribute("RequiresLineOfSight", false) end
			configurePromptMount(value)
			setPrompt(value, value:GetAttribute("Enabled") ~= false)
			local objectAnimation: ObjectAnimationApi? = self.ObjectAnimation
			if objectAnimation ~= nil then objectAnimation.PreloadTarget(value, { "DrawerOpen", "DrawerClose" }) end
		end
	end
end

function DrawerService.Toggle(self: any, _player: Player, target: Instance)
	if self.Active[target] ~= nil then
		return
	end

	local drawerValue = namedOwned(target, "Drawer")
	local opening = target:GetAttribute("Opened") ~= true
	local animationKey = if opening then "DrawerOpen" else "DrawerClose"
	local mode = self:_mode(target, animationKey)
	-- Animated drawers are positioned by their rig/keyframes and do not need
	-- legacy placement attachments. Only validate those for the tween fallback.
	local drawer: BasePart? = if drawerValue ~= nil and drawerValue:IsA("BasePart") then drawerValue else nil
	local openValue = namedOwned(target, "OpenPoint")
	local openPoint: Attachment? = if openValue ~= nil and openValue:IsA("Attachment") then openValue else nil
	if mode == "AttachmentTween" and (drawer == nil or openPoint == nil) then
		warn(`[DrawerService] {target:GetFullName()} uses AttachmentTween and requires a Drawer BasePart and OpenPoint Attachment`)
		return
	end
	if drawer ~= nil and self.Closed[target] == nil then
		self.Closed[target] = drawer.CFrame
	end
	self.Generations[target] = (self.Generations[target] or 0) + 1
	local generation: number = self.Generations[target]

	target:SetAttribute("Enabled", false)
	setPrompt(target, false)

	local objectAnimation: ObjectAnimationApi? = self.ObjectAnimation
	if mode == "Animation" then
		local result: any? = if objectAnimation ~= nil then objectAnimation.Play(target, animationKey, 0) else nil
		if result ~= nil then
			self.Active[target] = { Kind = "Animation", Generation = generation, Cancel = result.Cancel }
			if AnimationConfig.ObjectAnimationDebug then
				print(`[DrawerService] target={target:GetFullName()} direction={if opening then "Open" else "Close"} mode=Animation key={animationKey} initialLength={result.InitialLength} duration={result.Duration} generation={generation}`)
			end
			task.delay(result.Duration, function()
				self:_finish(target, generation, opening)
			end)
			return
		end
		-- An animated rig intentionally has no legacy Drawer BasePart. Never cast
		-- nil tween parts or move it with an unrelated fallback animation.
		target:SetAttribute("Enabled", true)
		setPrompt(target, true)
		warn(`[DrawerService] {target:GetFullName()} uses Animation mode but {animationKey} is unavailable. Check its AnimationController, Animator, ObjectAnimationProfile, and published asset permissions`)
		return
	end

	local closedPoint = namedOwned(target, "ClosedPoint")
	-- Narrowed above for AttachmentTween mode.
	local tweenDrawer = drawer :: BasePart
	local tweenOpenPoint = openPoint :: Attachment
	local destination: CFrame
	if opening then
		destination = tweenOpenPoint.WorldCFrame
	elseif closedPoint ~= nil and closedPoint:IsA("Attachment") then
		destination = closedPoint.WorldCFrame
	else
		destination = self.Closed[target] :: CFrame
	end

	local durationValue = target:GetAttribute("DrawerTweenTime")
	local duration = if typeof(durationValue) == "number" then math.clamp(durationValue, 0.05, 3) else 0.55
	tweenDrawer.Anchored = true
	local tween = TweenService:Create(tweenDrawer, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = destination })
	self.Active[target] = { Kind = "AttachmentTween", Generation = generation, Tween = tween }
	if AnimationConfig.ObjectAnimationDebug then
		print(`[DrawerService] target={target:GetFullName()} direction={if opening then "Open" else "Close"} mode=AttachmentTween key=none initialLength=0 duration={duration} generation={generation}`)
	end
	tween.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed then
			self:_finish(target, generation, opening)
		end
	end)
	tween:Play()
end

function DrawerService.CleanupRoom(self: any, room: any)
	for target, record: ActiveRecord in self.Active do
		if target:IsDescendantOf(room.Model) then
			self.Generations[target] = (self.Generations[target] or 0) + 1
			local activeTween = record.Tween
			if activeTween ~= nil then
				activeTween:Cancel()
			end
			local cancel = record.Cancel
			if cancel ~= nil then
				cancel()
			end
			self.Active[target] = nil
		end
	end

	for target in self.Closed do
		if target:IsDescendantOf(room.Model) then
			self.Closed[target] = nil
		end
	end
end

return DrawerService
