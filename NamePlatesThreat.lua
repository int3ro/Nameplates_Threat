local function initVariables(oldAcct) -- only the variables below are used by the addon
    local newAcct, key, value = {}
    newAcct["addonsEnabled"] = true  -- color by threat those nameplates you can attack
    newAcct["enablePlayers"] = false -- also color nameplates for player characters
    newAcct["enableNeutral"] = false -- also color nameplates for neutral targets
    newAcct["enableNoGroup"] = false -- also color nameplates not fighting your group
    newAcct["gradientColor"] = true  -- update nameplate color gradients (some CPU usage)
    newAcct["gradientPrSec"] = 5     -- update color gradients this many times per second
    newAcct["nonGroupColor"] = {r=0.15, g=0.15, b=0.15} -- dark   target not in group fight
    newAcct["youTank7color"] = {r=1.00, g=0.00, b=0.00} -- red    healers tanking by threat
    newAcct["youTank6color"] = {r=1.00, g=0.60, b=0.00} -- orange healers tanking by force
    newAcct["youTank5color"] = {r=0.00, g=0.85, b=0.00} -- green  group tanks tank by threat
    newAcct["youTank4color"] = {r=0.69, g=0.69, b=0.69} -- gray   group tanks tank by force
    newAcct["youTank3color"] = {r=0.69, g=0.69, b=0.69} -- gray   you are tanking by threat
    newAcct["youTank2color"] = {r=1.00, g=1.00, b=0.47} -- yellow you are tanking by force
    newAcct["youTank1color"] = {r=1.00, g=1.00, b=0.47} -- yellow others tanking by force
    newAcct["youTank0color"] = {r=1.00, g=0.60, b=0.00} -- orange others tanking by threat
    newAcct["nonTankUnique"] = false -- unique nontank colors instead of flip colors above
    newAcct["nonTank7color"] = {r=1.00, g=0.00, b=0.00} -- red    healers tanking by threat
    newAcct["nonTank6color"] = {r=1.00, g=0.60, b=0.00} -- orange healers tanking by force
    newAcct["nonTank5color"] = {r=0.00, g=0.85, b=0.00} -- green  group tanks tank by threat
    newAcct["nonTank4color"] = {r=0.69, g=0.69, b=0.69} -- gray   group tanks tank by force
    newAcct["nonTank3color"] = {r=0.69, g=0.69, b=0.69} -- gray   others tanking by threat
    newAcct["nonTank2color"] = {r=1.00, g=1.00, b=0.47} -- yellow others tanking by force
    newAcct["nonTank1color"] = {r=1.00, g=1.00, b=0.47} -- yellow you are tanking by force
    newAcct["nonTank0color"] = {r=1.00, g=0.60, b=0.00} -- orange you are tanking by threat
    newAcct["forcingUnique"] = false -- unique force colors instead of reuse threat colors
    newAcct["addonsVersion"] = tonumber(GetAddOnMetadata("NamePlatesThreat", "Version"))

    if oldAcct then -- override defaults with imported values if old keys match new keys
        --print("oldAcct:Begin")
        for key, value in pairs(newAcct) do
            if oldAcct[key] ~= nil and key ~= "addonsVersion" then
                if type(newAcct[key]) == "table" then
                    newAcct[key].r, newAcct[key].g, newAcct[key].b = oldAcct[key].r, oldAcct[key].g, oldAcct[key].b
                else
                    newAcct[key] = oldAcct[key]
                end
                --print("newAcct:" .. key .. ":" .. tostring(newAcct[key]))
            end
        end -- any old variables we do not recognize by their key name are discarded now
        --print("oldAcct:Finish")
    end
    return newAcct
end

local NPT = CreateFrame("Frame", nil, UIParent) -- invisible frame handling addon logic
NPT.thisUpdate = 0
NPT.playerRole = 0
NPT.offTanks = {}
NPT.nonTanks = {}
NPT.offHeals = {}
local NPTframe = CreateFrame("Frame", nil, NPT) -- options panel for tweaking the addon
NPTframe.lastSwatch = nil

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
        elseif collectedPlayer == "HEALER" then
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
    for _, unit in ipairs(NPT.offTanks) do
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
    for _, unit in ipairs(NPT.nonTanks) do
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
    for _, unit in ipairs(NPT.offHeals) do
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

    if NPTacct.addonsEnabled -- only color nameplates you can attack if addon is active
        and UnitCanAttack("player", unit) and not CompactUnitFrame_IsTapDenied(frame)
        and (NPTacct.enablePlayers or not UnitIsPlayer(unit))
        and (NPTacct.enableNeutral or not (UnitReaction(unit, "player") > 3)
            or UnitIsFriend(unit .. "target", "player")) then

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
            if NPT.playerRole == "TANK" then
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
        if status > -1 and NPT.playerRole ~= "TANK" and status < 4 then
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
                if not NPTacct.forcingUnique then -- reuse threat tanking colors or forced fader/color 1
                    if status == 1 then
                        color = 2
                    elseif status >= 7 then
                        fader = 0
                    elseif status >= 6 then
                        color = 0
                    elseif status >= 5 then
                        fader = 3
                    elseif status >= 4 then
                        color = 3
                    elseif status >= 3 then
                        fader = 2
                    end
                end
                if NPT.playerRole == "TANK" or not NPTacct.nonTankUnique then
                    color = NPTacct["youTank" .. color .. "color"]
                    fader = NPTacct["youTank" .. fader .. "color"]
                else
                    color = NPTacct["nonTank" .. color .. "color"]
                    fader = NPTacct["nonTank" .. fader .. "color"]
                end
            elseif not NPTacct.enableNoGroup then
                resetFrame(frame) -- reset frame if monster not fighting group
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

-- The color is only going to be reset after it was actually changed.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", updateHealthColor)

NPT:RegisterEvent("PLAYER_REGEN_ENABLED");
NPT:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE");
NPT:RegisterEvent("NAME_PLATE_UNIT_ADDED");
NPT:RegisterEvent("NAME_PLATE_UNIT_REMOVED");
NPT:RegisterEvent("PLAYER_ROLES_ASSIGNED");
NPT:RegisterEvent("RAID_ROSTER_UPDATE");
NPT:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
NPT:RegisterEvent("PLAYER_ENTERING_WORLD");
NPT:RegisterEvent("PET_DISMISS_START");
NPT:RegisterEvent("UNIT_PET");
NPT:RegisterEvent("ADDON_LOADED");
NPT:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "NamePlatesThreat" then
        NPTacct = initVariables(NPTacct) -- import variables or reset to defaults
        NPTframe:Initialize()
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "PLAYER_REGEN_ENABLED" then
        local callback, nameplate = function()
            for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
                updateThreatColor(nameplate.UnitFrame)
            end
            NPT.thisUpdate = 0
        end
        if event == "UNIT_THREAT_SITUATION_UPDATE" then
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
        NPT.offTanks, NPT.playerRole, NPT.nonTanks, NPT.offHeals = getGroupRoles()
        local nameplate
        for _, nameplate in pairs(C_NamePlate.GetNamePlates()) do
            resetFrame(nameplate.UnitFrame)
        end
        if event == "PLAYER_ENTERING_WORLD" then
            --InterfaceOptionsFrame_OpenToCategory(NPTframe) -- for debugging only
            --InterfaceOptionsFrame_OpenToCategory(NPTframe) -- must call it twice
        else
            self:GetScript("OnEvent")(self, "UNIT_THREAT_SITUATION_UPDATE")
        end
    end
end);
NPT:SetScript("OnUpdate", function(self, elapsed)
    if NPTacct.addonsEnabled and NPTacct.gradientColor then
        NPT.thisUpdate = NPT.thisUpdate + elapsed
        if NPT.thisUpdate >= 1/NPTacct.gradientPrSec then
            NPT:GetScript("OnEvent")(NPT, "UNIT_THREAT_SITUATION_UPDATE")
        end
    end -- remember "/console reloadui" for any script changes to take effect
end);
function NPTframe.okay()
    NPTacct = initVariables(NPT.acct) -- store panel fields into addon variables
    NPT:GetScript("OnEvent")(NPT, "PLAYER_SPECIALIZATION_CHANGED")
    --print(GetServerTime() .. " NPTframe.okay(): NPTacct.enableNeutral=" .. tostring(NPTacct.enableNeutral))
end
function NPTframe.cancel()
    NPT.acct = initVariables(NPTacct) -- restore panel fields from addon variables
    --print(GetServerTime() .. " NPTframe.cancel(): NPT.acct.enableNeutral=" .. tostring(NPT.acct.enableNeutral))
end
function NPTframe.default()
    NPT.acct = initVariables()
end
function NPTframe.refresh() -- called on panel shown or after default was accepted
    --print(GetServerTime() .. " NPTframe.refresh(): Begin")
    NPTframe.addonsEnabled:GetScript("PostClick")(NPTframe.addonsEnabled, nil, nil, NPT.acct.addonsEnabled, true)
    NPTframe.enablePlayers:GetScript("PostClick")(NPTframe.enablePlayers, nil, nil, NPT.acct.enablePlayers)
    NPTframe.enableNeutral:GetScript("PostClick")(NPTframe.enableNeutral, nil, nil, NPT.acct.enableNeutral)

    NPTframe.enableNoGroup:GetScript("PostClick")(NPTframe.enableNoGroup, nil, nil, NPT.acct.enableNoGroup)
    NPTframe.nonGroupColor:GetScript("PostClick")(NPTframe.nonGroupColor, nil, nil, NPT.acct.nonGroupColor)

    NPTframe.gradientColor:GetScript("PostClick")(NPTframe.gradientColor, nil, nil, NPT.acct.gradientColor)
    NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, NPT.acct.gradientPrSec)

    NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, NPT.acct.forcingUnique)
    --todo forcing unique color swatches

    NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, NPT.acct.nonTankUnique)
    --todo nontank unique color swatches

    NPTframe.nonTankForced:GetScript("PostClick")(NPTframe.nonTankForced, nil, nil, NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
    --todo nontank forced color swatches

    --print(GetServerTime() .. " NPTframe.refresh(): Finish")
end
function NPTframe.ColorSwatchPostClick(self, button, down, value, enable)
    if enable ~= nil and not enable then
        if NPTframe.lastSwatch and NPTframe.lastSwatch == self then
            ColorPickerFrame:Hide()
            NPTframe.lastSwatch:SetChecked(false)
            ColorPickerFrame.cancelFunc(ColorPickerFrame.previousValues)
            NPTframe.lastSwatch = nil
        end
        self:Disable()
        self:SetBackdropColor(0.3, 0.3, 0.3)
    elseif enable then
        self:Enable()
        self:SetBackdropColor(1.0, 1.0, 1.0)
    end
    if value ~= nil then
        self.color:SetVertexColor(value.r, value.g, value.b)
    end
    local r, g, b, changed = self.color:GetVertexColor()
    changed = {}
    changed.r, changed.g, changed.b = r, g, b
    if value ~= nil or self:IsEnabled() and enable == nil then
        if NPT.acct[self:GetName()] ~= nil then
            NPT.acct[self:GetName()].r = changed.r
            NPT.acct[self:GetName()].g = changed.g
            NPT.acct[self:GetName()].b = changed.b
        end
        if value == nil then
            ColorPickerFrame:Hide()
            if NPTframe.lastSwatch then
                NPTframe.lastSwatch:SetChecked(false)
                ColorPickerFrame.cancelFunc(ColorPickerFrame.previousValues)
            end
            if self:GetChecked() then
                NPTframe.lastSwatch = self
                ColorPickerFrame:Show()
                ColorPickerFrame.opacityFunc = nil
                ColorPickerFrame.opacity = nil
                ColorPickerFrame.hasOpacity = false
                ColorPickerFrame.func = NPTframe.OnColorSelect
                ColorPickerFrame.cancelFunc = NPTframe.OnColorSelect
                ColorPickerFrame.previousValues = changed
                ColorPickerFrame:SetColorRGB(changed.r, changed.g, changed.b)
            else
                NPTframe.lastSwatch = nil
            end
        elseif NPTframe.lastSwatch == self and not ColorPickerFrame:IsVisible() then
            NPTframe.lastSwatch:SetChecked(false)
            NPTframe.lastSwatch = nil
        end
    end
    --print(GetServerTime() .. " NPTframe." .. self:GetName() .. "(frame): " .. tostring(NPT.acct[self:GetName()].r) .. " " .. tostring(NPT.acct[self:GetName()].g) .. " " .. tostring(NPT.acct[self:GetName()].b))
    if NPT.acct[self:GetName()] ~= nil then
        changed = (NPT.acct[self:GetName()].r ~= NPTacct[self:GetName()].r)
                or (NPT.acct[self:GetName()].g ~= NPTacct[self:GetName()].g)
                or (NPT.acct[self:GetName()].b ~= NPTacct[self:GetName()].b)
    else
        changed = false
    end
    --print(GetServerTime() .. " NPTframe." .. self:GetName() .. "(saved): " .. tostring(NPTacct[self:GetName()].r) .. " " .. tostring(NPTacct[self:GetName()].g) .. " " .. tostring(NPTacct[self:GetName()].b))
    if changed then
        self.text:SetFontObject("GameFontNormalSmall")
    elseif self:IsEnabled() then
        self.text:SetFontObject("GameFontHighlightSmall")
    else
        self.text:SetFontObject("GameFontDisableSmall")
    end
end
function NPTframe.OnColorSelect(self, r, g, b)
    if self and r and g and b then
        return -- unsupported for now
    elseif self then
        r, g, b = self.r, self.g, self.b
    else
        r, g, b = ColorPickerFrame:GetColorRGB()
    end
    self = {}
    self.r, self.g, self.b = r, g, b
    --print(GetServerTime() .. " NPTframe.OnColorSelect(): " .. tostring(r) .. " " .. tostring(g) .. " " .. tostring(b))
    NPTframe.lastSwatch:GetScript("PostClick")(NPTframe.lastSwatch, nil, nil, self)
end
function NPTframe.CheckButtonPostClick(self, button, down, value, enable)
    if enable ~= nil and not enable then
        self:Disable()
    elseif enable then
        self:Enable()
    end
    if value ~= nil then
        self:SetChecked(value)
    end
    if value ~= nil or self:IsEnabled() and enable == nil then
        if NPT.acct[self:GetName()] ~= nil then
            NPT.acct[self:GetName()] = self:GetChecked()
        end
    end
    local small = strfind(self.text:GetFontObject():GetName(), "Small")
    --print(self.text:GetFontObject():GetName() .. ":" .. tostring(small) .. ":Small")
    if small then
        small = "Small"
    else
        small = ""
    end
    if NPT.acct[self:GetName()] ~= nil and NPT.acct[self:GetName()] ~= NPTacct[self:GetName()] then
        self.text:SetFontObject("GameFontNormal" .. small)
    elseif self:IsEnabled() then
        self.text:SetFontObject("GameFontHighlight" .. small)
    else
        self.text:SetFontObject("GameFontDisable" .. small)
    end
    --print(GetServerTime() .. " NPTframe." .. self:GetName() .. "(): NPT.acct." .. self:GetName() .. "=" .. tostring(NPT.acct[self:GetName()]))
end
function NPTframe.SliderOnValueChanged(self, button, down, value, enable)
    if enable ~= nil and not enable then
        self:Disable()
        self.low:SetFontObject("GameFontDisableSmall")
        self.high:SetFontObject("GameFontDisableSmall")
    elseif enable then
        self:Enable()
        self.low:SetFontObject("GameFontHighlightSmall")
        self.high:SetFontObject("GameFontHighlightSmall")
    end
    if value ~= nil then
        self:SetValue(math.min(math.max(tonumber(self.low:GetText()), value), tonumber(self.high:GetText())))
    end
    if value ~= nil or self:IsEnabled() and enable == nil then
        if NPT.acct[self:GetName()] ~= nil then
            NPT.acct[self:GetName()] = self:GetValue()
        end
        self.text:SetText(self:GetValue())
    end
    if NPT.acct[self:GetName()] ~= nil and NPT.acct[self:GetName()] ~= NPTacct[self:GetName()] then
        self.text:SetFontObject("GameFontNormalSmall")
    elseif self:IsEnabled() then
        self.text:SetFontObject("GameFontHighlightSmall")
    else
        self.text:SetFontObject("GameFontDisableSmall")
    end
    --print(GetServerTime() .. " NPTframe." .. self:GetName() .. "(): NPT.acct." .. self:GetName() .. "=" .. tostring(NPT.acct[self:GetName()]))
end
function NPTframe:Initialize()
    self:cancel() -- simulate options cancel so panel variables are reset
    self.name = GetAddOnMetadata("NamePlatesThreat", "Title")

    self.bigTitle = self:CreateFontString("bigTitle", "ARTWORK", "GameFontNormalLarge")
    self.bigTitle:SetPoint("LEFT", self, "TOPLEFT", 16, -24)
    self.bigTitle:SetPoint("RIGHT", self, "TOPRIGHT", -32, -24)
    self.bigTitle:SetJustifyH("LEFT")
    self.bigTitle:SetText(self.name .. " " .. NPTacct.addonsVersion .. " by " .. GetAddOnMetadata("NamePlatesThreat", "Author"))
    self.bigTitle:SetHeight(self.bigTitle:GetStringHeight() * 1)

    self.subTitle = self:CreateFontString("subTitle", "ARTWORK", "GameFontHighlightSmall")
    self.subTitle:SetPoint("LEFT", self, "TOPLEFT", 16, -50)
    self.subTitle:SetPoint("RIGHT", self, "TOPRIGHT", -32, -50)
    self.subTitle:SetJustifyH("LEFT")
    self.subTitle:SetText(GetAddOnMetadata("NamePlatesThreat", "Notes") .. " Press Okay to keep unsaved AddOn changes (in yellow below), press Escape or Cancel to discard unsaved changes, or click Defaults > These Settings to reset everything below.")
    self.subTitle:SetHeight(self.subTitle:GetStringHeight() * 2)

    self.addonsEnabled = self:CheckButtonCreate("addonsEnabled", "Color Non-Friendly Nameplates", 1)
    self.addonsEnabled:SetScript("PostClick", function(self, button, down, value, enable)
        NPTframe.CheckButtonPostClick(self, button, down, value, enable)
        NPTframe.enablePlayers:GetScript("PostClick")(NPTframe.enablePlayers, nil, nil, nil, NPT.acct.addonsEnabled)
        NPTframe.enableNeutral:GetScript("PostClick")(NPTframe.enableNeutral, nil, nil, nil, NPT.acct.addonsEnabled)

        NPTframe.enableNoGroup:GetScript("PostClick")(NPTframe.enableNoGroup, nil, nil, nil, NPT.acct.addonsEnabled)
        --NPTframe.nonGroupColor:GetScript("PostClick")(NPTframe.nonGroupColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enableNoGroup)

        NPTframe.gradientColor:GetScript("PostClick")(NPTframe.gradientColor, nil, nil, nil, NPT.acct.addonsEnabled)
        --NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.gradientColor)

        NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, nil, NPT.acct.addonsEnabled)
        --todo forcing unique color swatches

        NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, nil, NPT.acct.addonsEnabled)
        --todo nontank unique color swatches

        NPTframe.nonTankForced:GetScript("PostClick")(NPTframe.nonTankForced, nil, nil, nil, NPT.acct.addonsEnabled)
        --todo nontank forced color swatches
    end)

    self.enablePlayers = self:CheckButtonCreate("enablePlayers", "Color Player Characters", 1, 1)
    self.enablePlayers:SetScript("PostClick", NPTframe.CheckButtonPostClick)

    self.enableNeutral = self:CheckButtonCreate("enableNeutral", "Color Neutral Targets", 1, 2)
    self.enableNeutral:SetScript("PostClick", NPTframe.CheckButtonPostClick)

    self.enableNoGroup = self:CheckButtonCreate("enableNoGroup", "Color Out of Combat", 1, 3)
    self.enableNoGroup:SetScript("PostClick", function(self, button, down, value, enable)
        NPTframe.CheckButtonPostClick(self, button, down, value, enable)
        NPTframe.nonGroupColor:GetScript("PostClick")(NPTframe.nonGroupColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enableNoGroup)
    end)
    self.nonGroupColor = self:ColorSwatchCreate("nonGroupColor", "Target is Out of Combat", 4, 0)
    self.nonGroupColor:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

    self.gradientColor, self.gradientPrSec = self:CheckSliderCreate("gradientColor", "Color Gradient Updates Per Second", "gradientPrSec", 1, 9, 2, true)
    self.gradientColor:SetScript("PostClick", function(self, button, down, value, enable)
        NPTframe.CheckButtonPostClick(self, button, down, value, enable)
        NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.gradientColor)
    end)
    self.gradientPrSec:SetScript("OnValueChanged", NPTframe.SliderOnValueChanged)

    self.youTank7color = self:ColorSwatchCreate("youTank7color", "Healers have High Threat", 4, 1)
    self.youTank0color = self:ColorSwatchCreate("youTank0color", "Damage has High Threat", 4, 2)
    self.youTank2color = self:ColorSwatchCreate("youTank2color", "You have the Low Threat", 4, 3)
    self.youTank3color = self:ColorSwatchCreate("youTank3color", "You have the High Threat", 4, 4)
    self.youTank5color = self:ColorSwatchCreate("youTank5color", "Tanks have High Threat", 4, 5)

    self.forcingUnique = self:CheckButtonCreate("forcingUnique", "Unique Colors Forced Tanking", 8)
    self.forcingUnique:SetScript("PostClick", function(self, button, down, value, enable)
        NPTframe.CheckButtonPostClick(self, button, down, value, enable)
        if (NPT.acct.forcingUnique and NPT.acct.nonTankUnique) ~= (NPTacct.forcingUnique and NPTacct.nonTankUnique) then
            NPTframe.nonTankForced.text:SetFontObject("GameFontNormal")
        else
            NPTframe.nonTankForced.text:SetFontObject("GameFontHighlight")
        end
        NPTframe.nonTankForced:SetChecked(NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
        --todo forcing unique color swatches
    end)
    self.youTank6color = self:ColorSwatchCreate("youTank6color", "Healers have Low Threat", 8, 1)
    self.youTank1color = self:ColorSwatchCreate("youTank1color", "Damage has Low Threat", 8, 2)
    self.youTank4color = self:ColorSwatchCreate("youTank4color", "Tanks have Low Threat", 8, 3)

    self.nonTankUnique = self:CheckButtonCreate("nonTankUnique", "Unique Colors as Non-Tank Role", 4, nil, true)
    self.nonTankUnique:SetScript("PostClick", function(self, button, down, value, enable)
        NPTframe.CheckButtonPostClick(self, button, down, value, enable)
        if (NPT.acct.forcingUnique and NPT.acct.nonTankUnique) ~= (NPTacct.forcingUnique and NPTacct.nonTankUnique) then
            NPTframe.nonTankForced.text:SetFontObject("GameFontNormal")
        else
            NPTframe.nonTankForced.text:SetFontObject("GameFontHighlight")
        end
        NPTframe.nonTankForced:SetChecked(NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
        --todo nontank unique color swatches
    end)
    self.nonTank7color = self:ColorSwatchCreate("nonTank7color", "Healers have High Threat", 4, 1, true)
    self.nonTank3color = self:ColorSwatchCreate("nonTank3color", "You have the High Threat", 4, 2, true)
    self.nonTank2color = self:ColorSwatchCreate("nonTank2color", "Damage has Low Threat", 4, 3, true)
    self.nonTank0color = self:ColorSwatchCreate("nonTank0color", "Damage has High Threat", 4, 4, true)
    self.nonTank5color = self:ColorSwatchCreate("nonTank5color", "Tanks have High Threat", 4, 5, true)

    self.nonTankForced = self:CheckButtonCreate("nonTankForced", "Unique Colors Forced Non-Tank", 8, nil, true)
    self.nonTankForced:SetScript("PostClick", function(self, button, down, value, enable)
        NPTframe.CheckButtonPostClick(self, button, down, value, enable)
        value = self:GetChecked()
        NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, value)
        NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, value)
        --todo nontank forced color swatches
    end)
    self.nonTank6color = self:ColorSwatchCreate("nonTank6color", "Healers have Low Threat", 8, 1, true)
    self.nonTank1color = self:ColorSwatchCreate("nonTank1color", "You have the Low Threat", 8, 2, true)
    self.nonTank4color = self:ColorSwatchCreate("nonTank4color", "Tanks have Low Threat", 8, 3, true)

    InterfaceOptions_AddCategory(self)
    --print(GetServerTime() .. " NPTframe:Initialize(): NPTacct.enableNeutral=" .. tostring(NPTacct.enableNeutral))
end
function NPTframe:ColorSwatchCreate(newName, newText, mainRow, subRow, columnTwo)
    local newObject = CreateFrame("CheckButton", newName, self, "InterfaceOptionsCheckButtonTemplate")
    newObject.text = _G[newName .. "Text"]
    local rowX, rowY, colX = 10, 22.65, 0
    if subRow then
        newObject.text:SetFontObject("GameFontDisableSmall")
        rowY = rowY*subRow
    else
        newObject.text:SetFontObject("GameFontDisable")
        rowX = 0
        rowY = 0
    end
    rowY = 34*mainRow + rowY
    if columnTwo then
        colX = 286
    end
    newObject.color = newObject:CreateTexture()
    newObject.color:SetWidth(15)
    newObject.color:SetHeight(15)
    newObject.color:SetPoint("CENTER")
    newObject.color:SetTexture("Interface/ChatFrame/ChatFrameColorSwatch")
    newObject:SetBackdrop({bgFile="Interface/ChatFrame/ChatFrameColorSwatch",insets={left=3,right=3,top=3,bottom=3}})
    newObject:SetPushedTexture(newObject.color)
    newObject:SetNormalTexture(newObject.color)
    newObject.text:SetJustifyH("LEFT")
    newObject.text:SetText(newText)
    newObject:SetPoint("LEFT", self, "TOPLEFT", 14+rowX+colX, -59.3-rowY)
    newObject.text:SetPoint("LEFT", self, "TOPLEFT", 42+rowX+colX, -58.3-rowY)
    newObject.text:SetPoint("RIGHT", self, "TOPRIGHT", -318+colX, -58.3-rowY)
    newObject:SetBackdropColor(0.3, 0.3, 0.3)
    newObject:Disable()
    return newObject
end
function NPTframe:CheckButtonCreate(newName, newText, mainRow, subRow, columnTwo)
    local newObject = CreateFrame("CheckButton", newName, self, "InterfaceOptionsCheckButtonTemplate")
    newObject.text = _G[newName .. "Text"]
    local rowX, rowY, colX = 10, 22.65, 0
    if subRow then
        newObject.text:SetFontObject("GameFontDisableSmall")
        rowY = rowY*subRow
    else
        newObject.text:SetFontObject("GameFontDisable")
        rowX = 0
        rowY = 0
    end
    rowY = 34*mainRow + rowY
    if columnTwo then
        colX = 286
    end
    newObject.text:SetJustifyH("LEFT")
    newObject.text:SetText(newText)
    newObject:SetPoint("LEFT", self, "TOPLEFT", 14+rowX+colX, -59.3-rowY)
    newObject.text:SetPoint("LEFT", self, "TOPLEFT", 42+rowX+colX, -58.3-rowY)
    newObject.text:SetPoint("RIGHT", self, "TOPRIGHT", -318+colX, -58.3-rowY)
    newObject:Disable()
    return newObject
end
function NPTframe:CheckSliderCreate(newCheck, newText, newSlider, minVal, maxVal, mainRow, columnTwo)
    local newCheck = CreateFrame("CheckButton", newCheck, self, "InterfaceOptionsCheckButtonTemplate")
    local newSlider = CreateFrame("Slider", newSlider, self, "OptionsSliderTemplate")
    local rowY, colX = 34*mainRow, 0
    if columnTwo then
        colX = 286
    end
    newSlider:SetPoint("LEFT", self, "TOPLEFT", 42+colX, -59.3-rowY)
    newSlider:SetPoint("RIGHT", self, "TOPRIGHT", -318+colX, -59.3-rowY)
    newSlider:SetMinMaxValues(minVal, maxVal)
    newSlider:SetValueStep(1)
    newSlider:SetObeyStepOnDrag(true)
    newSlider.low = _G[newSlider:GetName() .. "Low"]
    newSlider.low:SetFontObject("GameFontDisableSmall")
    newSlider.low:SetText(minVal)
    newSlider.high = _G[newSlider:GetName() .. "High"]
    newSlider.high:SetFontObject("GameFontDisableSmall")
    newSlider.high:SetText(maxVal)
    newSlider.text = _G[newSlider:GetName() .. "Text"]
    newSlider.text:ClearAllPoints()
    newSlider.text:SetPoint("LEFT", self, "TOPLEFT", 42+colX, -69.3-rowY)
    newSlider.text:SetPoint("RIGHT", self, "TOPRIGHT", -318+colX, -69.3-rowY)
    newSlider.text:SetFontObject("GameFontDisableSmall")
    newSlider.text:SetText("?")
    newCheck:SetPoint("LEFT", self, "TOPLEFT", 14+colX, -59.3-rowY)
    newCheck:SetHitRectInsets(0, 0, 0, 0)
    newCheck.text = _G[newCheck:GetName() .. "Text"]
    newCheck.text:SetPoint("LEFT", self, "TOPLEFT", 42+colX, -48.3-rowY)
    newCheck.text:SetPoint("RIGHT", self, "TOPRIGHT", -318+colX, -48.3-rowY)
    newCheck.text:SetFontObject("GameFontDisableSmall")
    newCheck.text:SetText(newText)
    newCheck.text:SetJustifyH("CENTER")
    newCheck.slider = newSlider
    newCheck:Disable()
    newSlider:Disable()
    return newCheck, newSlider
end
