--Modulescript in Services folder in ServerScriptService
--!strict
local RoomSelector = {}; RoomSelector.__index = RoomSelector
function RoomSelector.new(registry: any, pacing: any, config: any): any return setmetatable({ Registry=registry, Pacing=pacing, Config=config }, RoomSelector) end
local function recentDistance(history: {string}, id: string): number?
	for offset = 0, #history - 1 do if history[#history-offset] == id then return offset end end
	return nil
end
local function consecutive(history: {string}, id: string): number local n=0; for i=#history,1,-1 do if history[i]~=id then break end; n+=1 end; return n end
function RoomSelector.Select(self: any,run: any, depth: number, requiredEntrance: string?, excluded: {[string]: boolean}?, placementRecovery: boolean?): (any?, any)
	local debugInfo: any = { ValidCandidates={} :: {any}, RejectedCandidates={} :: {any}, SelectedTemplate=nil }
	local scheduled = run.ScheduledSpecialRooms[depth]
	local mandatory = self.Config.MandatoryRooms[depth]
	local targetDifficulty: number = depth * (self.Config.Difficulty.PerDepth :: number)
	for _, template: any in self.Registry:GetAll() do
		local reason: string? = nil
		if excluded and excluded[template.Id] then reason="excluded after failed placement"
		elseif template.Theme ~= run.Theme then reason=`theme {template.Theme} != {run.Theme}`
		elseif depth < template.MinDepth or depth > template.MaxDepth then reason="outside depth range"
		elseif requiredEntrance and not (self.Config.ConnectorCompatibility[requiredEntrance] and self.Config.ConnectorCompatibility[requiredEntrance][template.EntranceType]) then reason=`connector {requiredEntrance} cannot connect to {template.EntranceType}`
		elseif template.IsUnique and run.UsedUniqueRooms[template.Id] then reason="unique room already used"
		else
			local distance = recentDistance(run.RoomHistory, template.Id)
			-- Cooldowns shape normal selection, but must not make placement retries
			-- impossible after a different template's Bounds failed. Recovery still
			-- honors theme, depth, connectors, uniqueness and scheduled rooms.
			if not placementRecovery and distance and distance < template.CooldownRooms then reason=`cooldown: last used {distance} rooms ago`
			elseif not placementRecovery and consecutive(run.RoomHistory, template.Id) >= template.MaxConsecutive then reason="MaxConsecutive reached"
			elseif mandatory and template.Id ~= mandatory then reason=`mandatory room is {mandatory}`
			elseif scheduled and ((scheduled.RoomId and template.Id ~= scheduled.RoomId) or (scheduled.Category and template.Category ~= scheduled.Category)) then reason=`scheduled {scheduled.Kind} room required`
			elseif scheduled and scheduled.Requires and not run.Prerequisites[scheduled.Requires] then reason=`missing prerequisite {scheduled.Requires}` end
		end
		local pacingMultiplier: number = 1
		if not reason then local allowed, multiplier, pacingReason = self.Pacing:GetMultiplier(run.CurrentPacingState, template); if not allowed then reason=pacingReason else pacingMultiplier=multiplier end end
		if reason then table.insert(debugInfo.RejectedCandidates, { Id=template.Id, Reason=reason, BaseWeight=template.Weight, AdjustedWeight=0 })
		else
			local difficultyDelta = math.abs(template.Difficulty-targetDifficulty)
			local difficultyMultiplier = 1 / (1 + difficultyDelta / self.Config.Difficulty.Tolerance)
			local repeatMultiplier = if not placementRecovery and run.RoomHistory[#run.RoomHistory] == template.Id then self.Config.ImmediateRepeatMultiplier else 1
			local darkMultiplier = if template.CanBeDark then self.Config.DarkRoomWeightMultiplier else 1
			local adjusted = template.Weight * pacingMultiplier * difficultyMultiplier * repeatMultiplier * darkMultiplier
			if adjusted > 0 then table.insert(debugInfo.ValidCandidates, { Template=template, Id=template.Id, BaseWeight=template.Weight, AdjustedWeight=adjusted }) else table.insert(debugInfo.RejectedCandidates,{Id=template.Id,Reason="adjusted weight is zero",BaseWeight=template.Weight,AdjustedWeight=0}) end
		end
	end
	local total: number=0; for _, c: any in debugInfo.ValidCandidates do total += c.AdjustedWeight end
	if self.Config.Debug.Enabled and self.Config.Debug.CandidateWeights then
		for _,candidate: any in debugInfo.ValidCandidates do print(`[RoomSelector] depth={depth} {candidate.Id}: {candidate.BaseWeight} -> {candidate.AdjustedWeight}`) end
		for _,candidate: any in debugInfo.RejectedCandidates do print(`[RoomSelector] depth={depth} rejected {candidate.Id}: {candidate.Reason}`) end
	end
	if total <= 0 then
		local fallback: any? = if self.Config.FallbackEnabled then self.Registry:Get(self.Config.FallbackRoomId) else nil
		debugInfo.Error = `No candidate at depth {depth}; rejected: ` .. table.concat((function() local t={}; for _,r in debugInfo.RejectedCandidates do table.insert(t, `{r.Id} ({r.Reason})`) end; return t end)(), ", ")
		local fallbackConnects = fallback and (not requiredEntrance or (self.Config.ConnectorCompatibility[requiredEntrance] and self.Config.ConnectorCompatibility[requiredEntrance][fallback.EntranceType]))
		if fallback and fallbackConnects and not (excluded and excluded[fallback.Id]) then debugInfo.UsedFallback=true; debugInfo.SelectedTemplate=fallback; return fallback,debugInfo end
		return nil, debugInfo
	end
	local roll=run.Random:NextNumber(0,total); local cursor=0
	for _, c: any in debugInfo.ValidCandidates do cursor += c.AdjustedWeight; if roll <= cursor then debugInfo.SelectedTemplate=c.Template; debugInfo.Roll=roll; debugInfo.TotalWeight=total; return c.Template,debugInfo end end
	error("weighted selection invariant failed")
end
return RoomSelector
