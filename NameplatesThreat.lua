local offTanks = {}
local playerRole

local function updatePlayerRole()
    playerRole = GetSpecializationRole(GetSpecialization())
end

local function updateHealthColor(frame, ...)
    if frame.threat then
        local forceUpdate = ...
        local previousColor = frame.threat.previousColor
        if forceUpdate
                or previousColor.r ~= frame.healthBar.r
                or previousColor.g ~= frame.healthBar.g
                or previousColor.b ~= frame.healthBar.b then
            frame.healthBar:SetStatusBarColor(frame.threat.color.r,
                frame.threat.color.g,
                frame.threat.color.b)

            frame.threat.previousColor.r = frame.healthBar.r
            frame.threat.previousColor.g = frame.healthBar.g
            frame.threat.previousColor.b = frame.healthBar.b
        end
    end
end

-- This function is called constantly during combat. The color is only going to be reset after it was actually changed.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", updateHealthColor)

local function collectOffTanks()
    local collectedTanks = {}
    local unitPrefix, unit, i

    if IsInRaid() then
        unitPrefix = "raid"
    else
        unitPrefix = "party"
    end

    for i = 1, GetNumGroupMembers() do
        unit = unitPrefix .. i
        if UnitGroupRolesAssigned(unit) == "TANK" and not UnitIsUnit(unit, "player") then
            table.insert(collectedTanks, unit)
        end
    end

    return collectedTanks
end

local function isOfftankTanking(mobUnit)
    local unit, situation
    for _, unit in ipairs(offTanks) do
        situation = UnitThreatSituation(unit, mobUnit) or -1
        if situation > 1 then
            return true
        end
    end

    return false
end

local function updateThreatColor(frame)
    local unit = frame.unit
    local reaction = UnitReaction("player", unit)
    if reaction
            and reaction < 5
            and (reaction < 4 or CompactUnitFrame_IsOnThreatListWithPlayer(frame.displayedUnit))
            and not UnitIsPlayer(unit)
            and not CompactUnitFrame_IsTapDenied(frame) then
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
        if not frame.threat or frame.threat.lastSituation ~= threat then
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

            if not frame.threat then
                frame.threat = {
                    ["color"] = {},
                    ["previousColor"] = {},
                };
            end

            frame.threat.lastSituation = threat
            frame.threat.color.r = r
            frame.threat.color.g = g
            frame.threat.color.b = b

            updateHealthColor(frame, true)
        end
    else
        frame.threat = nil
    end
end

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

        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
            updateThreatColor(nameplate.UnitFrame)
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not playerRole then
            updatePlayerRole()
        end

        local unitId = arg1
        local callback = function()
            local plate = C_NamePlate.GetNamePlateForUnit(unitId)
            if plate then
                updateThreatColor(plate.UnitFrame)
            end
        end

        callback()
        C_Timer.NewTimer(0.3, callback)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        C_NamePlate.GetNamePlateForUnit(arg1).UnitFrame.threat = nil
    elseif event == "PLAYER_ROLES_ASSIGNED" then
        offTanks = collectOffTanks()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        updatePlayerRole()
    end
end);