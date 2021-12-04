local AB = { }
local frame = CreateFrame('Button', _, UIParent)
--frame position
frame:SetWidth(100)
frame:SetHeight(100)
frame:SetPoint('CENTER', UIParent, 'CENTER')

--frame movable
--maybe add a slash command to make it (un)movable
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag('LeftButton')
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
--BagBuddy.portrait:SetTexture(0.0, 0.0, 1.0, 0.5)

--display the frame
--maybe add a slash command to make it (not) visible
frame:Show()

---
frame:RegisterEvent('PLAYER_LOGIN')

--get AB ready to check the player on talent change
function AB:StartUp()
	frame:RegisterEvent('CHARACTER_POINTS_CHANGED')
	frame:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
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
	}
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
		buffList.ArcaneFocus.cost = -select(5, GetTalentInfo(1, 2))
		buffList.NetherwindPresence.haste = 2 * select(5, GetTalentInfo(1, 28))
		buffList.Precision.cost = -select(5, GetTalentInfo(3, 6))
		--remake this using the talent type
	end
end

--[[
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
	else
		print('Use: /ab on/off')
	end
end
]]--

local timeSinceLastUpdate = 0
local update_interval = 0.2

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

		time = 0
		count = 0

		manaCost = ComputeManaCost(baseManaCost, stacks, buffList)
		castTime = ComputeCastTime(baseCastTime, buffList)
		frame.stats:SetText('Cast time: ' .. math.floor(castTime * 100) / 100 .. '\n' .. 'Mana Cost: ' .. math.floor(manaCost * 100) / 100)	

		--loop
		while true do
			--if any self-buff is available, activate it and start cooldown (except mana gem/evocation)
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
		frame.text:SetText('Time left: ' .. math.floor(time * 100) / 100 .. '\n' .. 'Casts left: ' .. count)

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
	frame:SetScript('OnUpdate', UpdatePrediction)
end

function AB:PLAYER_REGEN_ENABLED()
	print('Leaving combat')
	frame:SetScript('OnUpdate', nil);
	timeSinceLastUpdate = 0
end

--general event handler
frame:SetScript('OnEvent', function(self, event, ...)
	if AB[event] then 
		print(event)
		AB[event](AB, ...)
	end
	if event == 'CHARACTER_POINTS_CHANGED' or event == 'ACTIVE_TALENT_GROUP_CHANGED' or event == 'PLAYER_ALIVE' or event == 'PLAYER_LOGIN' then
		AB:CheckCharacter()
	end
end)
