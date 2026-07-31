--!strict
local Workspace=game:GetService("Workspace")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Constants=require(ReplicatedStorage.Shared.RoomConstants)
local Generator={}; Generator.__index=Generator
function Generator.new(selector:any,lifecycle:any,pacing:any,config:any,folder:Folder): any return setmetatable({Selector=selector,Lifecycle=lifecycle,Pacing=pacing,Config=config,Folder=folder},Generator) end
local function parts(model:Model):(BasePart,BasePart,BasePart,Attachment)
	local entrance=model:FindFirstChild(Constants.EntranceName)::BasePart; local exit=model:FindFirstChild(Constants.ExitName)::BasePart; local bounds=model:FindFirstChild(Constants.BoundsName)::BasePart
	return entrance,exit,bounds,entrance:FindFirstChild(Constants.ConnectorName)::Attachment
end
function Generator._place(self:any,model:Model, previous:any?)
	-- The first room is already authored at its desired world transform in Studio.
	-- Do not PivotTo(CFrame.new()) here: that erases the template pivot's rotation and
	-- can turn an otherwise correct starter room by 90 degrees when it is cloned.
	if not previous then return end
	local _,_,_,entranceConnector=parts(model)
	local exitConnector=previous.Exit:FindFirstChild(Constants.ConnectorName)::Attachment
	-- Connectors point out of their room. Rotating 180 degrees makes their forward axes oppose.
	local desiredEntrance=exitConnector.WorldCFrame*CFrame.Angles(0,math.pi,0)
	local pivot=model:GetPivot(); model:PivotTo((desiredEntrance*entranceConnector.WorldCFrame:Inverse())*pivot)
end
function Generator._overlaps(self:any,model:Model,bounds:BasePart):(boolean,string?)
	if not self.Config.Generation.CheckBoundsOverlap then return false,nil end
	local parameters=OverlapParams.new(); parameters.FilterType=Enum.RaycastFilterType.Include; parameters.FilterDescendantsInstances={self.Folder}
	local size=Vector3.new(math.max(0.05,bounds.Size.X-0.1),math.max(0.05,bounds.Size.Y-0.1),math.max(0.05,bounds.Size.Z-0.1))
	-- Bounds are the authored spatial contract. Testing every wall/door produced false
	-- positives at a valid shared doorway, so only another room's Bounds can reject.
	for _,part in Workspace:GetPartBoundsInBox(bounds.CFrame,size,parameters) do
		if part.Name==Constants.BoundsName and not part:IsDescendantOf(model) then
			return true,`{bounds:GetFullName()} overlaps {part:GetFullName()}`
		end
	end
	return false,nil
end
function Generator.GenerateOne(self:any,run:any,index:number,previous:any?):any
	local excluded: {[string]: boolean}={}; local required: string?=if previous then previous.Model:GetAttribute("ExitType") :: string? else nil; local diagnostics: {any}={}
	for attempt=1,self.Config.Generation.MaximumGenerationRetries do
		local template: any?,debugInfo: any=self.Selector:Select(run,index,required,excluded); table.insert(diagnostics,debugInfo)
		if not template then
			local failures: {string}={}; for _,info: any in diagnostics do if info.PlacementFailure then table.insert(failures,info.PlacementFailure) end end
			local suffix=if #failures>0 then `; placement failures: {table.concat(failures," | ")}` else ""
			error((debugInfo.Error or `selection failed at room {index}`)..suffix)
		end
		local model: Model=template.Model:Clone(); model.Name=string.format("Room_%04d_%s",index,tostring(template.Id)); model.Parent=self.Folder; self:_place(model,previous)
		local entrance,exit,bounds=parts(model)
		local overlaps,overlapReason=self:_overlaps(model,bounds)
		if overlaps then debugInfo.PlacementFailure=`{template.Id}: {overlapReason or "Bounds overlap"}`; excluded[template.Id]=true; model:Destroy(); continue end
		model:SetAttribute("RoomIndex",index); model:SetAttribute("TemplateId",template.Id); model:SetAttribute("RoomState",Constants.States.Generated)
		local room: any={Index=index,Id=`{run.Seed}:{index}`,TemplateId=template.Id,Model=model,Entrance=entrance,Exit=exit,Bounds=bounds,State=Constants.States.Generated,Seed=run.Seed,Connections={} :: {RBXScriptConnection},CleanupCallbacks={} :: {() -> ()},TemporaryInstances={} :: {Instance},Occupants={} :: {[Player]: boolean}}
		if self.Config.Debug.Enabled and self.Config.Debug.Visuals then
			for _,part in {entrance,exit,bounds} do local box=Instance.new("SelectionBox"); box.Name="RoomDebug"; box.Adornee=part; box.Color3=if part==bounds then Color3.new(1,0.2,0.2) else Color3.new(0.2,1,0.2); box.Parent=model; table.insert(room.TemporaryInstances,box) end
		end
		run.ActiveRooms[index]=room; run.GeneratedUntilIndex=math.max(run.GeneratedUntilIndex,index); table.insert(run.RoomHistory,template.Id)
		if template.IsUnique then run.UsedUniqueRooms[template.Id]=true end
		local scheduled=run.ScheduledSpecialRooms[index]; if scheduled and scheduled.Grants then run.Prerequisites[scheduled.Grants]=true end
		self.Pacing:Commit(run.CurrentPacingState,template,run.Random); self.Lifecycle:Load(room)
		if self.Config.Debug.Enabled then print(`[RoomGenerator] #{index} {template.Id}, pacing={run.CurrentPacingState.Name}`) end
		return room
	end
	local summaries: {string}={}; for attempt,info: any in diagnostics do table.insert(summaries,`attempt {attempt}: {info.Error or (info.SelectedTemplate and info.SelectedTemplate.Id) or "no selection"}`) end
	error(`Room {index} failed placement after {self.Config.Generation.MaximumGenerationRetries} attempts; {table.concat(summaries,"; ")}`)
end
function Generator.GenerateAhead(self:any,run:any,targetIndex:number)
	local capped=math.min(targetIndex,run.CurrentRoomIndex+self.Config.Generation.RoomsAhead)
	for index=run.GeneratedUntilIndex+1,capped do self:GenerateOne(run,index,run.ActiveRooms[index-1]); if self.Config.Generation.GenerationDelay>0 then task.wait(self.Config.Generation.GenerationDelay) end end
end
return Generator
