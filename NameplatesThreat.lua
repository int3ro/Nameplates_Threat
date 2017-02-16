local offTanks = {}
local playerRole

local function updatePlayerRole()
    playerRole = GetSpecializationRole(GetSpecialization())
end

local function resetFrame(frame)
    frame.lastThreatSituation = nil
    frame.healthBar.threatColor = nil
    frame.healthBar.previousColor = nil
end

local function updateHealthColor(frame)
    local healthBar = frame.healthBar
    if healthBar.threatColor then
        local previousColor = healthBar.previousColor
        if not previousColor
                or previousColor.r ~= healthBar.r
                or previousColor.g ~= healthBar.g
                or previousColor.b ~= previousColor.b then
            frame.healthBar:SetStatusBarColor(healthBar.threatColor.r, healthBar.threatColor.g, healthBar.threatColor.b)
            healthBar.previousColor = {
                ["r"] = healthBar.r,
                ["g"] = healthBar.g,
                ["b"] = healthBar.b,
            };
        end
    end
end
-- called constantly in combat. so we only reset the color after it was actually changed.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", updateHealthColor)

local function collectOffTanks()
    local collectedTanks = {}
    local unitPrefix

    if IsInRaid() then
        unitPrefix = "raid"
    else
        unitPrefix = "party"
    end

    for i=1, GetNumGroupMembers() do
        local unit = unitPrefix..i
        if UnitGroupRolesAssigned(unit) == "TANK" and not UnitIsUnit(unit, "player") then
            table.insert(collectedTanks, unit)
        end
    end

    return collectedTanks
end

local function isOfftankTanking(mobUnit)
    for i, unit in ipairs(offTanks) do
        local situation = UnitThreatSituation(unit, mobUnit) or -1
        if situation > 1 then
            return true
        end
    end

    return false
end

local function updateThreatColor(frame)
    if UnitIsEnemy("player", frame.unit) and not CompactUnitFrame_IsTapDenied(frame) then
        --[[
            threat:
            -1 = not on threat table.
            0 = not tanking, lower threat than tank.
            1 = not tanking, higher threat than tank.
            2 = insecurely tanking, another unit have higher threat but not tanking.
            3 = securely tanking, highest threat
            9 = offtank is tanking, our created state
        ]] --
        local threat = UnitThreatSituation("player", frame.unit) or -1
        if playerRole == "TANK" and threat < 1 and isOfftankTanking(frame.unit) then
            threat = 9
        end

        -- only recalculate color when situation was actually changed
        if frame.lastThreatSituation == nil or frame.lastThreatSituation ~= threat then

            local r, g, b
            if playerRole == "TANK" then
                if threat == 3 then
                    r, g, b = 0.0, 0.5, 0.0123
                elseif threat == 2 then
                    r, g, b = 1.0, 0.5, 0.0
                elseif threat == 1 then
                    r, g, b = 1.0, 1.0, 0.4
                elseif threat == 9 then
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
            frame.lastThreatSituation = threat
            frame.healthBar.previousColor = nil
            frame.healthBar.threatColor =
            {
                ["r"] = r,
                ["g"] = g,
                ["b"] = b,
            };
            updateHealthColor(frame)
        end
    else
        resetFrame(frame)
    end
end

local myFrame = CreateFrame("frame")
myFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
myFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
myFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
myFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE");
myFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED");
myFrame:RegisterEvent("GROUP_ROSTER_UPDATE");
myFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_THREAT_SITUATION_UPDATE" then
        if not playerRole then
            updatePlayerRole()
        end
        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
            updateThreatColor(nameplate.UnitFrame)
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        updateThreatColor(nameplate.UnitFrame)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        resetFrame(nameplate.UnitFrame)
    elseif event == "PLAYER_ROLES_ASSIGNED" or event == "GROUP_ROSTER_UPDATE" then
        offTanks = collectOffTanks()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        updatePlayerRole()
    end
end);