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
-- This function is called constantly during combat. The color is only going to be reset after it was actually changed.
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
    local unit = frame.unit
    if UnitIsEnemy("player", unit) and not CompactUnitFrame_IsTapDenied(frame) then
        --[[
            threat:
            -1 = not on threat table.
            0 = not tanking, lower threat than tank.
            1 = not tanking, higher threat than tank.
            2 = insecurely tanking, another unit have higher threat but not tanking.
            3 = securely tanking, highest threat
            9 = offtank is tanking
        ]] --
        local threat = UnitThreatSituation("player", unit) or -1
        if playerRole == "TANK" and threat < 1 and isOfftankTanking(unit) then
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

local function updateAllNameplates()
    for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
        updateThreatColor(nameplate.UnitFrame)
    end
end

local polishTimer
local myFrame = CreateFrame("frame")
myFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE");
myFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
myFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
myFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED");
myFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
myFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_THREAT_SITUATION_UPDATE" then
        if not playerRole then
            updatePlayerRole()
        end
        updateAllNameplates()

        -- Sometimes single nameplates got the wrong Threatsituation and color.
        -- It keeps that color until this event is called again, which can take a while.
        -- The polishTimer starts after a second without situation update.
        if polishTimer then
            polishTimer:Cancel()
        end
        polishTimer = C_Timer.NewTimer(1, function()
            updateAllNameplates()
            polishTimer = nil
        end)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        updateThreatColor(nameplate.UnitFrame)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        resetFrame(nameplate.UnitFrame)
    elseif event == "PLAYER_ROLES_ASSIGNED" then
        offTanks = collectOffTanks()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        updatePlayerRole()
    end
end);