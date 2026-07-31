--Modulescript in Services folder in ServerScriptService
--!strict
local RunManager={}; RunManager.__index=RunManager
function RunManager.new(config:any,registry:any,generator:any,lifecycle:any,cleanup:any,tracker:any,pacing:any): any
	return setmetatable({Config=config,Registry=registry,Generator=generator,Lifecycle=lifecycle,Cleanup=cleanup,Tracker=tracker,Pacing=pacing,State=nil :: any?},RunManager)
end
function RunManager._theme(self:any,depth:number):string for _,range: any in self.Config.ThemeProgression do if depth>=range.MinDepth and depth<=range.MaxDepth then return range.Theme end end; return "Hotel" end
function RunManager._schedule(self:any,random:Random):{[number]:any}
	local result={}; for _,definition in self.Config.SpecialRoomRanges do local available={}; for i=definition.Min,definition.Max do if not result[i] then table.insert(available,i) end end; assert(#available>0,`no free position for {definition.Kind}`); local index=available[random:NextInteger(1,#available)]; result[index]={Kind=definition.Kind,RoomId=definition.RoomId,Category=definition.Category,Requires=definition.Requires,Grants=definition.Grants} end; return result
end
function RunManager.StartRun(self:any,customSeed:number?):any
	if self.State then self:StopRun() end
	local seed=customSeed or math.floor(os.clock()*1000000)%2147483647; local random=Random.new(seed)
	local state: any={Seed=seed,Random=random,CurrentRoomIndex=0,GeneratedUntilIndex=-1,RoomHistory={} :: {string},UsedUniqueRooms={} :: {[string]: boolean},ScheduledSpecialRooms=self:_schedule(random),CurrentPacingState=self.Pacing:Create(random),ActiveRooms={} :: {[number]: any},Prerequisites={} :: {[string]: boolean},Theme=self:_theme(0),IsReady=false}
	self.State=state; self.Tracker:SetRun(state)
	local generated, generationError=pcall(function() self.Generator:GenerateAhead(state,self.Config.Generation.RoomsAhead) end)
	if not generated then self:StopRun(); error(`[RunManager] initial room window failed; no doors were enabled: {generationError}`) end
	self.Lifecycle:Activate(assert(state.ActiveRooms[0])); state.IsReady=true
	print(`[RunManager] started deterministic run with seed {seed}`); return state
end
function RunManager.GetState(self:any):any? return self.State end
function RunManager.Advance(self:any,player:Player,fromIndex:number)
	local run: any=self.State; assert(run,"no run"); assert(fromIndex==run.CurrentRoomIndex,"stale door"); local current: any=run.ActiveRooms[fromIndex]; assert(current,"current room is missing"); self.Lifecycle:Complete(current)
	local nextIndex=run.CurrentRoomIndex+1
	if not run.ActiveRooms[nextIndex] then self.Generator:GenerateOne(run,nextIndex,current) end
	run.CurrentRoomIndex=nextIndex; run.Theme=self:_theme(run.CurrentRoomIndex); local nextRoom: any=run.ActiveRooms[run.CurrentRoomIndex]; assert(nextRoom,"next room generation failed"); self.Lifecycle:Activate(nextRoom); self.Tracker:MarkEntered(player,run.CurrentRoomIndex)
	self.Generator:GenerateAhead(run,run.CurrentRoomIndex+self.Config.Generation.RoomsAhead); self:CleanupOldRooms()
end
function RunManager.CleanupOldRooms(self:any)
	local run: any=self.State; assert(run,"no run"); local lowest:number=self.Tracker:GetLowestActive(run.CurrentRoomIndex); local threshold:number=lowest-self.Config.Generation.RoomsBehind
	for index,room in run.ActiveRooms do if index<threshold and next(room.Occupants)==nil then self.Cleanup:Destroy(room); run.ActiveRooms[index]=nil end end
	local activeCount=0; for _ in run.ActiveRooms do activeCount+=1 end
	if activeCount>self.Config.Generation.MaximumActiveRooms and self.Config.Debug.Enabled then warn(`[RunManager] {activeCount} rooms retained (limit {self.Config.Generation.MaximumActiveRooms}) because a player may still need them`) end
end
function RunManager.StopRun(self:any) local state: any=self.State; if not state then return end; for _,room in state.ActiveRooms do self.Cleanup:Destroy(room) end; self.State=nil; self.Tracker:SetRun(nil) end
return RunManager
