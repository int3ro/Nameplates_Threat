local function initVariables(oldAcct) -- only the variables below are used by the addon
	local newAcct, key, value = {}
	newAcct["addonsEnabled"] = true  -- color by threat those nameplates you can attack
	newAcct["colBorderOnly"] = false -- ignore healthbar and color nameplate border instead
	newAcct["showPetThreat"] = true  -- include pets as offtanks when coloring nameplates
	newAcct["enableOutside"] = true  -- also color nameplates outside PvE instances
	newAcct["enableNoFight"] = true  -- also color nameplates not fighting your group
	newAcct["hostilesColor"] = {r=163, g= 48, b=201} -- violet hostile not in group fight
	newAcct["neutralsColor"] = {r=  0, g=112, b=222} -- blue   neutral not in group fight
	newAcct["enablePlayers"] = true  -- also color nameplates for hostile player characters
	newAcct["pvPlayerColor"] = {r=245, g=140, b=186} -- pink   player not in group fight
	newAcct["gradientColor"] = true  -- fade nameplate colors low to high (some CPU usage)
	newAcct["gradientPrSec"] = 5	 -- update color gradients this many times per second
	newAcct["youTankCombat"] = false -- color by roles below instead of simple traffic light
	newAcct["youTank7color"] = {r=255, g=  0, b=  0} -- red    healers tanking by threat
	newAcct["youTank0color"] = {r=255, g=153, b=  0} -- orange others tanking by threat
	newAcct["youTank4color"] = {r=255, g=255, b=120} -- yellow group tanks tank by force
	newAcct["youTank2color"] = {r=176, g=176, b=176} -- gray   you are tanking by force
	newAcct["youTank3color"] = {r=  0, g=217, b=  0} -- green  you are tanking by threat
	newAcct["youTank6color"] = {r=255, g=153, b=  0} -- orange healers tanking by force (0)
	newAcct["youTank1color"] = {r=255, g=255, b=120} -- yellow others tanking by force (4)
	newAcct["youTank5color"] = {r=176, g=176, b=176} -- gray   group tanks tank by threat (2)
	newAcct["nonTankUnique"] = false -- unique nontank colors instead of flip colors above
	newAcct["nonTank7color"] = {r=255, g=  0, b=  0} -- red    healers tanking by threat
	newAcct["nonTank3color"] = {r=255, g=153, b=  0} -- orange you are tanking by threat
	newAcct["nonTank2color"] = {r=255, g=255, b=120} -- yellow you are tanking by force
	newAcct["nonTank0color"] = {r=176, g=176, b=176} -- gray   others tanking by threat
	newAcct["nonTank5color"] = {r=  0, g=217, b=  0} -- green  group tanks tank by threat
	newAcct["nonTank6color"] = {r=255, g=153, b=  0} -- orange healers tanking by force (3)
	newAcct["nonTank1color"] = {r=255, g=255, b=120} -- yellow others tanking by force (2)
	newAcct["nonTank4color"] = {r=176, g=176, b=176} -- gray   group tanks tank by force (0)
	newAcct["forcingUnique"] = false -- unique force colors instead of reuse threat colors

	if oldAcct then -- override defaults with imported values if old keys match new keys
		--print("oldAcct:Begin")
		for key, value in pairs(newAcct) do
			if key == "colBorderOnly" and WOW_PROJECT_ID ~= WOW_PROJECT_MAINLINE then
				--print("newAcct:" .. key .. ":" .. "classic skip retail setting")
			elseif oldAcct[key] ~= nil then
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
local _, T = ...
local NPT = CreateFrame("Frame", nil, UIParent) -- invisible frame handling addon logic
NPT.addonIndex = 0
NPT.playerRole = "DAMAGER"
NPT.thisUpdate = 0
NPT.offTanks = {}
NPT.nonTanks = {}
NPT.offHeals = {}
NPT.nonHeals = {}
NPT.threat = {}

--mikfhan: below no longer needed?
--no longer needed? _, _, _, NPT.C_AddOns = GetBuildInfo()
--if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then
--	NPT.C_AddOns = _G.C_AddOns
--else
--	NPT.C_AddOns = _G
--end

local NPTframe = CreateFrame("Frame", nil, NPT) -- options panel for tweaking the addon
NPTframe.lastSwatch = nil

local function resetFrame(plate)
	--print(GetServerTime() .. " resetFrame(): Begin")
	if plate.UnitFrame and plate.UnitFrame.unit and UnitCanAttack("player", plate.UnitFrame.unit) and plate.UnitFrame.healthBar then
		if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and plate.UnitFrame.healthBar.border then
			if UnitIsUnit(plate.UnitFrame.unit, "target") then
				plate.UnitFrame.healthBar.border:SetVertexColor(1, 1, 1, 1)
			else
				plate.UnitFrame.healthBar.border:SetVertexColor(0, 0, 0, 1)
			end
			--print(GetServerTime() .. " resetFrame(): Border")
		end
		local currentColor = {r=1, g=0, b=0, a=1.0}
		if UnitReaction(plate.UnitFrame.unit, "player") > 3 then
			currentColor = {r=1, g=1, b=0, a=1}
		end	--possible /console taintlog 2 by directly setting rgba values so we can only SetStatusBarColor
		--currentColor.r, currentColor.g, currentColor.b, currentColor.a = plate.UnitFrame.healthBar:GetStatusBarColor()
		plate.UnitFrame.healthBar:SetStatusBarColor(currentColor.r, currentColor.g, currentColor.b, currentColor.a)
		--print(GetServerTime() .. " resetFrame(): Health")
	end
	if NPT.threat[plate.namePlateUnitToken] ~= nil then
		NPT.threat[plate.namePlateUnitToken] = nil
		--print(GetServerTime() .. " resetFrame(): Token")
	end
	--print(GetServerTime() .. " resetFrame(): Finish")
end

local function updatePlateColor(plate, ...)
	local forceUpdate = ...
	if NPT.threat[plate.namePlateUnitToken] and NPT.threat[plate.namePlateUnitToken].color then
		local currentColor = {r=0, g=0, b=0, a=0}
		if not plate.UnitFrame.healthBar or NPTacct.colBorderOnly and not plate.UnitFrame.healthBar.border then
			forceUpdate = false
		elseif not forceUpdate then
			if NPTacct.colBorderOnly then
				currentColor.r = plate.UnitFrame.healthBar.border.r or 0
				currentColor.g = plate.UnitFrame.healthBar.border.g or 0
				currentColor.b = plate.UnitFrame.healthBar.border.b or 0
				currentColor.a = plate.UnitFrame.healthBar.border.a or 0
			else
				currentColor.r = plate.UnitFrame.healthBar.r or 0
				currentColor.g = plate.UnitFrame.healthBar.g or 0
				currentColor.b = plate.UnitFrame.healthBar.b or 0
				currentColor.a = plate.UnitFrame.healthBar.a or 0
			end
			if currentColor.a ~= NPT.threat[plate.namePlateUnitToken].color.a
			or currentColor.r ~= NPT.threat[plate.namePlateUnitToken].color.r
			or currentColor.g ~= NPT.threat[plate.namePlateUnitToken].color.g
			or currentColor.b ~= NPT.threat[plate.namePlateUnitToken].color.b
			then
				forceUpdate = true
			end
		end
		currentColor = plate.UnitFrame.unit
		if forceUpdate and NPT.threat[plate.namePlateUnitToken].color.r and NPT.threat[plate.namePlateUnitToken].color.g and NPT.threat[plate.namePlateUnitToken].color.b then
			if NPTacct.colBorderOnly then
				plate.UnitFrame.healthBar.border:SetVertexColor(NPT.threat[plate.namePlateUnitToken].color.r, NPT.threat[plate.namePlateUnitToken].color.g, NPT.threat[plate.namePlateUnitToken].color.b, NPT.threat[plate.namePlateUnitToken].color.a or 1)
			else
				if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE and plate.UnitFrame.healthBar.border then
					if CompactUnitFrame_IsTapDenied(plate.UnitFrame) or currentColor and UnitIsTapDenied(currentColor) then
						plate.UnitFrame.healthBar.border:SetAlpha(0)
					else
						plate.UnitFrame.healthBar.border:SetAlpha(1)
					end
				end
				plate.UnitFrame.healthBar:SetStatusBarColor(NPT.threat[plate.namePlateUnitToken].color.r, NPT.threat[plate.namePlateUnitToken].color.g, NPT.threat[plate.namePlateUnitToken].color.b, NPT.threat[plate.namePlateUnitToken].color.a or 1)
			end
		end
	else
		resetFrame(plate)
	end
end

local function getGroupRoles()
	local collectedTanks = {}
	local collectedOther = {}
	local collectedHeals = {}
	local collectedPlayer, unitPrefix, unit, i, unitRole = "NONE"

	if IsInRaid() then
		unitPrefix = "raid"
	else
		unitPrefix = "party"
	end
	for i = 1, MAX_RAID_MEMBERS do
		unit = unitPrefix .. i
		unitRole = "NONE"
		if unitPrefix == "party" and i >= GetNumGroupMembers() then
			break
		elseif UnitExists(unit) then
			unitRole = UnitGroupRolesAssigned(unit)
			if unitRole == "NONE" then
				if unitPrefix == "raid" then
					_, _, _, _, _, _, _, _, _, unit, _, unitRole = GetRaidRosterInfo(i)
					if unit == "MAINTANK" or unit == "MAINASSIST" then
						unitRole = "TANK"
					end
					unit = unitPrefix .. i
				elseif UnitIsGroupLeader(unit) then
					unitRole = "TANK"
				end
			end
			if UnitIsUnit(unit, "player") then
				collectedPlayer = unitRole
			else
				if unitRole == "TANK" then
					table.insert(collectedTanks, unit)
				elseif unitRole == "HEALER" then
					table.insert(collectedHeals, unit)
				else
					table.insert(collectedOther, unit)
				end
				unit = unitPrefix .. "pet" .. i
				if UnitExists(unit) then
					if NPTacct.showPetThreat or unitRole == "TANK" then
						table.insert(collectedTanks, unit)
					else
						table.insert(collectedOther, unit)
					end
				end
			end
		end
	end
-- mikfhan: Outside raid groups the player is not counted amongst the party members
	if GetNumGroupMembers() > 0 then
		if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
-- mikfhan: Retail will use player spec regardless of the group role chosen earlier
			collectedPlayer = GetSpecializationRole(GetSpecialization())
		elseif unitPrefix == "party" then
-- mikfhan: Wrath Classic has no unit spec but talent panel has a party role up top
			collectedPlayer = UnitGroupRolesAssigned("player")
			if UnitIsGroupLeader("player") and (collectedPlayer == "NONE" or WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
-- mikfhan: Classic Era using party leader since roles did not even exist back then
				collectedPlayer = "TANK"
			end
		end
	end
	if UnitExists("pet") then
		if NPTacct.showPetThreat or collectedPlayer == "TANK" then
			table.insert(collectedTanks, "pet")
		else
			table.insert(collectedOther, "pet")
		end
	end
	if collectedPlayer ~= "TANK" and collectedPlayer ~= "HEALER" then
		collectedPlayer = "DAMAGER"
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
	local threatValue, status, unit = 0

-- mikfhan TODO: recheck status & scaledPercentage & isTanking there are maybe fine details
-- we've missed: https://wowpedia.fandom.com/wiki/API_UnitDetailedThreatSituation 

	-- store if an offtank is tanking, or store their threat value if higher than others
	for _, unit in ipairs(NPT.offTanks) do
		_, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
		if status and status > 1 then
			threatStatus = status + 2
			tankValue = threatValue
		elseif threatValue and threatValue > offTankValue then
			offTankValue = threatValue
		end
		if UnitIsUnit(unit, monster .. "target") then
			targetStatus = 5
		end
	end
	-- store if the player is tanking, or store their threat value if higher than others
	_, status, _, _, threatValue = UnitDetailedThreatSituation("player", monster)
	if status and status > 1 then
		threatStatus = status
		tankValue = threatValue
	elseif threatValue then
		playerValue = threatValue
	end
	if UnitIsUnit("player", monster .. "target") then
		targetStatus = 3
	end
	-- store if a non-tank is tanking, or store their threat value if higher than others
	for _, unit in ipairs(NPT.nonTanks) do
		_, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
		if status and status > 1 then
			threatStatus = 3 - status
			tankValue = threatValue
		elseif threatValue and threatValue > nonTankValue then
			nonTankValue = threatValue
		end
		if UnitIsUnit(unit, monster .. "target") then
			targetStatus = 0
		end
	end
	-- store if an offheal is tanking, or store their threat value if higher than others
	for _, unit in ipairs(NPT.offHeals) do
		_, status, _, _, threatValue = UnitDetailedThreatSituation(unit, monster)
		if status and status > 1 then
			threatStatus = status + 4
			tankValue = threatValue
		elseif threatValue and threatValue > offHealValue then
			offHealValue = threatValue
		end
		if UnitIsUnit(unit, monster .. "target") then
			targetStatus = 7
		end
	end
	-- pretend any other combat situation means monster is being offtanked by force
	if targetStatus < 0 and threatStatus < 0 and UnitAffectingCombat(monster) then
		if NPT.playerRole == "TANK" then
			targetStatus = 4
		else
			targetStatus = 1
		end
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

-- mikfhan: convert RGB max 1 into HSV max 1 color space (beware 0 > values > 1 rounding)
local function rgb2hsv(color)
	local cmax = math.max(color.r, color.g, color.b)
	local diff = cmax - math.min(color.r, color.g, color.b)

	local h = 0
	if diff ~= 0 then
		if cmax == color.r then
			h = (color.g - color.b) / diff + 6
		elseif cmax == color.g then
			h = (color.b - color.r) / diff + 8
		else
			h = (color.r - color.g) / diff + 10
		end
		h = (h % 6) / 6
	end
	local s = diff / math.max(cmax, 1)

	diff = {}
	diff.h = math.min(math.max(0, h), 1)
	diff.s = math.min(math.max(0, s), 1)
	diff.v = math.min(math.max(0, cmax), 1)
	diff.a = color.a
	return diff
end

-- mikfhan: convert HSV max 1 into RGB max 1 color space (beware 0 > values > 1 rounding)
local function hsv2rgb(color)
	local i = math.floor(color.h * 6)
	local p = color.h * 6 - i
	local q = color.v * (1 - p * 2)
	local t = color.v * (1 - (1 - p) * color.s)
	p = color.v * (1 - color.s)

	i = {r = i % 6}
	if i.r == 0 then
		i.r = color.v
		i.g = t
		i.b = p
	elseif i.r == 1 then
		i.r = q
		i.g = color.v
		i.b = p
	elseif i.r == 2 then
		i.r = p
		i.g = color.v
		i.b = t
	elseif i.r == 3 then
		i.r = p
		i.g = q
		i.b = color.v
	elseif i.r == 4 then
		i.r = t
		i.g = p
		i.b = color.v
	else
		i.r = color.v
		i.g = p
		i.b = q
	end
	i.r = math.min(math.max(0, i.r), 1)
	i.g = math.min(math.max(0, i.g), 1)
	i.b = math.min(math.max(0, i.b), 1)
	i.a = color.a
	return i
end

-- mikfhan: convert to hue/saturation/value before fading then back again
-- https://homepages.abdn.ac.uk/npmuseum/article/Maxwell/Legacy/Maxtriangle.gif
-- https://axonflux.com/handy-rgb-to-hsl-and-rgb-to-hsv-color-model-c
local function gradient(color, fader, ratio)
	local output = {r=0, g=0, b=0, a=1}
	output.r = color.r / 255
	output.g = color.g / 255
	output.b = color.b / 255
	if ratio > 0 then
		if ratio >= 1 then
			output.r = fader.r / 255
			output.g = fader.g / 255
			output.b = fader.b / 255
		elseif NPTacct.gradientColor then -- maximum ratio just uses the fader 100%
			output = rgb2hsv(output)
			output.a = {r=fader.r/255, g=fader.g/255, b=fader.b/255, a=output.a}
			output.a = rgb2hsv(output.a)

			output.h = (output.h + (output.a.h - output.h) * ratio)
			output.s = (output.s + (output.a.s - output.s) * ratio)
			output.v = (output.v + (output.a.v - output.v) * ratio)
			output.a = output.a.a
			output = hsv2rgb(output)
		end -- otherwise convert to HSV and fade then back to RGB
	end
	return output
end

local function updateThreatColor(plate, status, tank, offtank, player, nontank, offheal)
	local color, fader, unit, ratio = IsInInstance()
	if color and (fader == "party" or fader == "raid" or fader == "scenario") then
		fader = true -- indicates a PvE instance
	else
		fader = false -- PvP or non-instance zone
	end
	unit = plate.UnitFrame.unit
	ratio = 0

	if NPTacct.addonsEnabled -- only color nameplates you can attack if addon is active
		and UnitCanAttack("player", unit)
		and (NPTacct.enableOutside or fader) -- and outside or players only if enabled
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
		end
		-- compare highest group threat with tank for color gradient if enabled
		if status > -1 then
			if NPTacct.youTankCombat and (status == 6 or status == 7) then
				ratio = math.max(offtank, player, nontank)
			elseif NPT.playerRole == "TANK" then
				if status == 0 or status == 1 or status == 6 or status == 7 then
					ratio = math.max(offtank, player)
				else -- damage roles are tanking the monster
					ratio = math.max(nontank, offheal)
				end -- offtanks or you as tank have monster
			else
				if status == 2 or status == 3 then
					ratio = math.max(offtank, nontank)
				else -- you have monster as damage or healer
					ratio = player
				end -- damage or tank roles have the monster
			end
			-- threat ratio when monster switch target (melee 110% or 130% ranged to reclaim)
			if status == 1 or status == 2 or status == 4 or status == 6 then
				if tank < ratio then ratio = tank / ratio else ratio = 0 end
				if NPTacct.youTankCombat then ratio = 1 - ratio end
			else -- monster is tanked by someone via force
				if ratio < tank then ratio = ratio / tank else ratio = 0 end
			end -- monster is tanked by someone via threat
			
-- mikfhan: some cases give 0 > ratio > 1 and some of the cases might not be correct de/nom or color below
			ratio = math.min(math.max(0, ratio), 1)

			if not NPTacct.gradientColor then
				if ratio >= 0.5 and ratio < 1 and not NPTacct.youTankCombat
				and (status == 1 or status == 6 or status == 4 or status == 2)
				then -- clamp tanking by force to proper color if not fading gradient
					if NPT.playerRole == "TANK" and (status == 1 or status == 6)
					or NPT.playerRole ~= "TANK" and status == 2
					then
						ratio = 1
					else -- bad orange above better yellow below
						ratio = 0.5
					end
				else
					ratio = math.floor(ratio)
				end
			end
		end
	end
	if not status or not NPTacct.enableNoFight and NPT.thisUpdate ~= nil and status < 0 or not (NPTacct.enableOutside or fader) then
		resetFrame(plate) -- only recolor when situation was changed with gradient toward sibling color
-- mikfhan: for some reason 9.0.1 is sorting nameplates randomly from their unit, breaking the two check lines below:
--	elseif not NPT.threat[plate.namePlateUnitToken] or NPT.threat[plate.namePlateUnitToken].lastStatus ~= status or NPT.threat[plate.namePlateUnitToken].lastRatio ~= ratio then
--		resetFrame(plate)
	elseif NPTacct.addonsEnabled and unit and UnitCanAttack("player", unit) then
		color = NPTacct.hostilesColor -- color outside group (others for players or neutrals)
		if UnitIsPlayer(unit) then
			color = NPTacct.pvPlayerColor
		elseif UnitReaction(unit, "player") > 3 or UnitExists(unit .. "target") then
			color = NPTacct.neutralsColor
		end
		fader = color
		unit = ratio

		if not NPT.threat[plate.namePlateUnitToken] then
			NPT.threat[plate.namePlateUnitToken] = {
				["color"] = {r=0, g=0, b=0, a=1}
			}
			NPT.threat[plate.namePlateUnitToken].lastStatus = -1
			NPT.threat[plate.namePlateUnitToken].lastRatio = 0
		end

		if status > -1 and NPTacct.youTankCombat then -- color depending on threat or target situation odd/even
			if NPT.playerRole == "TANK" then
				if status == 0 then	-- others tanking by threat	orange to yellow
					color = 0
					if NPTacct.forcingUnique then fader = 1 else fader = 4 end
				elseif status == 1 then	-- others tanking by force	yellow to orange
					if NPTacct.forcingUnique then color = 1 else color = 4 end
					fader = 0
				elseif status == 2 then	-- you're tanking by force	gray to green
					color = 2
					fader = 3
				elseif status == 3 then	-- you're tanking by threat	green to gray
					color = 3
					fader = 2
				elseif status == 4 then	-- tanks tanking by force	yellow to gray
					color = 4
					if NPTacct.forcingUnique then fader = 5 else fader = 2 end
				elseif status == 5 then	-- tanks tanking by threat	gray to yellow
					if NPTacct.forcingUnique then color = 5 else color = 2 end
					fader = 4
				elseif status == 6 then	-- healer tanking by force	orange to red
					if NPTacct.forcingUnique then color = 6 else color = 0 end
					fader = 7
				elseif status == 7 then	-- healer tanking by threat	red to orange
					color = 7
					if NPTacct.forcingUnique then fader = 6 else fader = 0 end
				end
			elseif NPTacct.nonTankUnique then
				if status == 0 then	-- others tanking by threat	gray to yellow
					color = 0
					if NPTacct.forcingUnique then fader = 1 else fader = 2 end
				elseif status == 1 then	-- others tanking by force	yellow to gray
					if NPTacct.forcingUnique then color = 1 else color = 2 end
					fader = 0
				elseif status == 2 then	-- you're tanking by force	yellow to orange
					color = 2
					fader = 3
				elseif status == 3 then	-- you're tanking by threat	orange to yellow
					color = 3
					fader = 2
				elseif status == 4 then	-- tanks tanking by force	gray to green
					if NPTacct.forcingUnique then color = 4 else color = 0 end
					fader = 5
				elseif status == 5 then	-- tanks tanking by threat	green to gray
					color = 5
					if NPTacct.forcingUnique then fader = 4 else fader = 0 end
				elseif status == 6 then	-- healer tanking by force	orange to red
					if NPTacct.forcingUnique then color = 6 else color = 3 end
					fader = 7
				elseif status == 7 then	-- healer tanking by threat	red to orange
					color = 7
					if NPTacct.forcingUnique then fader = 6 else fader = 3 end
				end
			else
				if status == 0 then	-- others tanking by threat	gray to yellow
					color = 2
					if NPTacct.forcingUnique then fader = 1 else fader = 4 end
				elseif status == 1 then	-- others tanking by force	yellow to gray
					if NPTacct.forcingUnique then color = 1 else color = 4 end
					fader = 2
				elseif status == 2 then	-- you're tanking by force	yellow to orange
					color = 4
					fader = 0
				elseif status == 3 then	-- you're tanking by threat	orange to yellow
					color = 0
					fader = 4
				elseif status == 4 then	-- tanks tanking by force	gray to green
					if NPTacct.forcingUnique then color = 5 else color = 2 end
					fader = 3
				elseif status == 5 then	-- tanks tanking by threat	green to gray
					color = 3
					if NPTacct.forcingUnique then fader = 5 else fader = 2 end
				elseif status == 6 then	-- healer tanking by force	orange to red
					if NPTacct.forcingUnique then color = 6 else color = 0 end
					fader = 7
				elseif status == 7 then	-- healer tanking by threat	red to orange
					color = 7
					if NPTacct.forcingUnique then fader = 6 else fader = 0 end
				end
			end
			if NPT.playerRole == "TANK" or not NPTacct.nonTankUnique then
				color = NPTacct["youTank" .. color .. "color"]
				fader = NPTacct["youTank" .. fader .. "color"]
			else
				color = NPTacct["nonTank" .. color .. "color"]
				fader = NPTacct["nonTank" .. fader .. "color"]
			end
		elseif status > -1 then
			if NPT.playerRole == "TANK" then
				if status == 2 or status == 4		-- you or offtanks by force	yellow to orange
				or status == 3 or status == 5 then	-- you or offtanks by threat
					if ratio > 0.5 then
						color = 4
						fader = 0
						ratio = ratio - 0.5
					else				-- less than half caught up	green or gray
						if status == 2 or status == 3 then color = 3 else color = 2 end
						fader = 4
					end
					ratio = ratio * 2
				else					-- others by force/threat	red to orange
					color = 7
					fader = 0
				end
			else
				if status == 0 or status == 7 or status == 5		-- by threat	yellow to orange
				or status == 1 or status == 6 or status == 4 then	-- by force
					if ratio > 0.5 then
						color = 4
						fader = 0
						ratio = ratio - 0.5
					else				-- less than half caught up	green or gray
						if status == 5 or status == 4 then color = 3 else color = 2 end
						fader = 4
					end
					ratio = ratio * 2
				else					-- you tank by force/threat	red to orange
					color = 7
					fader = 0
				end
			end
			color = NPTacct["youTank" .. color .. "color"]
			fader = NPTacct["youTank" .. fader .. "color"]
		end
		NPT.threat[plate.namePlateUnitToken].color = gradient(color, fader, ratio)

--		if unit > 0 and unit ~= NPT.threat[plate.namePlateUnitToken].lastRatio
--		or status > -1 and status ~= NPT.threat[plate.namePlateUnitToken].lastStatus then
--			print(GetServerTime() .. " NPT status " .. status
--			.. " ratio " .. math.floor(unit * 100)
--			.. " r=" .. math.floor(255 * NPT.threat[plate.namePlateUnitToken].color.r)
--			.. " g=" .. math.floor(255 * NPT.threat[plate.namePlateUnitToken].color.g)
--			.. " b=" .. math.floor(255 * NPT.threat[plate.namePlateUnitToken].color.b))
--		end

		NPT.threat[plate.namePlateUnitToken].lastStatus = status
		NPT.threat[plate.namePlateUnitToken].lastRatio = unit

		updatePlateColor(plate, false)
	end
	return plate, status, tank, offtank, player, nontank, offheal
end
local function callback()
	if NPTacct.addonsEnabled and NPT.thisUpdate then
		NPT.thisUpdate = false
		local nameplates, key, plate = {}
		if InCombatLockdown() then
			NPT.thisUpdate = nil -- to force enable non combat colors while fighting
		end
		for key, plate in pairs(C_NamePlate.GetNamePlates()) do
			plate = {updateThreatColor(plate)}
			if not NPTacct.enableNoFight and NPT.thisUpdate ~= nil and (not plate[2] or plate[2] < 0) then
				table.insert(nameplates, plate) -- these may need recolor if group combat is discovered
			else
				NPT.thisUpdate = nil -- we discovered group combat but those ignored before need recoloring
			end
		end
		for key, plate in pairs(nameplates) do
			updateThreatColor(unpack(plate)) -- recolor those we ignored before group combat was discovered
		end
		NPT.thisUpdate = 0
	end
end

--NPT:RegisterEvent("UNIT_COMBAT")
--NPT:RegisterEvent("UNIT_ATTACK")
--NPT:RegisterEvent("UNIT_DEFENSE")
--NPT:RegisterEvent("PLAYER_REGEN_DISABLED")
--NPT:RegisterEvent("PLAYER_ENTER_COMBAT")
--NPT:RegisterEvent("PLAYER_LEAVE_COMBAT")
--NPT:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
NPT:RegisterEvent("ADDON_LOADED")
NPT:RegisterEvent("PLAYER_ENTERING_WORLD")
NPT:RegisterEvent("PLAYER_ROLES_ASSIGNED")
NPT:RegisterEvent("GROUP_ROSTER_UPDATE")
NPT:RegisterEvent("PET_DISMISS_START")
NPT:RegisterEvent("UNIT_PET")
if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then
	NPT:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
elseif WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
	NPT:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	NPT:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
	NPT:RegisterEvent("PLAYER_SOFT_FRIEND_CHANGED")
	NPT:RegisterEvent("PLAYER_SOFT_ENEMY_CHANGED")
end
NPT:RegisterEvent("NAME_PLATE_UNIT_ADDED")
NPT:RegisterEvent("PLAYER_TARGET_CHANGED")
NPT:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
NPT:RegisterEvent("UNIT_TARGET")
NPT:RegisterEvent("PLAYER_REGEN_ENABLED")
NPT:RegisterEvent("NAME_PLATE_UNIT_REMOVED")

NPT:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" and string.upper(arg1) == string.upper("NamePlatesThreat") then
		repeat
			NPT.addonIndex = NPT.addonIndex + 1
		until string.upper(_G.C_AddOns.GetAddOnInfo(NPT.addonIndex)) == string.upper(arg1)
		NPTacct = initVariables(NPTacct) -- import variables or reset to defaults
		NPTframe:Initialize()
		if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
			hooksecurefunc("CompactUnitFrame_UpdateHealthColor", function(frame)
				local plate = C_NamePlate.GetNamePlateForUnit(frame.unit)
				if plate and NPTacct.addonsEnabled and frame.unit and UnitCanAttack("player", frame.unit) then updatePlateColor(plate) end
			end) -- mikfhan: these are needed due to WoW retail healthbars marked dirty from multiple places for next frame reset so we must recolor posthook
			hooksecurefunc("CompactUnitFrame_UpdateHealthBorder", function(frame)
				local plate = C_NamePlate.GetNamePlateForUnit(frame.unit)
				if plate and NPTacct.addonsEnabled and frame.unit and UnitCanAttack("player", frame.unit) then updatePlateColor(plate) end
			end) -- https://github.com/tomrus88/BlizzardInterfaceCode/blob/24c0341aff3996fe55089e18b41e19bc40552c64/Interface/FrameXML/CompactUnitFrame.lua#L81
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_ROLES_ASSIGNED" or
		event == "GROUP_ROSTER_UPDATE" or event == "PET_DISMISS_START" or event == "UNIT_PET" or
		event == "PLAYER_SPECIALIZATION_CHANGED" then
		local key, plate
		for key, plate in pairs(C_NamePlate.GetNamePlates()) do
			resetFrame(plate)
		end
		NPT.threat = {}
		NPT.nonHeals = {}
		NPT.offTanks, NPT.playerRole, NPT.nonTanks, NPT.offHeals = getGroupRoles()
		C_Timer.NewTimer(0.1, callback)
	elseif event == "PLAYER_SOFT_INTERACT_CHANGED" or event == "PLAYER_SOFT_FRIEND_CHANGED" or
		event == "PLAYER_SOFT_ENEMY_CHANGED" or event == "NAME_PLATE_UNIT_ADDED" or
		event == "PLAYER_TARGET_CHANGED" or event == "UNIT_THREAT_SITUATION_UPDATE" or
		event == "UNIT_TARGET" or event == "PLAYER_REGEN_ENABLED" then
		if event == "PLAYER_REGEN_ENABLED" then -- keep trying until mobs back at spawn
			C_Timer.NewTimer(20.0, callback)
		else -- soft targets need a short delay for border
			C_Timer.NewTimer(0.1, callback)
		end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		local plate = C_NamePlate.GetNamePlateForUnit(arg1)
		if plate and plate.UnitFrame then
			resetFrame(plate)
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" and WOW_PROJECT_ID == WOW_PROJECT_CLASSIC and GetNumGroupMembers() > 0 then
		local timestamp, subevent, _, sourceGUID, _, sourceFlags, _, destGUID = CombatLogGetCurrentEventInfo()
		local COMBATLOG_FILTER_GROUPHEAL = bit.bor(
			COMBATLOG_OBJECT_AFFILIATION_MINE
		,	COMBATLOG_OBJECT_AFFILIATION_PARTY
		,	COMBATLOG_OBJECT_AFFILIATION_RAID
		,	COMBATLOG_OBJECT_REACTION_FRIENDLY
		,	COMBATLOG_OBJECT_CONTROL_PLAYER
		,	COMBATLOG_OBJECT_TYPE_PLAYER
		)
		if CombatLog_Object_IsA(sourceFlags, COMBATLOG_FILTER_GROUPHEAL) then
			--print(timestamp .. " " .. sourceGUID .. " " .. format("0x%X", sourceFlags))
			if subevent == "SPELL_HEAL" or subevent == "SPELL_PERIODIC_HEAL" then
				if sourceGUID ~= destGUID and string.sub(destGUID, 1, 6) == "Player" then
					NPT.nonHeals[sourceGUID] = timestamp
					if sourceGUID == UnitGUID("player") then
						if NPT.playerRole == "DAMAGER" then
							--print("player is now HEALER")
							NPT.playerRole = "HEALER"
						end
					else
						local key, unit
						for key, unit in pairs(NPT.nonTanks) do
							if sourceGUID == UnitGUID(unit) then
								--print(unit .. " is now HEALER")
								table.insert(NPT.offHeals, unit)
								table.remove(NPT.nonTanks, key)
								break
							end
						end
					end
				end
			elseif subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" then
				if NPT.nonHeals[sourceGUID] and NPT.nonHeals[sourceGUID] < timestamp - 60 then
					NPT.nonHeals[sourceGUID] = nil
					if sourceGUID == UnitGUID("player") then
						if NPT.playerRole == "HEALER" then
							--print("player is now DAMAGER")
							NPT.playerRole = "DAMAGER"
						end
					else
						local key, unit
						for key, unit in pairs(NPT.offHeals) do
							if sourceGUID == UnitGUID(unit) then
								--print(unit .. " is now DAMAGER")
								table.insert(NPT.nonTanks, unit)
								table.remove(NPT.offHeals, key)
								break
							end
						end
					end
				end
			end
		end
	end
end)
NPT:SetScript("OnUpdate", function(self, elapsed)
	if NPTacct.addonsEnabled and NPTacct.gradientColor and NPT.thisUpdate then
		NPT.thisUpdate = NPT.thisUpdate + elapsed
		if NPT.thisUpdate >= 1/NPTacct.gradientPrSec then
			callback()
		end
	end -- remember "/reload" for any script changes to take effect
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
	local red, green, blue, changed = self.color:GetVertexColor()
	changed = {}
	changed.r = math.floor(0.5+255*red)
	changed.g = math.floor(0.5+255*green)
	changed.b = math.floor(0.5+255*blue)
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
				ColorPickerFrame:SetupColorPickerAndShow(
				{
					r = red,
					g = green,
					b = blue,
					opacity = NPTframe.lastSwatch,
					hasOpacity = false,
					swatchFunc = NPTframe.OnColorSelect,
					cancelFunc = NPTframe.OnColorSelect,
					opacityFunc = nil
				})
				--ColorPickerFrame.previousValues = changed
				--ColorPickerFrame:SetColorRGB(r, g, b)
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
function NPTframe.OnColorSelect(previousValues)
	if not previousValues then
		previousValues = {}
		previousValues.r, previousValues.g, previousValues.b = ColorPickerFrame:GetColorRGB()
	end
	previousValues.r = math.floor(0.5+255*previousValues.r)
	previousValues.g = math.floor(0.5+255*previousValues.g)
	previousValues.b = math.floor(0.5+255*previousValues.b)
	--print(GetServerTime() .. " NPTframe.OnColorSelect(): " .. tostring(previousValues.r) .. " " .. tostring(previousValues.g) .. " " .. tostring(previousValues.b))
	ColorPickerFrame.opacity:GetScript("OnClick")(ColorPickerFrame.opacity, nil, nil, previousValues)
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
	if NPT.acct.colBorderOnly ~= NPTacct.colBorderOnly then
		NPT.playerRole = false
--		--print("newBorderOnly:" .. tostring(NPT.acct.colBorderOnly) .. " oldBorderOnly:" .. tostring(NPTacct.colBorderOnly))
	end -- above we flag old border coloring was inverted before resetting frames
	NPTacct = initVariables(NPT.acct) -- store panel fields into addon variables
	NPT:GetScript("OnEvent")(NPT, "PLAYER_ENTERING_WORLD")
end
function NPTframe.cancel()
	NPT.acct = initVariables(NPTacct) -- restore panel fields from addon variables
end
function NPTframe.default()
	NPT.acct = initVariables()
end
function NPTframe.refresh() -- called on panel shown or after default was accepted
	--print(GetServerTime() .. " NPTframe.refresh(): Begin")
	NPTframe.addonsEnabled:GetScript("OnClick")(NPTframe.addonsEnabled, nil, nil, NPT.acct.addonsEnabled, true)
	NPTframe.enableNoFight:GetScript("OnClick")(NPTframe.enableNoFight, nil, nil, NPT.acct.enableNoFight)
	NPTframe.enableOutside:GetScript("OnClick")(NPTframe.enableOutside, nil, nil, NPT.acct.enableOutside)
	NPTframe.enablePlayers:GetScript("OnClick")(NPTframe.enablePlayers, nil, nil, NPT.acct.enablePlayers)
	NPTframe.neutralsColor:GetScript("OnClick")(NPTframe.neutralsColor, nil, nil, NPT.acct.neutralsColor)
	NPTframe.hostilesColor:GetScript("OnClick")(NPTframe.hostilesColor, nil, nil, NPT.acct.hostilesColor)
	NPTframe.pvPlayerColor:GetScript("OnClick")(NPTframe.pvPlayerColor, nil, nil, NPT.acct.pvPlayerColor)

	NPTframe.gradientColor:GetScript("OnClick")(NPTframe.gradientColor, nil, nil, NPT.acct.gradientColor)
	NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, NPT.acct.gradientPrSec)
	NPTframe.colBorderOnly:GetScript("OnClick")(NPTframe.colBorderOnly, nil, nil, NPT.acct.colBorderOnly)
	NPTframe.showPetThreat:GetScript("OnClick")(NPTframe.showPetThreat, nil, nil, NPT.acct.showPetThreat)

	NPTframe.youTankCombat:GetScript("OnClick")(NPTframe.youTankCombat, nil, nil, NPT.acct.youTankCombat)
	NPTframe.youTank7color:GetScript("OnClick")(NPTframe.youTank7color, nil, nil, NPT.acct.youTank7color)
	NPTframe.youTank0color:GetScript("OnClick")(NPTframe.youTank0color, nil, nil, NPT.acct.youTank0color)
	NPTframe.youTank4color:GetScript("OnClick")(NPTframe.youTank4color, nil, nil, NPT.acct.youTank4color)
	NPTframe.youTank2color:GetScript("OnClick")(NPTframe.youTank2color, nil, nil, NPT.acct.youTank2color)
	NPTframe.youTank3color:GetScript("OnClick")(NPTframe.youTank3color, nil, nil, NPT.acct.youTank3color)

	NPTframe.forcingUnique:GetScript("OnClick")(NPTframe.forcingUnique, nil, nil, NPT.acct.forcingUnique)
	NPTframe.youTank6color:GetScript("OnClick")(NPTframe.youTank6color, nil, nil, NPT.acct.youTank6color)
	NPTframe.youTank1color:GetScript("OnClick")(NPTframe.youTank1color, nil, nil, NPT.acct.youTank1color)
	NPTframe.youTank5color:GetScript("OnClick")(NPTframe.youTank5color, nil, nil, NPT.acct.youTank5color)

	NPTframe.nonTankUnique:GetScript("OnClick")(NPTframe.nonTankUnique, nil, nil, NPT.acct.nonTankUnique)
	NPTframe.nonTank7color:GetScript("OnClick")(NPTframe.nonTank7color, nil, nil, NPT.acct.nonTank7color)
	NPTframe.nonTank3color:GetScript("OnClick")(NPTframe.nonTank3color, nil, nil, NPT.acct.nonTank3color)
	NPTframe.nonTank2color:GetScript("OnClick")(NPTframe.nonTank2color, nil, nil, NPT.acct.nonTank2color)
	NPTframe.nonTank0color:GetScript("OnClick")(NPTframe.nonTank0color, nil, nil, NPT.acct.nonTank0color)
	NPTframe.nonTank5color:GetScript("OnClick")(NPTframe.nonTank5color, nil, nil, NPT.acct.nonTank5color)

	NPTframe.nonTank6color:GetScript("OnClick")(NPTframe.nonTank6color, nil, nil, NPT.acct.nonTank6color)
	NPTframe.nonTank1color:GetScript("OnClick")(NPTframe.nonTank1color, nil, nil, NPT.acct.nonTank1color)
	NPTframe.nonTank4color:GetScript("OnClick")(NPTframe.nonTank4color, nil, nil, NPT.acct.nonTank4color)
	--print(GetServerTime() .. " NPTframe.refresh(): Finish")
end
function NPTframe.OnCommit()
	--print(GetServerTime() .. " NPTframe.OnCommit(): Begin")
	NPTframe.okay()
end
function NPTframe.OnDefault()
	--print(GetServerTime() .. " NPTframe.OnDefault(): Begin")
	NPTframe.default()
end
function NPTframe.OnRefresh()
	--print(GetServerTime() .. " NPTframe.OnRefresh(): Begin")
	NPTframe.refresh()
end
function NPTframe:Initialize()
	self:cancel() -- simulate options cancel so panel variables are reset
	self.name = _G.C_AddOns.GetAddOnMetadata(NPT.addonIndex, "Title")

	self.bigTitle = self:CreateFontString("bigTitle", "ARTWORK", "GameFontNormalLarge")
	self.bigTitle:SetPoint("LEFT", self, "TOPLEFT", 16, -24)
	self.bigTitle:SetPoint("RIGHT", self, "TOPRIGHT", -32, -24)
	self.bigTitle:SetJustifyH("LEFT")
	self.bigTitle:SetText(_G.C_AddOns.GetAddOnMetadata(NPT.addonIndex, "Version") .. "-release by " .. _G.C_AddOns.GetAddOnMetadata(NPT.addonIndex, "Author"))
	self.bigTitle:SetHeight(self.bigTitle:GetStringHeight() * 1)

	self.subTitle = self:CreateFontString("subTitle", "ARTWORK", "GameFontHighlightSmall")
	self.subTitle:SetPoint("LEFT", self, "TOPLEFT", 16, -50)
	self.subTitle:SetPoint("RIGHT", self, "TOPRIGHT", -32, -50)
	self.subTitle:SetJustifyH("LEFT")

--	_, _, _, self.colBorderOnly = GetBuildInfo()
--	if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC or self.colBorderOnly >= 11404 then
		self.addonDefault = CreateFrame("Button", "addonDefault", self, "UIPanelButtonTemplate")
		self.addonDefault:SetPoint("RIGHT", self, "TOPRIGHT", -32, -24)
		self.addonDefault:SetText("Defaults")
		self.addonDefault:SetWidth(100)
		self.addonDefault:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		self.addonDefault:SetScript("OnClick", function(self, button, down)
			if button == "RightButton" then
				NPTframe.cancel()
			else
				NPTframe.default()
			end
			NPTframe.refresh()
		end)
		self.subTitle:SetText(_G.C_AddOns.GetAddOnMetadata(NPT.addonIndex, "Notes") .. " Press Escape, X or Close to keep unsaved AddOn changes in yellow below, or click Defaults to reset AddOn options (right-click Defaults instead to only discard yellow unsaved changes).")
--	else
--		self.subTitle:SetText(_G.C_AddOns.GetAddOnMetadata(NPT.addonIndex, "Notes") .. " Press Okay to keep unsaved AddOn changes in yellow below, press Escape or Cancel to discard unsaved changes, or click Defaults > These Settings to reset AddOn options.")
--	end
	self.subTitle:SetHeight(self.subTitle:GetStringHeight() * 2)

	self.addonsEnabled = self:CheckButtonCreate("addonsEnabled", "Color Non-Friendly Nameplates", "Enable for AddOn to function.", 1)
	self.addonsEnabled:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.enableNoFight:GetScript("OnClick")(NPTframe.enableNoFight, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.enableOutside:GetScript("OnClick")(NPTframe.enableOutside, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.enablePlayers:GetScript("OnClick")(NPTframe.enablePlayers, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.hostilesColor:GetScript("OnClick")(NPTframe.hostilesColor, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.neutralsColor:GetScript("OnClick")(NPTframe.neutralsColor, nil, nil, nil, NPT.acct.addonsEnabled)

		NPTframe.gradientColor:GetScript("OnClick")(NPTframe.gradientColor, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.colBorderOnly:GetScript("OnClick")(NPTframe.colBorderOnly, nil, nil, nil, NPT.acct.addonsEnabled and WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
		NPTframe.showPetThreat:GetScript("OnClick")(NPTframe.showPetThreat, nil, nil, nil, NPT.acct.addonsEnabled)

		NPTframe.youTankCombat:GetScript("OnClick")(NPTframe.youTankCombat, nil, nil, nil, NPT.acct.addonsEnabled)
		NPTframe.forcingUnique:GetScript("OnClick")(NPTframe.forcingUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.nonTankUnique:GetScript("OnClick")(NPTframe.nonTankUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.nonTankForced:GetScript("OnClick")(NPTframe.nonTankForced, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)

	self.colBorderOnly = self:CheckButtonCreate("colBorderOnly", "Color Nameplate Border Only", "Enable coloring only the border instead of the whole nameplate.", 1, 1)
	self.colBorderOnly:SetScript("OnClick", NPTframe.CheckButtonPostClick)

	self.showPetThreat = self:CheckButtonCreate("showPetThreat", "Color Group Pets as Tanks", "Enable group pets as secondary tanks when coloring nameplates instead of using role from owner.", 1, 2)
	self.showPetThreat:SetScript("OnClick", NPTframe.CheckButtonPostClick)

	self.enableOutside = self:CheckButtonCreate("enableOutside", "Color Out of Dungeons", "Enable coloring nameplates outside PvE instanced zones.", 1, 3)
	self.enableOutside:SetScript("OnClick", NPTframe.CheckButtonPostClick)

	self.gradientColor, self.gradientPrSec = self:CheckSliderCreate("gradientColor", "Color Gradient Updates Per Second", "Enable fading of nameplates between high and low colors when coloring them by threat.", "gradientPrSec", 1, 9, 6, true)
	self.gradientColor:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.gradientPrSec:GetScript("OnValueChanged")(NPTframe.gradientPrSec, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.gradientColor)
	--	NPTframe.youTankCombat:GetScript("OnClick")(NPTframe.youTankCombat, nil, nil, NPT.acct.gradientColor, NPT.acct.addonsEnabled)
	end)
	self.gradientPrSec:SetScript("OnValueChanged", NPTframe.SliderOnValueChanged)

	self.enableNoFight = self:CheckButtonCreate("enableNoFight", "Color Out of Combat", "Enable coloring nameplates when group is not in combat.", 4, nil, false)
	self.enableNoFight:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.hostilesColor:GetScript("OnClick")(NPTframe.hostilesColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enableNoFight)
		NPTframe.neutralsColor:GetScript("OnClick")(NPTframe.neutralsColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enableNoFight)
	end)
	self.hostilesColor = self:ColorSwatchCreate("hostilesColor", "Hostile is Out of Combat", "", 4, 1, false)
	self.hostilesColor:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.neutralsColor = self:ColorSwatchCreate("neutralsColor", "Neutral is Out of Combat", "", 4, 2, false)
	self.neutralsColor:SetScript("OnClick", NPTframe.ColorSwatchPostClick)

	self.enablePlayers = self:CheckButtonCreate("enablePlayers", "Color Player Characters", "Enable coloring nameplates of PvP flagged enemy players.", 6, nil, false)
	self.enablePlayers:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.pvPlayerColor:GetScript("OnClick")(NPTframe.pvPlayerColor, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.enablePlayers)
	end)
	self.pvPlayerColor = self:ColorSwatchCreate("pvPlayerColor", "Player is Out of Combat", "", 6, 1, false)
	self.pvPlayerColor:SetScript("OnClick", NPTframe.ColorSwatchPostClick)

	self.youTankCombat = self:CheckButtonCreate("youTankCombat", "Color Nameplates by Role", "Enable coloring nameplates as below by group role currently tanking, instead of just reusing colors below from bad to good.", 8)
	self.youTankCombat:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.youTank7color:GetScript("OnClick")(NPTframe.youTank7color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank0color:GetScript("OnClick")(NPTframe.youTank0color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank4color:GetScript("OnClick")(NPTframe.youTank4color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank2color:GetScript("OnClick")(NPTframe.youTank2color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.youTank3color:GetScript("OnClick")(NPTframe.youTank3color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.forcingUnique:GetScript("OnClick")(NPTframe.forcingUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
		NPTframe.nonTankUnique:GetScript("OnClick")(NPTframe.nonTankUnique, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	--	NPTframe.gradientColor:GetScript("OnClick")(NPTframe.gradientColor, nil, nil, NPT.acct.youTankCombat, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)
	self.youTank7color = self:ColorSwatchCreate("youTank7color", "Healers have High Threat", "", 8, 1)
	self.youTank7color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.youTank0color = self:ColorSwatchCreate("youTank0color", "Damage has High Threat", "", 8, 2)
	self.youTank0color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.youTank4color = self:ColorSwatchCreate("youTank4color", "Tanks have Low Threat", "", 8, 3)
	self.youTank4color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.youTank2color = self:ColorSwatchCreate("youTank2color", "You have the Low Threat", "", 8, 4)
	self.youTank2color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.youTank3color = self:ColorSwatchCreate("youTank3color", "You have the High Threat", "", 8, 5)
	self.youTank3color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)

	self.forcingUnique = self:CheckButtonCreate("forcingUnique", "Unique Colors In-Between", "Enable colors below instead of reusing colors above when close to a threat situation change.", 12)
	self.forcingUnique:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.youTank6color:GetScript("OnClick")(NPTframe.youTank6color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique)
		NPTframe.youTank1color:GetScript("OnClick")(NPTframe.youTank1color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique)
		NPTframe.youTank5color:GetScript("OnClick")(NPTframe.youTank5color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique)
		NPTframe.nonTankForced:GetScript("OnClick")(NPTframe.nonTankForced, nil, nil, NPT.acct.forcingUnique and NPT.acct.nonTankUnique, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)
	self.youTank6color = self:ColorSwatchCreate("youTank6color", "Healers have Low Threat", "", 12, 1)
	self.youTank6color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.youTank1color = self:ColorSwatchCreate("youTank1color", "Damage has Low Threat", "", 12, 2)
	self.youTank1color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.youTank5color = self:ColorSwatchCreate("youTank5color", "Tanks have High Threat", "", 12, 3)
	self.youTank5color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)

	self.nonTankUnique = self:CheckButtonCreate("nonTankUnique", "Unique Colors as Non-Tank", "Enable colors below in a non-tank role or solo instead of reusing the color to its left.", 8, nil, true)
	self.nonTankUnique:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		NPTframe.nonTank7color:GetScript("OnClick")(NPTframe.nonTank7color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank3color:GetScript("OnClick")(NPTframe.nonTank3color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank2color:GetScript("OnClick")(NPTframe.nonTank2color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank0color:GetScript("OnClick")(NPTframe.nonTank0color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTank5color:GetScript("OnClick")(NPTframe.nonTank5color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.nonTankUnique)
		NPTframe.nonTankForced:GetScript("OnClick")(NPTframe.nonTankForced, nil, nil, NPT.acct.forcingUnique and NPT.acct.nonTankUnique, NPT.acct.addonsEnabled and NPT.acct.youTankCombat)
	end)
	self.nonTank7color = self:ColorSwatchCreate("nonTank7color", "Healers have High Threat", "", 8, 1, true)
	self.nonTank7color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.nonTank3color = self:ColorSwatchCreate("nonTank3color", "You have the High Threat", "", 8, 2, true)
	self.nonTank3color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.nonTank2color = self:ColorSwatchCreate("nonTank2color", "You have the Low Threat", "", 8, 3, true)
	self.nonTank2color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.nonTank0color = self:ColorSwatchCreate("nonTank0color", "Damage has High Threat", "", 8, 4, true)
	self.nonTank0color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.nonTank5color = self:ColorSwatchCreate("nonTank5color", "Tanks have High Threat", "", 8, 5, true)
	self.nonTank5color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)

	self.nonTankForced = self:CheckButtonCreate("nonTankForced", "Unique Colors In-Between", "Enable colors below instead of reusing colors above when close to a threat situation change.", 12, nil, true)
	self.nonTankForced:SetScript("OnClick", function(self, button, down, value, enable)
		NPTframe.CheckButtonPostClick(self, button, down, value, enable)
		if value == nil and enable == nil then
			value = self:GetChecked()
			NPTframe.forcingUnique:GetScript("OnClick")(NPTframe.forcingUnique, nil, nil, value)
			NPTframe.nonTankUnique:GetScript("OnClick")(NPTframe.nonTankUnique, nil, nil, value)
		end
		if (NPT.acct.forcingUnique and NPT.acct.nonTankUnique) ~= (NPTacct.forcingUnique and NPTacct.nonTankUnique) then
			NPTframe.nonTankForced.text:SetFontObject("GameFontNormal")
		elseif self:IsEnabled() then
			NPTframe.nonTankForced.text:SetFontObject("GameFontHighlight")
		else
			NPTframe.nonTankForced.text:SetFontObject("GameFontDisable")
		end
		NPTframe.nonTank6color:GetScript("OnClick")(NPTframe.nonTank6color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
		NPTframe.nonTank1color:GetScript("OnClick")(NPTframe.nonTank1color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
		NPTframe.nonTank4color:GetScript("OnClick")(NPTframe.nonTank4color, nil, nil, nil, NPT.acct.addonsEnabled and NPT.acct.youTankCombat and NPT.acct.forcingUnique and NPT.acct.nonTankUnique)
	end)
	self.nonTank6color = self:ColorSwatchCreate("nonTank6color", "Healers have Low Threat", "", 12, 1, true)
	self.nonTank6color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.nonTank1color = self:ColorSwatchCreate("nonTank1color", "Damage has Low Threat", "", 12, 2, true)
	self.nonTank1color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)
	self.nonTank4color = self:ColorSwatchCreate("nonTank4color", "Tanks have Low Threat", "", 12, 3, true)
	self.nonTank4color:SetScript("OnClick", NPTframe.ColorSwatchPostClick)

	--InterfaceOptions_AddCategory(self)
	Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(self, self.name))
end
function NPTframe:ColorSwatchCreate(newName, newText, toolText, mainRow, subRow, columnTwo)
	local newObject = CreateFrame("CheckButton", newName, self, BackdropTemplateMixin and "UICheckButtonTemplate,BackdropTemplate" or "UICheckButtonTemplate")
	newObject:SetSize(26, 26)
	newObject.text = _G[newObject:GetName() .. "Text"]
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
	local newObject = CreateFrame("CheckButton", newName, self, "UICheckButtonTemplate")
	newObject:SetSize(26, 26)
	newObject.text = _G[newObject:GetName() .. "Text"]
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
	local newCheck = CreateFrame("CheckButton", newCheck, self, "UICheckButtonTemplate")
	local newSlider = CreateFrame("Slider", newSlider, self, "UISliderTemplate")
-- mikfhan: below is needed since we inherited from UISliderTemplateWithLabels now deprecated
	newSlider:SetSize(144, 17)
	newSlider.text = newSlider:CreateFontString(newSlider:GetName() .. "Text", "ARTWORK", "GameFontHighlight")
	newSlider.text:SetParentKey("Text")
	newSlider.text:SetPoint("BOTTOM", newSlider, "TOP")
	newSlider.low = newSlider:CreateFontString(newSlider:GetName() .. "Low", "ARTWORK", "GameFontHighlightSmall")
	newSlider.low:SetParentKey("Low")
	newSlider.low:SetText("LOW")
	newSlider.low:SetPoint("TOPLEFT", newSlider, "BOTTOMLEFT", -4, 3)
	newSlider.high = newSlider:CreateFontString(newSlider:GetName() .. "High", "ARTWORK", "GameFontHighlightSmall")
	newSlider.high:SetParentKey("High")
	newSlider.high:SetText("HIGH")
	newSlider.high:SetPoint("TOPRIGHT", newSlider, "BOTTOMRIGHT", 4, 3)
	newCheck:SetSize(26, 26)
-- mikfhan: and newCheck:SetSize above as well from deprecated OptionsBaseCheckButtonTemplate
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