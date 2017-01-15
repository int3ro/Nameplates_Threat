local isOfftank = function(target)
    if ( UnitPlayerOrPetInRaid(target) or UnitPlayerOrPetInParty(target) ) then
        if ( not UnitIsUnit("player", target) and UnitGroupRolesAssigned(target) == "TANK" and UnitGroupRolesAssigned("player") == "TANK" ) then
            return true
        end
    end
    return false
end
hooksecurefunc("CompactUnitFrame_OnUpdate", function(frame)
	if C_NamePlate.GetNamePlateForUnit(frame.unit) ~= C_NamePlate.GetNamePlateForUnit("player") and not UnitIsPlayer(frame.unit) and not CompactUnitFrame_IsTapDenied(frame) then
		local threat = UnitThreatSituation("player", frame.unit) or 0
		if GetSpecializationRole(GetSpecialization()) == "TANK" then
			if threat == 3 then
				-- Securely tanking	
				r, g, b = 0, 0.5, 0
			elseif threat == 2 then
				-- Tanking, but somebody else has higher threat (losing threat)
				r, g, b = 1, 0.5, 0		
			elseif threat == 1 then
				-- Not tanking, but higher threat than tank
				r, g, b = 1, 1, 0.4
			else
				-- Not tanking
				local target = frame.unit.."target"
				if isOfftank(target) then
					r, g, b = 0.2, 0.5, 0.9
				else
					r, g, b = 1, 0, 0
				end
			end
		else
			if threat >= 2 then
				-- tanking
				r, g, b = 1, 0.5, 0	
			elseif threat == 1 then
				-- Not tanking, but higher threat than tank				
				r, g, b = 1, 1, 0.4
			else
				-- Not tanking
				r, g, b = 1, 0, 0	
			end
		end
		frame.healthBar:SetStatusBarColor(r, g, b, 1)
	end
end)