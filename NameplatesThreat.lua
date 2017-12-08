local offTanks = {}
local allOther = {}
local playerRole
local lastUpdate = 1 -- Set this to 0 to disable continuous nameplate updates every frame (see code at bottom).

local function updatePlayerRole()
    playerRole = GetSpecializationRole(GetSpecialization())
end

local function resetFrame(frame)
    if frame.threat then
        frame.threat = nil
        frame.healthBar:SetStatusBarColor(frame.healthBar.r, frame.healthBar.g, frame.healthBar.b)
    end
end

local function updateHealthColor(frame, ...)
    if frame.threat then
        local forceUpdate = ...
        local previousColor = frame.threat.previousColor
        if forceUpdate
                or previousColor.r ~= frame.healthBar.r
                or previousColor.g ~= frame.healthBar.g
                or previousColor.b ~= frame.healthBar.b then
            frame.healthBar:SetStatusBarColor(frame.threat.color.r, frame.threat.color.g, frame.threat.color.b)

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
    local collectedOther = {}
    local unitPrefix, unit, i, unitRole
    local isInRaid = IsInRaid()

    if isInRaid then
        unitPrefix = "raid"
    else
        unitPrefix = "party"
    end

    for i = 1, GetNumGroupMembers() do
        unit = unitPrefix .. i
        if not UnitIsUnit(unit, "player") then
            unitRole = UnitGroupRolesAssigned(unit)
            if isInRaid and unitRole == "NONE" then
                _, _, _, _, _, _, _, _, _, unitRole = GetRaidRosterInfo(i)
                if unitRole == "MAINTANK" then
                    unitRole = "TANK"
                end
            end
            if unitRole == "TANK" then
                table.insert(collectedTanks, unit)
            else
                table.insert(collectedOther, unit)
            end
        end
    end

    return collectedTanks, collectedOther
end

local function isOfftankTanking(mobUnit)
    local unit, situation
    for _, unit in ipairs(offTanks) do
        situation = UnitThreatSituation(unit, mobUnit)
        if situation and situation > 1 then
            return unit
        end
    end

    return nil
end

local function otherHighPercent(mobUnit)
    local unitArray, unit, situation
    local highest = 0

    if playerRole == "TANK" then
        unitArray = allOther
    else
        unitArray = offTanks
    end

    for _, unit in ipairs(unitArray) do
        _, _, _, situation = UnitDetailedThreatSituation(unit, mobUnit)
        if situation and situation > highest then
            highest = situation
        end
    end

    return highest
end

local function updateThreatColor(frame)
    if not playerRole then
        updatePlayerRole()
    end

    local unit = frame.unit
    -- http://wowwiki.wikia.com/wiki/API_UnitReaction
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
           +4 = offtank is tanking.
        ]]--
        local _, threat, _, percent = UnitDetailedThreatSituation("player", unit)
        if not threat then
            if UnitAffectingCombat(unit) then
                threat = 0
            else
                threat = -1
            end
            percent = 0
        end
        if playerRole == "TANK" and threat < 2 and isOfftankTanking(unit) then
            threat = 4
            percent = 100
        end
        percent = percent - otherHighPercent(unit)
        percent = math.abs(percent)
        percent = math.min(1, percent / 100)

        -- only recalculate color when situation was actually changed (todo: color by threat diff to next)
        if not frame.threat or frame.threat.lastThreat ~= threat or frame.threat.lastPercent ~= percent then
            local r, g, b = 0.2, 0.5, 0.9       -- blue for unknown threat
            if playerRole == "TANK" then
                if threat >= 4 then             -- others tanking offtank
                    r = r+(1-percent)*0.4       -- blue         no problem
                    g = g-(1-percent)*0.3
                    b = b-(1-percent)*0.1
                elseif threat >= 3 then         -- player tanking by threat
                    r, g, b = 0.0, 0.5, 0.0     -- green        perfection
                    r = r+(1-percent)*1.0
                    g = g+(1-percent)*0.5
                    b = b+(1-percent)*0.4
                elseif threat >= 2 then         -- player tanking by force
                    r, g, b = 1.0, 1.0, 0.4     -- yellow       attack soon
                    r = r-(1-percent)*1.0
                    g = g-(1-percent)*0.5
                    b = b-(1-percent)*0.4
                elseif threat >= 1 then         -- others tanking by force
                    r, g, b = 1.0, 0.5, 0.0     -- orange       taunt now
                    g = g-(1-percent)*0.5
                elseif threat >= 0 then         -- others tanking by threat
                    r, g, b = 1.0, 0.0, 0.0     -- red          attack now
                    g = g+(1-percent)*0.5
                end
            else
                if threat >= 3 then             -- player tanking by threat
                    r, g, b = 1.0, 0.0, 0.0     -- red          find tank
                    g = g+(1-percent)*0.5
                elseif threat >= 2 then         -- player tanking by force
                    r, g, b = 1.0, 0.5, 0.0     -- orange       find taunt
                    g = g-(1-percent)*0.5
                elseif threat >= 1 then         -- others tanking by force
                    r, g, b = 1.0, 1.0, 0.4     -- yellow       disengage
                    r = r-(1-percent)*1.0
                    g = g-(1-percent)*0.5
                    b = b-(1-percent)*0.4
                elseif threat >= 0 then         -- others tanking by threat
                    r, g, b = 0.0, 0.5, 0.0     -- green        no problem
                    r = r+(1-percent)*1.0
                    g = g+(1-percent)*0.5
                    b = b+(1-percent)*0.4
                end
            end

            if not frame.threat then
                frame.threat = {
                    ["color"] = {},
                    ["previousColor"] = {},
                };
            end

            frame.threat.lastThreat = threat
            frame.threat.lastPercent = percent
            frame.threat.color.r = r
            frame.threat.color.g = g
            frame.threat.color.b = b

            updateHealthColor(frame, true)
        end
    else
        resetFrame(frame)
    end
end

local myFrame = CreateFrame("frame")
myFrame:RegisterEvent("PLAYER_REGEN_ENABLED");
myFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE");
myFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED");
myFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
myFrame:RegisterEvent("PLAYER_ROLES_ASSIGNED");
myFrame:RegisterEvent("RAID_ROSTER_UPDATE");
myFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
myFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        local callback = function()
            for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                updateThreatColor(nameplate.UnitFrame)
            end
        end
        callback()
        if event == "PLAYER_REGEN_ENABLED" then
            C_Timer.NewTimer(5.0, callback)
        end -- to ensure colors update when mob is back at their spawn
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local callback = function()
            local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
            if nameplate then
                updateThreatColor(nameplate.UnitFrame)
            end
        end
        callback()
        C_Timer.NewTimer(0.3, callback)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
        if nameplate then
            resetFrame(nameplate.UnitFrame)
        end
    elseif event == "PLAYER_ROLES_ASSIGNED" or event == "RAID_ROSTER_UPDATE" then
        offTanks, allOther = collectOffTanks()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        updatePlayerRole()
    end
end);
if lastUpdate > 0 then -- one nameplate updated on every frame rendered
    myFrame:SetScript("OnUpdate", function(self, elapsed)
        local nameplate = C_NamePlate.GetNamePlates()
        if lastUpdate < #nameplate then
            lastUpdate = lastUpdate + 1
        else
            lastUpdate = 1
        end
        nameplate = nameplate[lastUpdate]
        if nameplate then
            updateThreatColor(nameplate.UnitFrame)
        end
    end);
end -- remember "/console reloadui" for any script changes to take effect