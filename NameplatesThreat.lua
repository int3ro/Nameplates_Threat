local nextUpdate = 0.2 -- set this 0 to disable continuous nameplate updates every x seconds
local thisUpdate = 0
local playerRole = 0
local offTanks = {}
local nonTanks = {}

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

local function getGroupRoles()
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
            if isInRaid and unitRole ~= "TANK" then
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

local function threatSituation(monster)
    local threatStatus = -1
    local tankValue    =  0
    local offTankValue =  0
    local playerValue  =  0
    local nonTankValue =  0
    local unit, isTanking, status, threatValue

    -- store if an offtank is tanking, or store their threat value if higher than others
    for _, unit in ipairs(offTanks) do
        isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
        if isTanking then
            threatStatus = status + 2
            tankValue = threatValue
        elseif status and threatValue > offTankValue then
            offTankValue = threatValue
        elseif UnitIsUnit(unit, monster .. "target") then
            threatStatus = 5 -- ensure threat status if monster is targeting an offtank
        end
    end
    -- store if the player is tanking, or store their threat value if higher than others
    isTanking, status, _, _, threatValue = UnitDetailedThreatSituation("player", monster)
    if isTanking then
        threatStatus = status
        tankValue = threatValue
    elseif status then
        playerValue = threatValue
    end
    -- store if a non-tank is tanking, or store their threat value if higher than others
    for _, unit in ipairs(nonTanks) do
        isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
        if isTanking then
            threatStatus = 3 - status
            tankValue = threatValue
        elseif status and threatValue > nonTankValue then
            nonTankValue = threatValue
        elseif UnitIsUnit(unit, monster .. "target") then
            threatStatus = 0 -- ensure threat status if monster is targeting a nontank
        end
    end
    -- deliver the stored information describing threat situation for this monster
    return threatStatus, tankValue, offTankValue, playerValue, nonTankValue
end

local function updateThreatColor(frame)
    local unit = frame.unit -- variable also reused for the threat ratio further down

    if UnitCanAttack("player", unit) and (UnitAffectingCombat(unit) or UnitReaction(unit, "player") < 4)
        and not UnitIsPlayer(unit) and not CompactUnitFrame_IsTapDenied(frame) then

        --[[Custom threat situation nameplate coloring:
           -1 = no threat data (monster not in combat).
            0 = a non tank is tanking by threat.
            1 = a non tank is tanking by force.
            2 = player tanking monster by force.
            3 = player tanking monster by threat.
           +4 = another tank is tanking by force.
           +5 = another tank is tanking by threat.
        ]]--
        local status, tank, offtank, player, nontank = threatSituation(unit)

        -- if CPU heavy features are enabled, compare highest group threat with tank for color gradient
        if nextUpdate > 0 and status > -1 then
            if playerRole == "TANK" then
                if status == 0 or status == 1 then
                    unit = math.max(offtank, player)
                else -- you or an offtank are tanking the monster
                    unit = nontank
                end
            else
                if status == 2 or status == 3 then
                    unit = math.max(offtank, nontank)
                else -- someone is tanking the monster for you
                    unit = player
                end
            end
            if status == 1 or status == 2 or status == 4 then
                unit = tank / math.max(unit, 1)
            else -- monster is tanked by someone via threat
                unit = unit / math.max(tank, 1)
            end
            unit = math.min(unit, 1)
        else
            unit = 0
        end
        if status > -1 and playerRole ~= "TANK" and status < 4 then
            status = 3 - status
        end -- invert colors when not a tank role and no group tanks are tanking

        -- only recalculate color when situation was actually changed with gradient toward sibling color
        if not frame.threat or frame.threat.lastStatus ~= status or frame.threat.lastRatio ~= unit then
            local r, g, b = 0.29,0.29,0.29  -- dark outside combat (colors below 4 inverted for nontanks)

            if status >= 5 then             -- tanks tanking by threat
                r, g, b = 0.00, 0.85, 0.00  -- green/gray   no problem
                r = r + unit * 0.69
                g = g - unit * 0.16
                b = b + unit * 0.69
            elseif status >= 4 then         -- tanks tanking by force
                r, g, b = 0.69, 0.69, 0.69  -- gray/green   no problem
                r = r - unit * 0.69
                g = g + unit * 0.16
                b = b - unit * 0.69
            elseif status >= 3 then         -- player tanking by threat
                r, g, b = 0.69, 0.69, 0.69  -- gray/yellow  disengage
                r = r + unit * 0.31
                g = g + unit * 0.31
                b = b - unit * 0.22
            elseif status >= 2 then         -- player tanking by force
                r, g, b = 1.00, 1.00, 0.47  -- yellow/gray  attack soon
                r = r - unit * 0.31
                g = g - unit * 0.31
                b = b + unit * 0.22
            elseif status >= 1 then         -- others tanking by force
                r, g, b = 1.00, 0.60, 0.00  -- orange/red   taunt now
                g = g - unit * 0.60
            elseif status >= 0 then         -- others tanking by threat
                r, g, b = 1.00, 0.00, 0.00  -- red/orange   attack now
                g = g + unit * 0.60
            end

            if not frame.threat then
                frame.threat = {
                    ["color"] = {},
                    ["previousColor"] = {},
                };
            end

            frame.threat.lastStatus = status
            frame.threat.lastRatio = unit
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
myFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
myFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "UNIT_THREAT_SITUATION_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        local callback = function()
            for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                updateThreatColor(nameplate.UnitFrame)
            end
            thisUpdate = 0
        end
        if event ~= "PLAYER_REGEN_ENABLED" then
            callback()
        else
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
    elseif event == "PLAYER_ROLES_ASSIGNED" or event == "RAID_ROSTER_UPDATE" or
           event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        offTanks, nonTanks = getGroupRoles()
        playerRole = GetSpecializationRole(GetSpecialization())
    end
end);
if nextUpdate > 0 then -- one nameplate updated every x seconds (increased CPU usage)
    myFrame:SetScript("OnUpdate", function(self, elapsed)
        thisUpdate = thisUpdate + elapsed
        if thisUpdate >= nextUpdate then
            for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                updateThreatColor(nameplate.UnitFrame)
            end
            thisUpdate = 0
        end
    end);
end -- remember "/console reloadui" for any script changes to take effect