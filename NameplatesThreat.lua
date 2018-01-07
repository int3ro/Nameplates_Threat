local function defaultVariables()   -- only those variables seen below are used by the addon
    NPTacct = {}
    NPTacct["addonIsActive"] = true -- color by threat those nameplates you can attack
    NPTacct["ignorePlayers"] = true -- ignoring nameplates for player characters
    NPTacct["ignoreNeutral"] = true -- ignoring nameplates for neutral monsters
    NPTacct["ignoreNoGroup"] = true -- ignoring nameplates not fighting your group
    NPTacct["gradientColor"] = true -- update nameplate color gradients (some CPU usage)
    NPTacct["gradientDelay"] = 0.2  -- update nameplate color gradients every x seconds
    NPTacct["nonGroupColor"] = {r=0.15, g=0.15, b=0.15} -- dark   target not in group fight
    NPTacct["youTank5color"] = {r=0.00, g=0.85, b=0.00} -- green  group tanks tank by threat
    NPTacct["youTank4color"] = {r=0.69, g=0.69, b=0.69} -- gray   group tanks tank by force
    NPTacct["youTank3color"] = {r=0.69, g=0.69, b=0.69} -- gray   you are tanking by threat
    NPTacct["youTank2color"] = {r=1.00, g=1.00, b=0.47} -- yellow you are tanking by force
    NPTacct["youTank1color"] = {r=1.00, g=0.60, b=0.00} -- orange others tanking by force
    NPTacct["youTank0color"] = {r=1.00, g=0.00, b=0.00} -- red    others tanking by threat
    NPTacct["nonTankReused"] = true -- reuse flipped colors above when playing as nontank
    NPTacct["nonTank5color"] = {r=0.00, g=0.85, b=0.00} -- green  group tanks tank by threat
    NPTacct["nonTank4color"] = {r=0.69, g=0.69, b=0.69} -- gray   group tanks tank by force
    NPTacct["nonTank3color"] = {r=0.69, g=0.69, b=0.69} -- gray   others tanking by threat
    NPTacct["nonTank2color"] = {r=1.00, g=1.00, b=0.47} -- yellow others tanking by force
    NPTacct["nonTank1color"] = {r=1.00, g=0.60, b=0.00} -- orange you are tanking by force
    NPTacct["nonTank0color"] = {r=1.00, g=0.00, b=0.00} -- red    you are tanking by threat
    NPTacct["storedVersion"] = tonumber(GetAddOnMetadata("NameplatesThreat", "Version"))
end

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
        if forceUpdate or not previousColor
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
    local collectedPlayer, unitPrefix, unit, i, unitRole
    local isInRaid = IsInRaid()

    collectedPlayer = GetSpecializationRole(GetSpecialization())
    if UnitExists("pet") then
        if collectedPlayer == "TANK" then
            table.insert(collectedTanks, "pet")
        else
            table.insert(collectedOther, "pet")
        end
    end
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
            unit = unitPrefix .. "pet" .. i
            if UnitExists(unit) then
                if unitRole == "TANK" then
                    table.insert(collectedTanks, unit)
                else
                    table.insert(collectedOther, unit)
                end
            end
        end
    end
    return collectedTanks, collectedPlayer, collectedOther
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
        elseif threatStatus < 0 and UnitIsUnit(unit, monster .. "target") then
            threatStatus = 5 -- ensure threat status if monster is targeting a tank
        end
    end
    -- store if the player is tanking, or store their threat value if higher than others
    isTanking, status, _, _, threatValue = UnitDetailedThreatSituation("player", monster)
    if isTanking then
        threatStatus = status
        tankValue = threatValue
    elseif status then
        playerValue = threatValue
    elseif threatStatus < 0 and UnitIsUnit("player", monster .. "target") then
        threatStatus = 3 -- ensure threat status if monster is targeting player
    end
    -- store if a non-tank is tanking, or store their threat value if higher than others
    for _, unit in ipairs(nonTanks) do
        isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
        if isTanking then
            threatStatus = 3 - status
            tankValue = threatValue
        elseif status and threatValue > nonTankValue then
            nonTankValue = threatValue
        elseif threatStatus < 0 and UnitIsUnit(unit, monster .. "target") then
            threatStatus = 0 -- ensure threat status if monster is targeting nontank
        end
    end
    if threatStatus > -1 and tankValue <= 0 then
        offTankValue = 0
        playerValue  = 0 -- clear threat values if tank was found through monster target
        nonTankValue = 0
    end
    -- deliver the stored information describing threat situation for this monster
    return threatStatus, tankValue, offTankValue, playerValue, nonTankValue
end

local function updateThreatColor(frame)
    local unit = frame.unit -- variable also reused for the threat ratio further down

    if NPTacct.addonIsActive -- only color nameplates you can attack if addon is active
        and UnitCanAttack("player", unit) and not CompactUnitFrame_IsTapDenied(frame)
        and not (NPTacct.ignorePlayers and UnitIsPlayer(unit))
        and not (NPTacct.ignoreNeutral and UnitReaction(unit, "player") > 3 and
                 not UnitIsFriend(unit .. "target", "player")) then

        --[[Custom threat situation nameplate coloring:
           -1 = no threat data (monster not in combat).
            0 = a non tank is tanking by threat.
            1 = a non tank is tanking by force.
            2 = player tanking monster by force.
            3 = player tanking monster by threat.
           +4 = another tank is tanking by force.
           +5 = another tank is tanking by threat.
        ]]-- situation 0 to 3 flipped later as nontank.
        local status, tank, offtank, player, nontank = threatSituation(unit)

        -- compare highest group threat with tank for color gradient if enabled
        if NPTacct.gradientColor and status > -1 then
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
        end -- flip colors when not a tank role and no group tanks are tanking

        -- only recalculate color when situation was actually changed with gradient toward sibling color
        if not frame.threat or frame.threat.lastStatus ~= status or frame.threat.lastRatio ~= unit then
            local color = NPTacct.nonGroupColor -- dark outside group (status < 4 inverted for nontanks)
            local other = NPTacct.nonGroupColor -- we fade color toward the other if gradient is enabled

            if NPTacct.ignoreNoGroup and status < 0 then
                resetFrame(frame) -- reset frame if monster not fighting group member/pet
                return
            elseif NPTacct.nonTankReused or playerRole == "TANK" then
                if status >= 5 then                 -- tanks tanking via threat
                    color = NPTacct.youTank5color   -- green > gray   no problem
                    other = NPTacct.youTank4color
                elseif status >= 4 then             -- tanks tanking via force
                    color = NPTacct.youTank4color   -- gray > green   no problem
                    other = NPTacct.youTank5color
                elseif status >= 3 then             -- player tanking by threat
                    color = NPTacct.youTank3color   -- gray > yellow  disengage
                    other = NPTacct.youTank2color
                elseif status >= 2 then             -- player tanking by force
                    color = NPTacct.youTank2color   -- yellow > gray  attack soon
                    other = NPTacct.youTank3color
                elseif status >= 1 then             -- others tanking by force
                    color = NPTacct.youTank1color   -- orange > red   taunt now
                    other = NPTacct.youTank0color
                elseif status >= 0 then             -- others tanking by threat
                    color = NPTacct.youTank0color   -- red > orange   attack now
                    other = NPTacct.youTank1color
                end
            else -- playing as nontank without reusing flipped tank colors
                if status >= 5 then                 -- tanks tanking via threat
                    color = NPTacct.nonTank5color   -- green > gray   no problem
                    other = NPTacct.nonTank4color
                elseif status >= 4 then             -- tanks tanking via force
                    color = NPTacct.nonTank4color   -- gray > green   no problem
                    other = NPTacct.nonTank5color
                elseif status >= 3 then             -- others tanking by threat
                    color = NPTacct.nonTank3color   -- gray > yellow  disengage
                    other = NPTacct.nonTank2color
                elseif status >= 2 then             -- others tanking by force
                    color = NPTacct.nonTank2color   -- yellow > gray  attack soon
                    other = NPTacct.nonTank3color
                elseif status >= 1 then             -- player tanking by force
                    color = NPTacct.nonTank1color   -- orange > red   taunt now
                    other = NPTacct.nonTank0color
                elseif status >= 0 then             -- player tanking by threat
                    color = NPTacct.nonTank0color   -- red > orange   attack now
                    other = NPTacct.nonTank1color
                end
            end
            if not frame.threat then
                frame.threat = {
                    ["color"] = {},
                    ["previousColor"] = {},
                };
            end
            frame.threat.lastStatus = status
            frame.threat.lastRatio = unit

            if NPTacct.gradientColor and unit > 0 then
                frame.threat.color.r = color.r + (other.r - color.r) * unit
                frame.threat.color.g = color.g + (other.g - color.g) * unit
                frame.threat.color.b = color.b + (other.b - color.b) * unit
            else -- skip fading color by a linear gradient toward the other
                frame.threat.color.r = color.r
                frame.threat.color.g = color.g
                frame.threat.color.b = color.b
            end
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
myFrame:RegisterEvent("PET_DISMISS_START");
myFrame:RegisterEvent("UNIT_PET");
myFrame:RegisterEvent("ADDON_LOADED");
myFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "NameplatesThreat" then
        if not NPTacct or not NPTacct.storedVersion or NPTacct.storedVersion
            ~= tonumber(GetAddOnMetadata("NameplatesThreat", "Version")) then
            defaultVariables() -- reset variables if their stored version does not match
        end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
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
           event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" or
           event == "PET_DISMISS_START" or event == "UNIT_PET" then
        offTanks, playerRole, nonTanks = getGroupRoles()
    end
end);
myFrame:SetScript("OnUpdate", function(self, elapsed)
    if NPTacct.gradientColor then -- one nameplate updated every x seconds (increased CPU usage)
        thisUpdate = thisUpdate + elapsed
        if thisUpdate >= NPTacct.gradientDelay then
            for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                updateThreatColor(nameplate.UnitFrame)
            end
            thisUpdate = thisUpdate - NPTacct.gradientDelay
        end
    end -- remember "/console reloadui" for any script changes to take effect
end);