local AB = { }
local frame = CreateFrame('Button', _, UIParent)
--frame position
frame:SetWidth(100)
frame:SetHeight(100)
frame:SetPoint('CENTER', UIParent, 'CENTER')

--frame position saved between sessions
--this breaks if the game is loaded without the addon, then again with it
--needs to be reworked into a per character saved variable
frame:SetMovable(true)
frame:SetUserPlaced(true)
frame:EnableMouse(false)
frame:SetScript('OnDragStart', frame.StartMoving)
frame:SetScript('OnDragStop', frame.StopMovingOrSizing)

--frame text setup
frame.text = frame:CreateFontString('frame_text', 'OVERLAY', 'GameFontNormalLarge')
frame.text:SetPoint('CENTER', 0, -10)
frame.text:SetText('Test')

--extra text setup
frame.stats = frame:CreateFontString('frame_stats', 'OVERLAY', 'GameFontNormalLarge')
frame.stats:SetPoint('TOP', 0, 0)
frame.stats:SetText('Test stats')

--extra text setup
frame.buffs = frame:CreateFontString('frame_stats', 'OVERLAY', 'GameFontNormalLarge')
frame.buffs:SetPoint('RIGHT', 100, 200)
frame.buffs:SetText('Test buffs')

--frame background
frame.bg = frame:CreateTexture('frame_bg', 'BACKGROUND')
frame.bg:SetPoint('CENTER',0,0)
frame.bg:SetWidth(100)
frame.bg:SetHeight(100)
frame.bg:SetTexture('Interface\\DialogFrame\\UI-DialogBox-Background')
--frame.bg:SetTexture(0.0, 0.0, 1.0, 0.5)

--display the frame
--frame:Show()
frame:Hide()

frame:RegisterEvent('PLAYER_LOGIN')
--frame:RegisterEvent('PLAYER_LOGOUT')
--frame:RegisterEvent('ADDON_LOADED')

--get AB ready to check the player on talent change
function AB:StartUp()
	frame:RegisterEvent('CHARACTER_POINTS_CHANGED')
	frame:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
	frame:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')
--NOTE: On a fresh login, after PLAYER_LOGIN the game still does not know talents, PLAYER_ALIVE is needed for that
	frame:RegisterEvent('PLAYER_ALIVE')
end

--get AB ready on login
function AB:PLAYER_LOGIN()
	AB:StartUp()
	print('AB loaded')
end

local buffList = {
	ArcaneFocus = {
		--talent 1,2
		name = 'Arcane Focus',
		active = true,
		type = 'talent',
		--cost = -1/2/3,
	},
	NetherwindPresence = {
		--talent 1,28
		name = 'Netherwind Presence',
		active = true,
		type = 'talent',
		--haste = 2/4/6,
	},
	Precision = {
		--talent 3,6
		name = 'Precision',
		active = true,
		type = 'talent',
		--cost = -1/2/3
	},
	HastePCT1 = {
		name = 'Improved Moonkin Form', --shouldn't stack with Swift Retribution
		active = false,
		type = 'static',
		haste = 3, --1/2/3 from rank
	},
	HastePCT2 = {
		name = 'Swift Retribution', --shouldn't stack with Improved Moonkin Form
		active = false,
		type = 'static',
		haste = 3, --1/2/3 from rank
	},
	WrathOfAir = {
		name = 'Wrath of Air Totem',
		active = false,
		type = 'static',
		haste = 5,
	},
	BL = {
		name = 'Bloodlust', --Heroism
		active = false,
		type = 'temporary',
		haste = 30,
		maxDuration = 40,
	},
	PowerInfusion = {
		name = 'Power Infusion',
		active = false,
		type = 'temporary',
		haste = 20,
		cost = -20,
		maxDuration = 15,
	},
	--Replenishment = {},
	--Innervate = {},
	--Hymn of Hope = {},
	ArcanePower = {
		name = 'Arcane Power',
		active = false,
		type = 'temporary',
		cost = 20,
		maxDuration = 15, --18 with glyph
		maxCooldown = 84, --120 -15/30% talento 1,24 
	},
	IcyVeins = {
		name = 'Icy Veins',
		active = false,
		type = 'temporary',
		haste = 20,
		maxDuration = 20,
		maxCooldown = 144, --180 -7/14/20% talento 3,3
	},
	Berserking = {
		--only if troll
		name = 'Berserking',
		active = false,
		type = 'temporary',
		haste = 20,
		maxDuration = 10,
		maxCooldown = 180,
	},
	EngiGloves = {
		name = 'Hyperspeed Accelerators',
		active = false,
		type = 'temporary',
		rating = 340,
		maxDuration = 12,
		maxCooldown = 60,
	},
	--]]
	--[[
	PotionSpeed = {
		name = 'Potion of Speed',
		active = false,
		type = temporary,
		hasterating = 500,
		maxDuration = 15,
	},
	]]--
	--[[
	HasteRating = {
		name = 'Haste Rating',
		active = true,
		hasterating = 0,
	},
	]]--
	--[[
	ManaGem = {
		name = 'Mana Sapphire',
		active = true,
		type = 'item',
		???
	},
	--]]
	--[[
	Evocation = {
		???
	},
	--]]
}

local ComputeManaCost = function(cost, stacks, buffs)
	local x = cost * (1 + 1.75 * stacks)
	for k, buff in pairs(buffs) do
		if buff.active and buff.cost then
			x = x * (1 + buff.cost / 100)
		end
	end
	return x
end

local ComputeCastTime = function(cast, buffs)
	local x = cast
	for k, buff in pairs(buffs) do
		if buff.active and buff.haste then
			x = x / (1 + buff.haste / 100)
		end
	end
	x = x / (1 + GetCombatRatingBonus(20) / 100)
	return x
end

local UpdateBuff = function(buff, cast)
	if buff.active then
		buff.remainingDuration = math.max(buff.remainingDuration - cast, 0)
	end
	if buff.remainingDuration == 0 then
		buff.active = false
	end
	if buff.maxCooldown then
		buff.remainingCooldown = math.max(buff.remainingCooldown - cast, 0)
	end
end

--check class and talents to make sure the player is an Arcane Mage
function AB:CheckCharacter()
	print('checking character')
	--if not, unregister everything except what's necessary to check again
	if select(2, UnitClass('player')) ~= 'MAGE' or select(5, GetTalentInfo(1, 21)) == 0 then
		print('Wrong class/spec detected')
		frame:UnregisterAllEvents()
		AB:StartUp()
	else
	--if yes, register entering/leaving combat
	--also, check talents affecting spell cost / cast time
		print('Arcane Mage detected')
		frame:RegisterEvent('PLAYER_REGEN_ENABLED')
		frame:RegisterEvent('PLAYER_REGEN_DISABLED')
		--remake this using the talent type maybe?
		buffList.ArcaneFocus.cost = -select(5, GetTalentInfo(1, 2))
		buffList.NetherwindPresence.haste = 2 * select(5, GetTalentInfo(1, 28))
		buffList.Precision.cost = -select(5, GetTalentInfo(3, 6))
		if not IsSpellKnown(26297) then
			buffList.Berserking = nil
		end
		local gloves = GetInventoryItemLink("player", 10)
		--unlike racial, gloves enchant can be added/removed on the fly
		if (not gloves) or select(3, strsplit(":", gloves)) ~= '3604' then
			buffList.EngiGloves = nil
		else
			buffList.EngiGloves = {
				name = 'Hyperspeed Accelerators',
				active = false,
				type = 'temporary',
				rating = 340,
				maxDuration = 12,
				maxCooldown = 60,
			},
		end
	end
end

--slash command to manually turn AB on/off
SLASH_AB1 = "/ab"
SlashCmdList["AB"] = function(msg)
	if msg == 'on' then
		print('AB on')
		AB:StartUp()
		AB:CheckCharacter()
	elseif msg == 'off' then
		print('AB off')
		frame:UnregisterAllEvents()
		frame:Hide()
	elseif msg == 'lock' then
		--frame movable
		--maybe add a slash command to make it (un)movable
		if not UnitAffectingCombat('player') then
			if frame:IsMouseEnabled() then
				frame:Hide()
				frame:EnableMouse(false)
				frame:RegisterForDrag()
			else
				frame:Show()
				frame:EnableMouse(true)
				frame:RegisterForDrag('LeftButton')
			end
		else
			print('AB cannot be moved while in combat')
		end
	else	
		print('Use: /ab on/off/lock')
	end
end

local timeToDie

local timeSinceLastUpdate = 0
local update_interval = 0.05

local UpdatePrediction = function(self, elapsed)
	timeSinceLastUpdate = timeSinceLastUpdate + elapsed

	while timeSinceLastUpdate > update_interval do

		local baseManaCost, manaCost = 142.45
		-- 2035 base mana -> 142.45 base mana cost of AB
		local baseCastTime, castTime = 2.5
		local time, stacks, manaCurrent, manaMax, manaRegen, manaGain = 0, 0

		manaCurrent = UnitMana('player')
		manaMax = UnitManaMax('player')
		manaRegen = select(2, GetManaRegen())
		stacks = select(4, UnitDebuff('player', 'Arcane Blast')) or 0

		--check external buffs and set duration if found
		for k, buff in pairs(buffList) do
			if buff.type == 'temporary' then
				local name, _, _, _, _, _, expirationTime = UnitBuff('player', buff.name)
				if name then
					buff.active = true
					buff.remainingDuration = expirationTime - GetTime()
					--print(name)
				else
					buff.active = false
					buff.remainingDuration = nil
				end
				if buff.maxCooldown then
					local activationTime, spellCooldown = GetSpellCooldown(buff.name)
					buff.remainingCooldown = activationTime == 0 and 0 or (activationTime + spellCooldown - GetTime())
					--print(buff.remainingCooldown)
				end
			end
		end

		local currentbuffs = ''
		for k, buff in pairs(buffList) do
			if buff.active == true then
				currentbuffs = currentbuffs .. buff.name .. '\n'
			end
		end
		frame.buffs:SetText(currentbuffs)

		local spellCastName, _, _, _, _, endTime = UnitCastingInfo('player')

		time = spellCastName and endTime / 1000 - GetTime() or 0

		if time > 0 then
			for k, buff in pairs(buffList) do
				if buff.type == 'temporary' then
					UpdateBuff(buff, time)
				end
			end
			local tempCost = select(4, GetSpellInfo(spellCastName))
			manaCurrent = math.min(manaCurrent + manaRegen * time, manaMax) - tempCost
			if spellCastName == 'Arcane Blast' then
				stacks = math.min(stacks + 1, 4)
			end
		end

		manaCost = ComputeManaCost(baseManaCost, stacks, buffList)
		castTime = ComputeCastTime(baseCastTime, buffList)
		frame.stats:SetText('Cast time: ' .. math.floor(castTime * 100) / 100 .. '\n' .. 'Mana Cost: ' .. math.floor(manaCost * 100) / 100)	

		count = 0
		--loop
		while true do

			--if any self-buff is available, activate it and start cooldown (except mana gem/evocation)
			--need to implement a logic not to overlap haste cooldowns (berserking, icy veins, engi gloves)
			for k, buff in pairs(buffList) do
				if type == 'temporary' and buff.remainingCooldown == 0 then
					buff.active = true
					buff.remainingDuration = buff.maxDuration
				end
			end

			--compute mana cost
			manaCost = ComputeManaCost(baseManaCost, stacks, buffList)
			--compute cast time
			castTime = ComputeCastTime(baseCastTime, buffList)
			--compute mana regen during cast time
			manaGain = manaRegen * castTime

			--if manaCurrent + manaGain + [manaGem] < manaMax then
				--use managem
				--manaCurrent = manaCurrent + manaGem
			--end

			--break when you you can't cast anymore
			if manaCost > manaCurrent then
				break
			end

			--update after casting
			time = time + castTime
			count = count + 1
			stacks = math.min(stacks + 1, 4)
			manaCurrent = math.min(manaCurrent + manaGain, manaMax) - manaCost
			for k, buff in pairs(buffList) do
				if buff.type == 'temporary' then
					UpdateBuff(buff, castTime)
				end
			end
		end

		--display format (s or m:ss)
		if time < 60 then
			frame.text:SetText('Time left: ' .. string.format("%.1f", time) .. '\n' .. 'Casts left: ' .. count)
		else
			frame.text:SetText('Time left: ' .. string.format("%d:%0.1f", time / 60, time % 60) .. '\n' .. 'Casts left: ' .. count)
		end

		--change colour depending on a TimeToDie feed, if available
		if timeToDie and time > timeToDie then
			frame.text:SetTextColor(0, 1, 0, 1)
		else
			frame.text:SetTextColor(1, 0, 0, 1)
		end

		timeSinceLastUpdate = timeSinceLastUpdate - update_interval
	end
end

function AB:PLAYER_REGEN_DISABLED()
	print('Entering combat')
	for k, buff in pairs(buffList) do
		if buff.type == 'static' then
			local name, rank = UnitBuff('player', buff.name)
			if name then
				buff.active = true
				--buffList.buff.rank
				--should find a way to include cases of non-max rank, even if dumb
			else
				buff.active = false
			end
		end
	end
	frame:RegisterEvent('CHAT_MSG_ADDON')
	frame:SetScript('OnUpdate', UpdatePrediction)
	frame:Show()
end

function AB:PLAYER_REGEN_ENABLED()
	print('Leaving combat')
	frame:UnregisterEvent('CHAT_MSG_ADDON')
	frame:SetScript('OnUpdate', nil);
	frame:Hide()
	timeSinceLastUpdate = 0
	timeToDie = nil
end

function AB:CHAT_MSG_ADDON(...)
	local prefix, message, channel, source = ...
	print(prefix)
	if prefix == 'Manitary - ABS' and source == UnitName('player') then
		timeToDie = tonumber(message)
		print(timeToDie)
	end
end

--general event handler
frame:SetScript('OnEvent', function(self, event, ...)
	if AB[event] then 
		print(event)
		AB[event](AB, ...)
	end
	if event == 'CHARACTER_POINTS_CHANGED' or event == 'ACTIVE_TALENT_GROUP_CHANGED' or event == 'PLAYER_ALIVE' or event == 'PLAYER_LOGIN' or event == 'PLAYER_EQUIPMENT_CHANGED' then
		AB:CheckCharacter()
	end
end)
