--!strict
-- Intentionally contains no entity implementation. This demonstrates the extension boundary.
local EntityDirector={}
function EntityDirector.Attach(lifecycle:any):()->()
	return lifecycle:Subscribe("Activated",function(room:any)
		if room.Model:GetAttribute("AllowsEntities") then
			-- A future director may make its one deterministic decision here.
		end
	end)
end
return EntityDirector
