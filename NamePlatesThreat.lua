local function initVariables(oldAcct) -- only the variables below are used by the addon
	local newAcct, key, value = {}
	newAcct["addonsEnabled"] = true  -- color by threat those nameplates you can attack
	newAcct["colBorderOnly"] = false -- ignore healthbar and color nameplate border instead
	newAcct["showPetThreat"] = true  -- include pets as offtanks when coloring nameplates
	newAcct["enableOutside"] = true  -- also color nameplates outside PvE instances
	newAcct["enableNoFight"] = true  -- also color nameplates not fighting your group
	newAcct["hostilesColor"] = {r=163, g= 48, b=201} -- violet hostile not in group fight
	newAcct["neutralsColor"] = {r=  0, g=112, b=222} -- blue   neutral not in group fight
	newAcct["enablePlayers"] = false -- also color nameplates for player characters
	newAcct["pvPlayerColor"] = {r=245, g=140, b=186} -- pink   player not in group fight
	newAcct["gradientColor"] = true  -- update nameplate color gradients (some CPU usage)
	newAcct["gradientPrSec"] = 5	 -- update color gradients this many times per second
	newAcct["youTankCombat"] = true  -- unique colors in combat instead of colors above
	newAcct["youTank7color"] = {r=255, g=  0, b=  0} -- red    healers tanking by threat
	newAcct["youTank0color"] = {r=255, g=153, b=  0} -- orange others tanking by threat
	newAcct["youTank2color"] = {r=255, g=255, b=120} -- yellow you are tanking by force	* v reuse 4	gray
	newAcct["youTank3color"] = {r=176, g=176, b=176} -- gray   you are tanking by threat	*		green
	newAcct["youTank5color"] = {r=  0, g=217, b=  0} -- green  group tanks tank by threat	*		gray
	newAcct["youTank6color"] = {r=255, g=153, b=  0} -- orange healers tanking by force
	newAcct["youTank1color"] = {r=255, g=255, b=120} -- yellow others tanking by force
	newAcct["youTank4color"] = {r=176, g=176, b=176} -- gray   group tanks tank by force	* ^ allow 2	yellow
	newAcct["nonTankUnique"] = false -- unique nontank colors instead of flip colors above
	newAcct["nonTank7color"] = {r=255, g=  0, b=  0} -- red    healers tanking by threat
	newAcct["nonTank0color"] = {r=255, g=153, b=  0} -- orange you are tanking by threat
	newAcct["nonTank1color"] = {r=255, g=255, b=120} -- yellow you are tanking by force	4 <
	newAcct["nonTank3color"] = {r=176, g=176, b=176} -- gray   others tanking by threat
	newAcct["nonTank5color"] = {r=  0, g=217, b=  0} -- green  group tanks tank by threat
	newAcct["nonTank6color"] = {r=255, g=153, b=  0} -- orange healers tanking by force
	newAcct["nonTank2color"] = {r=255, g=255, b=120} -- yellow others tanking by force
	newAcct["nonTank4color"] = {r=176, g=176, b=176} -- gray   group tanks tank by force	2 <
	newAcct["forcingUnique"] = false -- unique force colors instead of reuse threat colors

	if oldAcct then -- override defaults with imported values if old keys match new keys
		--print("oldAcct:Begin")
		for key, value in pairs(newAcct) do
			if oldAcct[key] ~= nil then
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
NPT.addonIndex = 0

local NPTframe = CreateFrame("Frame", nil, NPT) -- options panel for tweaking the addon
NPTframe.lastSwatch = nil

local function resetFrame(frame)
	if frame.threat then
		frame.threat = nil
		if frame.unit then
			CompactUnitFrame_UpdateName(frame)
			CompactUnitFrame_UpdateHealthBorder(frame)
			CompactUnitFrame_UpdateHealthColor(frame)
		else
			frame.healthBar.border:SetVertexColor(frame.healthBar.border.r, frame.healthBar.border.g, frame.healthBar.border.b, frame.healthBar.border.a)
		end
		frame.healthBar:SetStatusBarColor(frame.healthBar.r, frame.healthBar.g, frame.healthBar.b, frame.healthBar.a)
	end
end

local function updatePlateColor(frame, ...)
	local forceUpdate = ...
	if frame.threat then
		if not forceUpdate then
			local currentColor = {}
			if NPTacct.colBorderOnly then
				if frame.unit and UnitIsUnit(frame.unit, "playertarget") then
					currentColor.a = frame.name.a
					currentColor.r = frame.name.r
					currentColor.g = frame.name.g
					currentColor.b = frame.name.b
				else
					currentColor.a = frame.healthBar.border.a
					currentColor.r = frame.healthBar.border.r
					currentColor.g = frame.healthBar.border.g
					currentColor.b = frame.healthBar.border.b
				end
			else
				currentColor.a = frame.healthBar.a
				currentColor.r = frame.healthBar.r
				currentColor.g = frame.healthBar.g
				currentColor.b = frame.healthBar.b
			end
			if currentColor.r ~= frame.threat.color.r
				or currentColor.g ~= frame.threat.color.g
				or currentColor.b ~= frame.threat.color.b
			then
				forceUpdate = true
			end
		end
		if forceUpdate then
			if NPTacct.colBorderOnly then
				if frame.unit and UnitIsUnit(frame.unit, "playertarget") then
					frame.name:SetVertexColor(frame.threat.color.r, frame.threat.color.g, frame.threat.color.b, frame.threat.color.a)
				else
					frame.healthBar.border:SetVertexColor(frame.threat.color.r, frame.threat.color.g, frame.threat.color.b, frame.threat.color.a)
				end
			else
				frame.healthBar:SetStatusBarColor(frame.threat.color.r, frame.threat.color.g, frame.threat.color.b, frame.threat.color.a)
			end
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
		table.insert(collectedTanks, "pet")
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
			if NPTacct.showPetThreat and UnitExists(unit) then
				table.insert(collectedTanks, unit)
			end
		end
	end
	return collectedTanks, collectedPlayer, collectedOther, collectedHeals
end

local function threatSituation(monster)
	local targetStatus = -1
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
		if NPTacct.youTankCombat and status then
			if isTanking then
				threatStatus = status + 2
				tankValue = threatValue
			elseif threatValue > offTankValue then
				offTankValue = threatValue
			end
		end
		if UnitIsUnit(unit, monster .. "target") then
			targetStatus = 5
		end
	end
	-- store if the player is tanking, or store their threat value if higher than others
	isTanking, status, _, _, threatValue = UnitDetailedThreatSituation("player", monster)
	if NPTacct.youTankCombat and status then
		if isTanking then
			threatStatus = status
			tankValue = threatValue
		else
			playerValue = threatValue
		end
	end
	if UnitIsUnit("player", monster .. "target") then
		targetStatus = 3
	end
	-- store if a non-tank is tanking, or store their threat value if higher than others
	for _, unit in ipairs(NPT.nonTanks) do
		isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
		if NPTacct.youTankCombat and status then
			if isTanking then
				threatStatus = 3 - status
				tankValue = threatValue
			elseif threatValue > nonTankValue then
				nonTankValue = threatValue
			end
		end
		if UnitIsUnit(unit, monster .. "target") then
			targetStatus = 0
		end
	end
	-- store if an offheal is tanking, or store their threat value if higher than others
	for _, unit in ipairs(NPT.offHeals) do
		isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
		if NPTacct.youTankCombat and status then
			if isTanking then
				threatStatus = status + 4
				tankValue = threatValue
			elseif threatValue > offHealValue then
				offHealValue = threatValue
			end
		end
		if UnitIsUnit(unit, monster .. "target") then
			targetStatus = 7
		end
	end
	-- default to offtank low threat on a nongroup target if none of the above were a match
	if targetStatus < 0 and UnitExists(monster .. "target") then
		unit = monster .. "target"
		isTanking, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
		if NPTacct.youTankCombat and status and NPTacct.showPetThreat then
			if isTanking then
				threatStatus = status + 2
				tankValue = threatValue
			elseif threatValue > offTankValue then
				offTankValue = threatValue
			end
		end
		targetStatus = 4
	end
	-- clear threat values if tank was found through monster target instead of threat
	if targetStatus > -1 and (UnitIsPlayer(monster) or threatStatus < 0) then
		threatStatus = targetStatus
		tankValue = 0
		offTankValue = 0
		playerValue  = 0
		nonTankValue = 0
		offHealValue = 0
	end
	-- deliver the stored information describing threat situation for this monster
	return threatStatus, tankValue, offTankValue, playerValue, nonTankValue, offHealValue
end

local function updateThreatColor(frame, status, tank, offtank, player, nontank, offheal)
	local unit, ratio = IsInInstance()
	if unit and (ratio == "party" or ratio == "raid" or ratio == "scenario") then
		ratio = true -- indicates a PvE instance
	else
		ratio = false -- PvP or non-instance zone
	end
	unit = frame.unit

	if NPTacct.addonsEnabled -- only color nameplates you can attack if addon is active
		and UnitCanAttack("player", unit) and not CompactUnitFrame_IsTapDenied(frame)
		and (NPTacct.enableOutside or ratio) -- and outside or players only if enabled
		and (NPTacct.enablePlayers or not UnitIsPlayer(unit)) then

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

		if not status then
			status, tank, offtank, player, nontank, offheal = threatSituation(unit)
		else
			unit = nil -- indicates we fetched threat values from provided inputs
		end
		-- compare highest group threat with tank for color gradient if enabled
		if NPTacct.gradientColor and status > -1 then
			if NPT.playerRole == "TANK" then
				if status == 0 or status == 1 then
					ratio = math.max(offtank, player)
				else -- you or an offtank are tanking the monster
					ratio = math.max(nontank, offheal)
				end
			else
				if status == 2 or status == 3 then
					ratio = math.max(offtank, nontank, offheal)
				else -- someone is tanking the monster for you
					ratio = player
				end
			end
			if status == 1 or status == 2 or status == 4 or status == 6 then
				ratio = tank / math.max(ratio, 1)
			else -- monster is tanked by someone via threat
				ratio = ratio / math.max(tank, 1)
			end
			ratio = math.min(ratio, 1)
		else
			ratio = 0
		end
		if not unit then
			unit = frame.unit -- no need to flip status when fetched from inputs
		elseif status > -1 and NPT.playerRole ~= "TANK" and status < 4 then
			status = 3 - status
		end -- flip colors when not a tank role and no group tanks or healers are tanking
	end
	if not status or not NPTacct.enableNoFight and NPT.thisUpdate and status < 0 then
		resetFrame(frame) -- only recolor when situation was changed with gradient toward sibling color
	elseif not frame.threat or frame.threat.lastStatus ~= status or frame.threat.lastRatio ~= ratio then
		local color = NPTacct.hostilesColor -- color outside group (others for players or neutrals)
		if UnitIsPlayer(unit) then
			color = NPTacct.pvPlayerColor
		elseif UnitReaction(unit, "player") > 3 then
			color = NPTacct.neutralsColor
		end
		local fader = color

		if status > -1 then -- color depending on threat or target situation odd/even
			color = status
			if status % 2 == 0 then
				fader = status + 1
			else
				fader = status - 1
			end
			if not NPTacct.forcingUnique then -- reuse threat tanking colors or forced fader/color 1
				if status == 7 then
					fader = 0
				elseif status == 6 then
					color = 0
				elseif status == 5 then
					fader = 3
				elseif status == 4 then
					color = 3
				elseif status == 3 and NPT.playerRole ~= "TANK" and NPTacct.nonTankUnique then
					fader = 1
				elseif status == 2 and NPT.playerRole ~= "TANK" and NPTacct.nonTankUnique then
					color = 1
				elseif status == 3 then
					fader = 2
				elseif status == 1 then
					color = 2
				end
			end
-- mikfhan begin TODO: remove forced unique and reduce number of colors and use green when player is tank role?
			-- if NPT.playerRole == "TANK" then
				-- if status == 0 then		-- others tanking by threat	orange to yellow
					-- color = 0
					-- if NPTacct.forcingUnique then fader = 1 else fader = 2 end
				-- elseif status == 1 then	-- others tanking by force	yellow to orange
					-- if NPTacct.forcingUnique then color = 1 else color = 2 end
					-- fader = 0
				-- elseif status == 2 then	-- you're tanking by force	gray to green
					-- color = 2
					-- fader = 3
				-- elseif status == 3 then	-- you're tanking by threat	green to gray
					-- color = 3
					-- fader = 2
				-- elseif status == 4 then	-- tanks tanking by force	yellow to gray
					-- if NPTacct.forcingUnique then color = 4 else color = 2 end
					-- fader = 5
				-- elseif status == 5 then	-- tanks tanking by threat	gray to yellow
					-- color = 5
					-- if NPTacct.forcingUnique then fader = 4 else fader = 2 end
				-- elseif status == 6 then	-- healer tanking by force	orange to red
					-- if NPTacct.forcingUnique then color = 6 else color = 0 end
					-- fader = 7
				-- elseif status == 7 then	-- healer tanking by threat	red to orange
					-- color = 7
					-- if NPTacct.forcingUnique then fader = 6 else fader = 0 end
				-- end
			-- elseif NPTacct.nonTankUnique then
				-- if status == 0 then		-- others tanking by threat	gray to yellow
					-- color = 0
					-- if NPTacct.forcingUnique then fader = 1 else fader = 2 end
				-- elseif status == 1 then	-- others tanking by force	yellow to gray
					-- if NPTacct.forcingUnique then color = 1 else color = 2 end
					-- fader = 0
				-- elseif status == 2 then	-- you're tanking by force	yellow to orange
					-- color = 2
					-- fader = 3
				-- elseif status == 3 then	-- you're tanking by threat	orange to yellow
					-- color = 3
					-- fader = 2
				-- elseif status == 4 then	-- tanks tanking by force	gray to green
					-- if NPTacct.forcingUnique then color = 4 else color = 2 end
					-- fader = 5
				-- elseif status == 5 then	-- tanks tanking by threat	green to gray
					-- color = 5
					-- if NPTacct.forcingUnique then fader = 4 else fader = 2 end
				-- elseif status == 6 then	-- healer tanking by force	orange to red
					-- if NPTacct.forcingUnique then color = 6 else color = 0 end
					-- fader = 7
				-- elseif status == 7 then	-- healer tanking by threat	red to orange
					-- color = 7
					-- if NPTacct.forcingUnique then fader = 6 else fader = 0 end
				-- end
			-- else
				-- if status == 0 then		-- others tanking by threat	gray to yellow
					-- color = 5
					-- if NPTacct.forcingUnique then fader = 4 else fader = 2 end
				-- elseif status == 1 then	-- others tanking by force	yellow to gray
					-- if NPTacct.forcingUnique then color = 4 else color = 2 end
					-- fader = 5
				-- elseif status == 2 then	-- you're tanking by force	yellow to orange
					-- if NPTacct.forcingUnique then color = 1 else color = 2 end
					-- fader = 0
				-- elseif status == 3 then	-- you're tanking by threat	orange to yellow
					-- color = 0
					-- if NPTacct.forcingUnique then fader = 1 else fader = 2 end
				-- elseif status == 4 then	-- tanks tanking by force	gray to green
					-- color = 2
					-- fader = 3
				-- elseif status == 5 then	-- tanks tanking by threat	green to gray
					-- color = 3
					-- fader = 2
				-- elseif status == 6 then	-- healer tanking by force	orange to red
					-- if NPTacct.forcingUnique then color = 6 else color = 0 end
					-- fader = 7
				-- elseif status == 7 then	-- healer tanking by threat	red to orange
					-- color = 7
					-- if NPTacct.forcingUnique then fader = 6 else fader = 0 end
				-- end
			-- end
-- mikfhan finish
			if NPT.playerRole == "TANK" or not NPTacct.nonTankUnique then
				color = NPTacct["youTank" .. color .. "color"]
				fader = NPTacct["youTank" .. fader .. "color"]
			else
				color = NPTacct["nonTank" .. color .. "color"]
				fader = NPTacct["nonTank" .. fader .. "color"]
			end
		end
		if not frame.threat then
			frame.threat = {
				["color"] = {}
			}
			frame.threat.color.a = 1
		end
		frame.threat.lastStatus = status
		frame.threat.lastRatio = ratio

		if NPTacct.gradientColor and ratio > 0 then
			frame.threat.color.r = (color.r + (fader.r - color.r) * ratio) / 255
			frame.threat.color.g = (color.g + (fader.g - color.g) * ratio) / 255
			frame.threat.color.b = (color.b + (fader.b - color.b) * ratio) / 255
		else -- skip fading color by a linear gradient toward the fader
			frame.threat.color.r = color.r / 255
			frame.threat.color.g = color.g / 255
			frame.threat.color.b = color.b / 255
		end
		updatePlateColor(frame, false)
	end
	return frame, status, tank, offtank, player, nontank, offheal
end

-- The color is only going to be reset after it was actually changed.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", updatePlateColor)
hooksecurefunc("CompactUnitFrame_UpdateHealthBorder", updatePlateColor)

NPT:RegisterEvent("PLAYER_TARGET_CHANGED")
NPT:RegisterEvent("UNIT_TARGET")
NPT:RegisterEvent("PLAYER_REGEN_ENABLED")
NPT:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
NPT:RegisterEvent("NAME_PLATE_UNIT_ADDED")
NPT:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
NPT:RegisterEvent("PLAYER_ROLES_ASSIGNED")
NPT:RegisterEvent("RAID_ROSTER_UPDATE")
NPT:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
NPT:RegisterEvent("PLAYER_ENTERING_WORLD")
NPT:RegisterEvent("PET_DISMISS_START")
NPT:RegisterEvent("UNIT_PET")
NPT:RegisterEvent("ADDON_LOADED")
NPT:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and string.upper(arg1) == string.upper("NamePlatesThreat") then
		repeat
			NPT.addonIndex = NPT.addonIndex + 1
		until string.upper(GetAddOnInfo(NPT.addonIndex)) == string.upper(arg1)
		NPTacct = initVariables(NPTacct) -- import variables or reset to defaults
		NPTframe:Initialize()
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_ENTERING_WORLD" or
		event == "PLAYER_ROLES_ASSIGNED" or event == "RAID_ROSTER_UPDATE" or
		event == "PET_DISMISS_START" or event == "UNIT_PET" then
		NPT.offTanks, NPT.playerRole, NPT.nonTanks, NPT.offHeals = getGroupRoles()
		local key, nameplate
		for key, nameplate in pairs(C_NamePlate.GetNamePlates()) do
			resetFrame(nameplate.UnitFrame)
		end
		if event == "PLAYER_ENTERING_WORLD" then
			--InterfaceOptionsFrame_OpenToCategory(NPTframe) --for debugging only
			--InterfaceOptionsFrame_OpenToCategory(NPTframe) --must call it twice
		else
			self:GetScript("OnEvent")(self, "UNIT_THREAT_SITUATION_UPDATE")
		end
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "NAME_PLATE_UNIT_ADDED" or
		event == "PLAYER_REGEN_ENABLED" or event == "UNIT_TARGET" or event == "PLAYER_TARGET_CHANGED" then
		local callback = function()
			local nameplates, key, nameplate = {}
			if InCombatLockdown() then
				NPT.thisUpdate = nil -- to force enable non combat colors while fighting
			end
			for key, nameplate in pairs(C_NamePlate.GetNamePlates()) do
				nameplate = {updateThreatColor(nameplate.UnitFrame)}
				if not NPTacct.enableNoFight and NPT.thisUpdate and nameplate[2] then
					if nameplate[2] < 0 then
						table.insert(nameplates, nameplate) -- store for recoloring later
					else
						NPT.thisUpdate = nil -- meaning we must recolor non combat plates
					end
				end
			end
			for key, nameplate in pairs(nameplates) do
				updateThreatColor(unpack(nameplate)) -- recolor previously stored plates
			end
			NPT.thisUpdate = 0
		end
		if event == "PLAYER_REGEN_ENABLED" then
			C_Timer.NewTimer(5.0, callback)
		else -- to ensure colors update after combat when mob is back at their spawn
			callback()
		end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local nameplate = C_NamePlate.GetNamePlateForUnit(arg1)
		if nameplate then
			resetFrame(nameplate.UnitFrame)
		end
	end
end)
NPT:SetScript("OnUpdate", function(self, elapsed)
	if NPTacct.addonsEnabled and NPTacct.gradientColor then
		NPT.thisUpdate = NPT.thisUpdate + elapsed
		if NPT.thisUpdate >= 1/NPTacct.gradientPrSec then
			NPT:GetScript("OnEvent")(NPT, "UNIT_THREAT_SITUATION_UPDATE")
		end
	end -- remember "/console reloadui" for any script changes to take effect
end)
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
		self.color:SetVertexColor(value.r / 255, value.g / 255, value.b / 255)
	end
	local r, g, b, changed = self.color:GetVertexColor()
	changed = {}
	changed.r = math.floor(0.5+255*r)
	changed.g = math.floor(0.5+255*g)
	changed.b = math.floor(0.5+255*b)
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
				ColorPickerFrame:SetColorRGB(r, g, b)
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
		r = math.floor(0.5+255*r)
		g = math.floor(0.5+255*g)
		b = math.floor(0.5+255*b)
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
function NPTframe.okay()
	NPTacct = initVariables(NPT.acct) -- store panel fields into addon variables
	NPT:GetScript("OnEvent")(NPT, "PLAYER_SPECIALIZATION_CHANGED")
end
function NPTframe.cancel()
	NPT.acct = initVariables(NPTacct) -- restore panel fields from addon variables
end
function NPTframe.default()
	NPT.acct = initVariables()
end
function NPTframe.refresh() -- called on panel shown or after default was accepted
	--print(GetServerTime() .. " NPTframe.refresh(): Begin")
	NPTframe.addonsEnabled:GetScript("PostClick")(NPTframe.addonsEnabled, nil, nil, NPT.acct.addonsEnabled, true)
	NPTframe.enableNoFight:GetScript("PostClick")(NPTframe.enableNoFight, nil, nil, NPT.acct.enableNoFight)
	NPTframe.enableOutside:GetScript("PostClick")(NPTframe.enableOutside, nil, nil, NPT.acct.enableOutside)
	NPTframe.enablePlayers:GetScript("PostClick")(NPTframe.enablePlayers, nil, nil, NPT.acct.enablePlayers)
	NPTframe.neutralsColor:GetScript("PostClick")(NPTframe.neutralsColor, nil, nil, NPT.acct.neutralsColor)
	NPTframe.hostilesColor:GetScript("PostClick")(NPTframe.hostilesColor, nil, nil, NPT.acct.hostilesColor)
	NPTframe.pvPlayerColor:GetScript("PostClick")(NPTframe.pvPlayerColor, nil, nil, NPT.acct.pvPlayerColor)

	NPTframe.gradientColor:GetScript("PostClick")(NPTframe.gradientColor, nil, nil, NPT.acct.gradientColor)
	NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, NPT.acct.gradientPrSec)
	NPTframe.colBorderOnly:GetScript("PostClick")(NPTframe.colBorderOnly, nil, nil, NPT.acct.colBorderOnly)
	NPTframe.showPetThreat:GetScript("PostClick")(NPTframe.showPetThreat, nil, nil, NPT.acct.showPetThreat)

	NPTframe.youTankCombat:GetScript("PostClick")(NPTframe.youTankCombat, nil, nil, NPT.acct.youTankCombat)
	NPTframe.youTank7color:GetScript("PostClick")(NPTframe.youTank7color, nil, nil, NPT.acct.youTank7color)
	NPTframe.youTank0color:GetScript("PostClick")(NPTframe.youTank0color, nil, nil, NPT.acct.youTank0color)
	NPTframe.youTank2color:GetScript("PostClick")(NPTframe.youTank2color, nil, nil, NPT.acct.youTank2color)
	NPTframe.youTank3color:GetScript("PostClick")(NPTframe.youTank3color, nil, nil, NPT.acct.youTank3color)
	NPTframe.youTank5color:GetScript("PostClick")(NPTframe.youTank5color, nil, nil, NPT.acct.youTank5color)

	NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, NPT.acct.forcingUnique)
	NPTframe.youTank6color:GetScript("PostClick")(NPTframe.youTank6color, nil, nil, NPT.acct.youTank6color)
	NPTframe.youTank1color:GetScript("PostClick")(NPTframe.youTank1color, nil, nil, NPT.acct.youTank1color)
	NPTframe.youTank4color:GetScript("PostClick")(NPTframe.youTank4color, nil, nil, NPT.acct.youTank4color)

	NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, NPT.acct.nonTankUnique)
	NPTframe.nonTank7color:GetScript("PostClick")(NPTframe.nonTank7color, nil, nil, NPT.acct.nonTank7color)
	NPTframe.nonTank3color:GetScript("PostClick")(NPTframe.nonTank3color, nil, nil, NPT.acct.nonTank3color)
	NPTframe.nonTank1color:GetScript("PostClick")(NPTframe.nonTank1color, nil, nil, NPT.acct.nonTank1color)
	NPTframe.nonTank0color:GetScript("PostClick")(NPTframe.nonTank0color, nil, nil, NPT.acct.nonTank0color)
	NPTframe.nonTank5color:GetScript("PostClick")(NPTframe.nonTank5color, nil, nil, NPT.acct.nonTank5color)

	NPTframe.nonTank6color:GetScript("PostClick")(NPTframe.nonTank6color, nil, nil, NPT.acct.nonTank6color)
	NPTframe.nonTank2color:GetScript("PostClick")(NPTframe.nonTank2color, nil, nil, NPT.acct.nonTank2color)
	NPTframe.nonTank4color:GetScript("PostClick")(NPTframe.nonTank4color, nil, nil, NPT.acct.nonTank4color)
	--print(GetServerTime() .. " NPTframe.refresh(): Finish")
end
function NPTframe:Initialize()
	self:cancel() -- simulate options cancel so panel variables are reset
	self.name = GetAddOnMetadata(NPT.addonIndex, "Title")

	self.bigTitle = self:CreateFontString("bigTitle", "ARTWORK", "GameFontNormalLarge")
	self.bigTitle:SetPoint("LEFT", self, "TOPLEFT", 16, -24)
	self.bigTitle:SetPoint("RIGHT", self, "TOPRIGHT", -32, -24)
	self.bigTitle:SetJustifyH("LEFT")
	self.bigTitle:SetText(GetAddOnMetadata(NPT.addonIndex, "Title") .. " " .. GetAddOnMetadata(NPT.addonIndex, "Version") .. " by " .. GetAddOnMetadata(NPT.addonIndex, "Author"))
	self.bigTitle:SetHeight(self.bigTitle:GetStringHeight() * 1)

	self.subTitle = self:CreateFontString("subTitle", "ARTWORK", "GameFontHighlightSmall")
	self.subTitle:SetPoint("LEFT", self, "TOPLEFT", 16, -50)
	self.subTitle:SetPoint("RIGHT", self, "TOPRIGHT", -32, -50)
	self.subTitle:SetJustifyH("LEFT")
	self.subTitle:SetText(GetAddOnMetadata(NPT.addonIndex, "Notes") .. " Press Okay to keep unsaved AddOn changes in yellow below, press Escape or Cancel to discard unsaved changes, or click Defaults > These Settings to reset everything below.")
	self.subTitle:SetHeight(self.subTitle:GetStringHeight() * 2)

	self.addonsEnabled = self:CheckButtonCreate("addonsEnabled", "Color Non-Friendly Nameplates", "Enable for AddOn to function.", 1)
	self.addonsEnabled:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.enableNoFight:GetScript("PostClick")(NPTframe.enableNoFight, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.enableOutside:GetScript("PostClick")(NPTframe.enableOutside, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.enablePlayers:GetScript("PostClick")(NPTframe.enablePlayers, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.hostilesColor:GetScript("PostClick")(NPTframe.hostilesColor, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.neutralsColor:GetScript("PostClick")(NPTframe.neutralsColor, nil, nil, nil, NPT.acct.addonsEnabled)

		NPTframe.gradientColor:GetScript("PostClick")(NPTframe.gradientColor, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.colBorderOnly:GetScript("PostClick")(NPTframe.colBorderOnly, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.showPetThreat:GetScript("PostClick")(NPTframe.showPetThreat, nil, nil, nil, NPT.acct.addonsEnabled)

		NPTframe.youTankCombat:GetScript("PostClick")(NPTframe.youTankCombat, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.nonTankForced:GetScript("PostClick")(NPTframe.nonTankForced, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)

	self.colBorderOnly = self:CheckButtonCreate("colBorderOnly", "Color Nameplate Border Only", "Enable coloring only the border instead of the whole nameplate.", 1, 1)
	self.colBorderOnly:SetScript("PostClick", NPTframe.CheckButtonPostClick)

	self.showPetThreat = self:CheckButtonCreate("showPetThreat", "Color Group Pets as Tanks", "Enable group pets as secondary tanks when coloring nameplates instead of only including yours.", 1, 2)
	self.showPetThreat:SetScript("PostClick", NPTframe.CheckButtonPostClick)

	self.enableOutside = self:CheckButtonCreate("enableOutside", "Color Out of Dungeons", "Enable coloring nameplates outside PvE instanced zones.", 1, 3)
	self.enableOutside:SetScript("PostClick", NPTframe.CheckButtonPostClick)

	self.gradientColor, self.gradientPrSec = self:CheckSliderCreate("gradientColor", "Color Gradient Updates Per Second", "Enable fading of nameplates between high and low colors.", "gradientPrSec", 1, 9, 2, true)
	self.gradientColor:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.gradientColor)
	end)
	self.gradientPrSec:SetScript("OnValueChanged", NPTframe.SliderOnValueChanged)

	self.enableNoFight = self:CheckButtonCreate("enableNoFight", "Color Out of Combat", "Enable coloring nameplates when group is not in combat.", 4, nil, false)
	self.enableNoFight:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.hostilesColor:GetScript("PostClick")(NPTframe.hostilesColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enableNoFight)
		NPTframe.neutralsColor:GetScript("PostClick")(NPTframe.neutralsColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enableNoFight)
	end)
	self.hostilesColor = self:ColorSwatchCreate("hostilesColor", "Hostile is Out of Combat", "", 4, 1, false)
	self.hostilesColor:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.neutralsColor = self:ColorSwatchCreate("neutralsColor", "Neutral is Out of Combat", "", 4, 2, false)
	self.neutralsColor:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

	self.enablePlayers = self:CheckButtonCreate("enablePlayers", "Color Player Characters", "Enable coloring nameplates of PvP flagged enemy players.", 6, nil, false)
	self.enablePlayers:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.pvPlayerColor:GetScript("PostClick")(NPTframe.pvPlayerColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enablePlayers)
	end)
	self.pvPlayerColor = self:ColorSwatchCreate("pvPlayerColor", "Player is Out of Combat", "", 6, 1, false)
	self.pvPlayerColor:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

	self.youTankCombat = self:CheckButtonCreate("youTankCombat", "Color Nameplates by Threat", "Enable coloring nameplates by their threat values and which group role is currently tanking.", 8)
	self.youTankCombat:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.youTank7color:GetScript("PostClick")(NPTframe.youTank7color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank0color:GetScript("PostClick")(NPTframe.youTank0color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank2color:GetScript("PostClick")(NPTframe.youTank2color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank3color:GetScript("PostClick")(NPTframe.youTank3color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank5color:GetScript("PostClick")(NPTframe.youTank5color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)
	self.youTank7color = self:ColorSwatchCreate("youTank7color", "Healers have High Threat", "", 8, 1)
	self.youTank7color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.youTank0color = self:ColorSwatchCreate("youTank0color", "Damage has High Threat", "", 8, 2)
	self.youTank0color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.youTank2color = self:ColorSwatchCreate("youTank2color", "You have the Low Threat", "", 8, 3)
	self.youTank2color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.youTank3color = self:ColorSwatchCreate("youTank3color", "You have the High Threat", "", 8, 4)
	self.youTank3color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.youTank5color = self:ColorSwatchCreate("youTank5color", "Tanks have High Threat", "", 8, 5)
	self.youTank5color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

	self.forcingUnique = self:CheckButtonCreate("forcingUnique", "Unique Colors Forced Tanking", "Enable colors below instead of reusing colors above when others are tanking by force.", 12)
	self.forcingUnique:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.youTank6color:GetScript("PostClick")(NPTframe.youTank6color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique)
		NPTframe.youTank1color:GetScript("PostClick")(NPTframe.youTank1color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique)
		NPTframe.youTank4color:GetScript("PostClick")(NPTframe.youTank4color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique)
		NPTframe.nonTankForced:GetScript("PostClick")(NPTframe.nonTankForced, nil, nil, NPT.acct.forcingUnique and NPT.acct.nonTankUnique, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)
	self.youTank6color = self:ColorSwatchCreate("youTank6color", "Healers have Low Threat", "", 12, 1)
	self.youTank6color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.youTank1color = self:ColorSwatchCreate("youTank1color", "Damage has Low Threat", "", 12, 2)
	self.youTank1color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.youTank4color = self:ColorSwatchCreate("youTank4color", "Tanks have Low Threat", "", 12, 3)
	self.youTank4color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

	self.nonTankUnique = self:CheckButtonCreate("nonTankUnique", "Unique Colors as Non-Tank Role", "Enable colors below in a non-tank specialization instead of reusing colors to the left.", 8, nil, true)
	self.nonTankUnique:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.nonTank7color:GetScript("PostClick")(NPTframe.nonTank7color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank0color:GetScript("PostClick")(NPTframe.nonTank0color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank1color:GetScript("PostClick")(NPTframe.nonTank1color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank3color:GetScript("PostClick")(NPTframe.nonTank3color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank5color:GetScript("PostClick")(NPTframe.nonTank5color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTankForced:GetScript("PostClick")(NPTframe.nonTankForced, nil, nil, NPT.acct.forcingUnique and NPT.acct.nonTankUnique, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)
	self.nonTank7color = self:ColorSwatchCreate("nonTank7color", "Healers have High Threat", "", 8, 1, true)
	self.nonTank7color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.nonTank0color = self:ColorSwatchCreate("nonTank0color", "You have the High Threat", "", 8, 2, true)
	self.nonTank0color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.nonTank1color = self:ColorSwatchCreate("nonTank1color", "You have the Low Threat", "", 8, 3, true)
	self.nonTank1color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.nonTank3color = self:ColorSwatchCreate("nonTank3color", "Damage has High Threat", "", 8, 4, true)
	self.nonTank3color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.nonTank5color = self:ColorSwatchCreate("nonTank5color", "Tanks have High Threat", "", 8, 5, true)
	self.nonTank5color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

	self.nonTankForced = self:CheckButtonCreate("nonTankForced", "Unique Colors Forced Non-Tank", "Enable colors below instead of reusing colors above when others are tanking by force.", 12, nil, true)
	self.nonTankForced:SetScript("PostClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		if value == nil and enable == nil then
			value = self:GetChecked()
			NPTframe.forcingUnique:GetScript("PostClick")(NPTframe.forcingUnique, nil, nil, value)
			NPTframe.nonTankUnique:GetScript("PostClick")(NPTframe.nonTankUnique, nil, nil, value)
		end
		if (NPT.acct.forcingUnique and NPT.acct.nonTankUnique) ~= (NPTacct.forcingUnique and NPTacct.nonTankUnique) then
			NPTframe.nonTankForced.text:SetFontObject("GameFontNormal")
		elseif self:IsEnabled() then
			NPTframe.nonTankForced.text:SetFontObject("GameFontHighlight")
		else
			NPTframe.nonTankForced.text:SetFontObject("GameFontDisable")
		end
		NPTframe.nonTank6color:GetScript("PostClick")(NPTframe.nonTank6color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
		NPTframe.nonTank2color:GetScript("PostClick")(NPTframe.nonTank2color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
		NPTframe.nonTank4color:GetScript("PostClick")(NPTframe.nonTank4color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
	end)
	self.nonTank6color = self:ColorSwatchCreate("nonTank6color", "Healers have Low Threat", "", 12, 1, true)
	self.nonTank6color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.nonTank2color = self:ColorSwatchCreate("nonTank2color", "Damage has Low Threat", "", 12, 2, true)
	self.nonTank2color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)
	self.nonTank4color = self:ColorSwatchCreate("nonTank4color", "Tanks have Low Threat", "", 12, 3, true)
	self.nonTank4color:SetScript("PostClick", NPTframe.ColorSwatchPostClick)

	InterfaceOptions_AddCategory(self)
end
function NPTframe:ColorSwatchCreate(newName, newText, toolText, mainRow, subRow, columnTwo)
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
	if toolText ~= nil and toolText ~= "" then
		newObject.toolText = toolText
		newObject:SetScript("OnEnter", function(self, motion)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.toolText, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		newObject:SetScript("OnLeave", GameTooltip_Hide)
	end
	return newObject
end
function NPTframe:CheckButtonCreate(newName, newText, toolText, mainRow, subRow, columnTwo)
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
	if toolText ~= nil and toolText ~= "" then
		newObject.toolText = toolText
		newObject:SetScript("OnEnter", function(self, motion)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.toolText, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		newObject:SetScript("OnLeave", GameTooltip_Hide)
	end
	return newObject
end
function NPTframe:CheckSliderCreate(newCheck, newText, toolText, newSlider, minVal, maxVal, mainRow, columnTwo)
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
	if toolText ~= nil and toolText ~= "" then
		newCheck.toolText = toolText
		newCheck:SetScript("OnEnter", function(self, motion)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.toolText, nil, nil, nil, nil, true)
			GameTooltip:Show()
		end)
		newCheck:SetScript("OnLeave", GameTooltip_Hide)
	end
	return newCheck, newSlider
end
