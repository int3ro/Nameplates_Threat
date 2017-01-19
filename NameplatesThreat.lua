local isOfftank = function(target)
    if ( UnitPlayerOrPetInRaid(target) or UnitPlayerOrPetInParty(target) ) then
        if ( not UnitIsUnit("player", target) and UnitGroupRolesAssigned(target) == "TANK" and UnitGroupRolesAssigned("player") == "TANK" ) then
            return true
        end
    end
    return false
end
hooksecurefunc("CompactUnitFrame_OnUpdate", function(frame)
	if C_NamePlate.GetNamePlateForUnit(frame.unit) ~= C_NamePlate.GetNamePlateForUnit("player") 
		and UnitIsEnemy("player", frame.unit) 
		and not UnitIsPlayer(frame.unit) 
		and not CompactUnitFrame_IsTapDenied(frame) then
		--[[
			threat:
			-1 = not on threat table.
			0 = not tanking, lower threat than tank.
			1 = not tanking, higher threat than tank.
			2 = insecurely tanking, another unit have higher threat but not tanking.
			3 = securely tanking, highest threat
		]]--
		local threat = UnitThreatSituation("player", frame.unit) or -1
		if GetSpecializationRole(GetSpecialization()) == "TANK" then
			if threat == 3 then				
				r, g, b = 0.0, 0.5, 0.0
			elseif threat == 2 then				
				r, g, b = 1.0, 0.5, 0.0
			elseif threat == 1 then				
				r, g, b = 1.0, 1.0, 0.4
			elseif isOfftank(frame.unit.."target") then
				r, g, b = 0.2, 0.5, 0.9
			else
				r, g, b = 1.0, 0.0, 0.0
			end
		else
			if threat >= 2 then
				r, g, b = 1.0, 0.0, 0.0
			elseif threat == 1 then 							
				r, g, b = 1.0, 1.0, 0.4	
			elseif threat == 0 then
				r, g, b = 0.0, 0.5, 0.0
			else
				r, g, b = 1.0, 0.0, 0.0				
			end
		end
		frame.healthBar:SetStatusBarColor(r, g, b, 1)
	end
end)
