--!strict
-- ModuleScript: ServerScriptService/Services/PlayerFrameworkRoomBridge
local B={}
function B.Connect(lifecycle:any,interactions:any,cutscenes:any):{()->()}
	return {
		lifecycle:Subscribe("Loaded",function(room) interactions:RegisterRoom(room); cutscenes:RegisterRoom(room) end),
		lifecycle:Subscribe("Activated",function(room) interactions:SetRoomActive(room.Index,true); cutscenes:SetRoomActive(room.Index,true) end),
		lifecycle:Subscribe("Deactivated",function(room) interactions:SetRoomActive(room.Index,false); cutscenes:SetRoomActive(room.Index,false) end),
		lifecycle:Subscribe("Unloading",function(room) interactions:UnregisterRoom(room.Index); cutscenes:UnregisterRoom(room.Index) end),
	}
end
return B
