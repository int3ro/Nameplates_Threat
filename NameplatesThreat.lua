local isOfftank = function(target)
    if (UnitPlayerOrPetInRaid(target) or UnitPlayerOrPetInParty(target)) then
        if (not UnitIsUnit("player", target) and UnitGroupRolesAssigned(target) == "TANK") then
            return true
        end
    end
    return false
end

local updateBarColor = function(frame, playerRole)
    if UnitIsEnemy("player", frame.unit) and not CompactUnitFrame_IsTapDenied(frame) then
        --[[
            threat:
            -1 = not on threat table.
            0 = not tanking, lower threat than tank.
            1 = not tanking, higher threat than tank.
            2 = insecurely tanking, another unit have higher threat but not tanking.
            3 = securely tanking, highest threat
        ]] --
        local threat = UnitThreatSituation("player", frame.unit) or -1
        local r, g, b
        if playerRole == "TANK" then
            if threat == 3 then
                r, g, b = 0.0, 0.5, 0.0123
            elseif threat == 2 then
                r, g, b = 1.0, 0.5, 0.0
            elseif threat == 1 then
                r, g, b = 1.0, 1.0, 0.4
            elseif isOfftank(frame.unit .. "target") then
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
        frame.healthBar:SetStatusBarColor(r, g, b);
        frame.healthBar.threatColor =
        {
            ["r"] = r,
            ["g"] = g,
            ["b"] = b,
        };
    else
        frame.healthBar.threatColor = nil
    end
end

-- called during UNIT_THREAT_SITUATION_UPDATE in friendly unit frames.
hooksecurefunc("CompactUnitFrame_UpdateAggroHighlight", function(frame)
    local playerRole = GetSpecializationRole(GetSpecialization())
    for _, frame in pairs(C_NamePlate.GetNamePlates()) do
        updateBarColor(frame.UnitFrame, playerRole);
    end
end)

-- called constantly in combat. so we only reset the color after it was actually changed.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
    local healthBar = frame.healthBar
    if healthBar.theatColor then
        local previousColor = healthBar.previousColor
        if not previousColor
                or previousColor.r ~= healthBar.r
                or previousColor.g ~= healthBar.g
                or previousColor.b ~= previousColor.b then
            frame.healthBar:SetStatusBarColor(healthBar.theatColor.r, healthBar.theatColor.g, healthBar.theatColor.b);
            healthBar.previousColor = {
                ["r"] = healthBar.r,
                ["g"] = healthBar.g,
                ["b"] = healthBar.b,
            };
        end
    end
end)