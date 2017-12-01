local offTanks = {}
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
            if unitRole == "TANK" then
                table.insert(collectedTanks, unit)
            elseif isInRaid and unitRole == "NONE" then
                local _, _, _, _, _, _, _, _, _, raidRole = GetRaidRosterInfo(i)
                if raidRole == "MAINTANK" then
                    table.insert(collectedTanks, unit)
                end
            end
        end
    end

    return collectedTanks
end

local function isOfftankTanking(mobUnit)
    local unit, situation
    for _, unit in ipairs(offTanks) do
        situation = UnitThreatSituation(unit, mobUnit) or -1
        if situation > 1 then
            return unit
        end
    end

    return nil
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
        local _, threat, percent = UnitDetailedThreatSituation("player", unit)
        if not threat then
            if UnitAffectingCombat(unit) then
                threat = 0
            else
                threat = -1
            end
            percent = 0
        else
            if percent > 100 then
                percent = percent - 100
            end
            percent = math.min(1, percent / 100)
        end
        if playerRole == "TANK" and threat < 2 and isOfftankTanking(unit) then
            threat = 4
        end

        -- only recalculate color when situation was actually changed
        if not frame.threat or frame.threat.lastSituation ~= threat then
            local r, g, b = 0.2, 0.5, 0.9       -- blue for unknown threat
            if playerRole == "TANK" then
                if threat >= 4 then             -- others tanking offtank
                    r = r - percent * 0.2       -- blue         no problem
                    b = b - percent * 0.9
                elseif threat >= 3 then         -- player tanking by threat
                    r, g, b = 0.0, 0.5, 0.0     -- green        perfection
                elseif threat >= 2 then         -- player tanking by force
                    r, g, b = 1.0, 1.0, 0.4     -- yellow       attack soon
                elseif threat >= 1 then         -- others tanking by force
                    r, g, b = 1.0, 0.5, 0.0     -- orange       taunt now
                    g = g + percent * 0.5
                    b = b + percent * 0.4
                elseif threat >= 0 then         -- others tanking by threat
                    r, g, b = 1.0, 0.0, 0.0     -- red          attack now
                    g = g + percent * 0.5
                end
            else
                if threat >= 3 then             -- player tanking by threat
                    r, g, b = 1.0, 0.0, 0.0     -- red          find tank
                elseif threat >= 2 then         -- player tanking by force
                    r, g, b = 1.0, 0.5, 0.0     -- orange       find taunt
                elseif threat >= 1 then         -- others tanking by force
                    r, g, b = 1.0, 1.0, 0.4     -- yellow       disengage
                    g = g - percent * 0.5
                    b = b - percent * 0.4
                elseif threat >= 0 then         -- others tanking by threat
                    r, g, b = 0.0, 0.5, 0.0     -- green        no problem
                    r = r + percent
                    g = g + percent * 0.5
                    b = b + percent * 0.4
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
        offTanks = collectOffTanks()
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