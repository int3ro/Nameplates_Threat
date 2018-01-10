local function initVariables(oldAcct) -- only the variables below are used by the addon
    newAcct = {}
    newAcct["addonIsActive"] = true -- color by threat those nameplates you can attack
    newAcct["ignorePlayers"] = true -- ignoring nameplates for player characters
    newAcct["ignoreNeutral"] = true -- ignoring nameplates for neutral monsters
    newAcct["ignoreNoGroup"] = true -- ignoring nameplates not fighting your group
    newAcct["gradientColor"] = true -- update nameplate color gradients (some CPU usage)
    newAcct["gradientDelay"] = 0.2  -- update nameplate color gradients every x seconds
    newAcct["nonGroupColor"] = {r=0.15, g=0.15, b=0.15} -- dark   target not in group fight
    newAcct["youTank7color"] = {r=1.00, g=0.00, b=0.00} -- red    healers tanking by threat
    newAcct["youTank6color"] = {r=1.00, g=0.60, b=0.00} -- orange healers tanking by force
    newAcct["youTank5color"] = {r=0.00, g=0.85, b=0.00} -- green  group tanks tank by threat
    newAcct["youTank4color"] = {r=0.69, g=0.69, b=0.69} -- gray   group tanks tank by force
    newAcct["youTank3color"] = {r=0.69, g=0.69, b=0.69} -- gray   you are tanking by threat
    newAcct["youTank2color"] = {r=1.00, g=1.00, b=0.47} -- yellow you are tanking by force
    newAcct["youTank1color"] = {r=1.00, g=1.00, b=0.47} -- yellow others tanking by force
    newAcct["youTank0color"] = {r=1.00, g=0.60, b=0.00} -- orange others tanking by threat
    newAcct["nonTankReused"] = true -- reuse flipped colors above when playing as nontank
    newAcct["nonTank7color"] = {r=1.00, g=0.00, b=0.00} -- red    healers tanking by threat
    newAcct["nonTank6color"] = {r=1.00, g=0.60, b=0.00} -- orange healers tanking by force
    newAcct["nonTank5color"] = {r=0.00, g=0.85, b=0.00} -- green  group tanks tank by threat
    newAcct["nonTank4color"] = {r=0.69, g=0.69, b=0.69} -- gray   group tanks tank by force
    newAcct["nonTank3color"] = {r=0.69, g=0.69, b=0.69} -- gray   others tanking by threat
    newAcct["nonTank2color"] = {r=1.00, g=1.00, b=0.47} -- yellow others tanking by force
    newAcct["nonTank1color"] = {r=1.00, g=1.00, b=0.47} -- yellow you are tanking by force
    newAcct["nonTank0color"] = {r=1.00, g=0.60, b=0.00} -- orange you are tanking by threat
    newAcct["forcingReused"] = true -- reuse tanking by threat colors when tanking by force
    newAcct["addonsVersion"] = tonumber(GetAddOnMetadata("NameplatesThreat", "Version"))

    if oldAcct then -- override defaults with imported values if old keys match new keys
        for key in pairs(newAcct) do
            if oldAcct[key] and key ~= "addonsVersion" then
                newAcct[key] = oldAcct[key]
            end
        end -- any old variables we do not recognize by their key name are discarded now
    end
    return newAcct
end

local thisUpdate = 0
local playerRole = 0
local offTanks = {}
local nonTanks = {}
local offHeals = {}

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
    local collectedHeals = {}
    local collectedPlayer, unitPrefix, unit, i, unitRole
    local isInRaid = IsInRaid()

    collectedPlayer = GetSpecializationRole(GetSpecialization())
    if UnitExists("pet") then
        if collectedPlayer == "TANK" then
            table.insert(collectedTanks, "pet")
        elseif unitRole == "HEALER" then
            table.insert(collectedHeals, "pet")
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
            elseif unitRole == "HEALER" then
                table.insert(collectedHeals, unit)
            else
                table.insert(collectedOther, unit)
            end
            unit = unitPrefix .. "pet" .. i
            if UnitExists(unit) then
                if unitRole == "TANK" then
                    table.insert(collectedTanks, unit)
                elseif unitRole == "HEALER" then
                    table.insert(collectedHeals, unit)
                else
                    table.insert(collectedOther, unit)
                end
            end
        end
    end
    return collectedTanks, collectedPlayer, collectedOther, collectedHeals
end

local function threatSituation(monster)
    local threatStatus = -1
    local tankValue    =  0
    local offTankValue =  0
    local playerValue  =  0
    local nonTankValue =  0
    local offHealValue =  0
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
    -- store if an offheal is tanking, or store their threat value if higher than others
    for _, unit in ipairs(offHeals) do
        isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
        if isTanking then
            threatStatus = status + 4
            tankValue = threatValue
        elseif status and threatValue > offHealValue then
            offHealValue = threatValue
        elseif threatStatus < 0 and UnitIsUnit(unit, monster .. "target") then
            threatStatus = 7 -- ensure threat status if monster is targeting a healer
        end
    end
    if threatStatus > -1 and tankValue <= 0 then
        offTankValue = 0
        playerValue  = 0 -- clear threat values if tank was found through monster target
        nonTankValue = 0
        offHealValue = 0
    end
    -- deliver the stored information describing threat situation for this monster
    return threatStatus, tankValue, offTankValue, playerValue, nonTankValue, offHealValue
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
           +6 = group healer is tanking by force.
           +7 = group healer is tanking by threat.
        ]]-- situation 0 to 3 flipped later as nontank.
        local status, tank, offtank, player, nontank, offheal = threatSituation(unit)

        -- compare highest group threat with tank for color gradient if enabled
        if NPTacct.gradientColor and status > -1 then
            if playerRole == "TANK" then
                if status == 0 or status == 1 then
                    unit = math.max(offtank, player)
                else -- you or an offtank are tanking the monster
                    unit = math.max(nontank, offheal)
                end
            else
                if status == 2 or status == 3 then
                    unit = math.max(offtank, nontank, offheal)
                else -- someone is tanking the monster for you
                    unit = player
                end
            end
            if status == 1 or status == 2 or status == 4 or status == 6 then
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
        end -- flip colors when not a tank role and no group tanks or healers are tanking

        -- only recalculate color when situation was actually changed with gradient toward sibling color
        if not frame.threat or frame.threat.lastStatus ~= status or frame.threat.lastRatio ~= unit then
            local color = NPTacct.nonGroupColor -- dark outside group (status < 4 inverted for nontanks)
            local fader = NPTacct.nonGroupColor -- we fade color toward the fader if gradient is enabled

            if status > -1 then -- determine colors depending on threat situation odd/even
                color = status
                if status % 2 == 0 then
                    fader = status + 1
                else
                    fader = status - 1
                end
                if NPTacct.forcingReused then -- reuse threat tanking colors or forced fader/color 1
                    if status >= 7 then
                        fader = 0
                    elseif status >= 6 then
                        color = 0
                    elseif status >= 5 then
                        fader = 3
                    elseif status >= 4 then
                        color = 3
                    elseif status >= 3 then
                        fader = 1
                    elseif status >= 2 then
                        color = 1
                    end
                end
                if playerRole == "TANK" or NPTacct.nonTankReused then
                    color = NPTacct["youTank" .. color .. "color"]
                    fader = NPTacct["youTank" .. fader .. "color"]
                else
                    color = NPTacct["nonTank" .. color .. "color"]
                    fader = NPTacct["nonTank" .. fader .. "color"]
                end
            elseif NPTacct.ignoreNoGroup then
                resetFrame(frame) -- reset frame if monster not fighting group member/pet
                return
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
                frame.threat.color.r = color.r + (fader.r - color.r) * unit
                frame.threat.color.g = color.g + (fader.g - color.g) * unit
                frame.threat.color.b = color.b + (fader.b - color.b) * unit
            else -- skip fading color by a linear gradient toward the fader
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
        NPTacct = initVariables(NPTacct) -- migrate variables or reset to default
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
        offTanks, playerRole, nonTanks, offHeals = getGroupRoles()
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