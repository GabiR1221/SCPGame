--!strict
-- ModuleScript: ServerScriptService/Services/EntityPathUtil
local U={}
local function point(value:Instance?):Vector3? if value and value:IsA("Attachment") then return value.WorldPosition elseif value and value:IsA("BasePart") then return value.Position end; return nil end
function U.RoomPoints(room:any):{Vector3}?
	local folder=room.Model:FindFirstChild("EntityPath"); local points:{Vector3}={}
	if folder then
		local entries:{Instance}=folder:GetChildren()
		table.sort(entries,function(a:Instance,b:Instance):boolean
			local aNumber:number?=tonumber(a.Name)
			local bNumber:number?=tonumber(b.Name)
			if aNumber~=nil and bNumber~=nil then return aNumber<bNumber end
			if aNumber~=nil then return true end
			if bNumber~=nil then return false end
			return a.Name<b.Name
		end)
		for _,entry:Instance in entries do local position=point(entry); if position then table.insert(points,position) end end
	end
	if #points==0 then table.insert(points,room.Entrance.Position); table.insert(points,room.Exit.Position) end
	if #points<2 then return nil end; return points
end
return U
