--!strict
local PacingDirector = {}; PacingDirector.__index = PacingDirector
function PacingDirector.new(config: any): any return setmetatable({ Config = config }, PacingDirector) end
function PacingDirector.Create(self: any,random: Random): any
	local state = self.Config.PacingStates.Calm
	return { Name = "Calm", RoomsInState = 0, TargetDuration = random:NextInteger(state.MinDuration, state.MaxDuration), ConsecutiveDark = 0 }
end
function PacingDirector.GetMultiplier(self: any,runtime: any, template: any): (boolean, number, string?)
	local state = self.Config.PacingStates[runtime.Name]
	if not state.Allowed[template.Category] and not template.IsSpecial then return false, 0, `category blocked by pacing state {runtime.Name}` end
	if not state.AllowsEntities and template.AllowsEntities and template.Category == "Danger" then return false, 0, "entity room blocked during this pacing state" end
	if template.CanBeDark and runtime.ConsecutiveDark >= self.Config.MaximumConsecutiveDarkRooms then return false, 0, "dark-room consecutive limit" end
	return true, state.Preferred[template.Category] or 1, nil
end
function PacingDirector.Commit(self: any,runtime: any, template: any, random: Random)
	runtime.ConsecutiveDark = if template.CanBeDark then runtime.ConsecutiveDark + 1 else 0
	runtime.RoomsInState += 1
	if runtime.RoomsInState >= runtime.TargetDuration then
		local nextName = self.Config.PacingStates[runtime.Name].Next
		local nextState = self.Config.PacingStates[nextName]
		runtime.Name, runtime.RoomsInState = nextName, 0
		runtime.TargetDuration = random:NextInteger(nextState.MinDuration, nextState.MaxDuration)
	end
end
return PacingDirector
