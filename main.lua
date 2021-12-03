local frame = CreateFrame('Frame')

frame:RegisterEvent('UNIT_MANA')
frame:RegisterEvent('UNIT_AURA')
frame:RegisterEvent('UNIT_MAXMANA')
frame:RegisterEvent('ACTIVE_TALENT_GROUP_CHANGED')
frame:RegisterEvent('PLAYER_ENTERING_WORLD')
frame:RegisterEvent('PLAYER_EQUIPMENT_CHANGED')

local InitialiseBuff = function(buff)
	local isActive, _, _, _, _, _, expirationTime = UnitBuff('player', buff)
	local activationTime, spellCooldown = GetSpellCooldown(buff)
	return {
		active = isActive and true or false,
		duration = isActive and expirationTime - GetTime() or 0,
		cooldown = activationTime == 0 and 0 or spellCooldown - (GetTime() - activationTime),
		cooldownmax = spellCooldown,
	}
end

local ComputeCastTime = function(cast, icyveins, berserking, powerinfusion)
	return cast / (1 + (icyveins.active and 0.2 or 0)) / (1 + (berserking.active and 0.2 or 0)) --/ (1 + (powerinfusion.active and 0.2 or 0))
end

local ComputeManaCost = function(cost, stacks, arcanepower, powerinfusion)
	return cost * (1 + 1.75 * stacks) * (1 + (arcanepower.active and 0.2 or 0)) --/ (1 + powerinfusion.active and 0.2 or 0)
end

local UpdateBuff = function(buff, cast)
	return {
		active = (buff.cooldown < cast or buff.duration > cast) and true or false,
		duration = math.max(buff.duration - cast, 0),
		cooldown = buff.cooldown > cast and buff.cooldown - cast or buff.spellCooldown,
		cooldownmax = buff.spellCooldown,
	}
end

local manaCostReduction = 0
local initialManaCost, baseManaCost = 142.45, 142.5
-- 2035 base mana -> 142.45 base mana cost of AB
local initialCastTime, baseCastTime = 2.5, 2.5

local time, manaCurrent, manaMax, manaCost, castTime, stacks
local IcyVeins

frame:SetScript('OnEvent', function(self, event, unit)
	if select(2, UnitClass('player')) ~= 'MAGE' then return end
	if event == 'ACTIVE_TALENT_GROUP_CHANGED' or event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_EQUIPMENT_CHANGED' then
		manaCostReduction = select(5, GetTalentInfo(1, 2)) + select(5, GetTalentInfo(3, 6))
		baseManaCost = initialManaCost * (1 - manaCostReduction / 100)
		baseCastTime = initialCastTime / (1 + 2 * select(5, GetTalentInfo(1, 28)) / 100) / (1 + GetCombatRatingBonus(20) / 100)
	end
	if unit ~= 'player' then return end
	-- if not UnitAffectingCombat('player') then return end
	-- only compute in combat
	if event == 'UNIT_MANA' or event == 'UNIT_AURA' or event == 'UNIT_MAXMANA' then
		manaCurrent = UnitMana('player')
		manaMax = UnitManaMax('player')
		manaRegen = select(2, GetManaRegen())
		stacks = select(4, UnitDebuff('player', 'Arcane Blast')) or 0
		
		IcyVeins = InitialiseBuff('Icy Veins')
		Berserking = InitialiseBuff('Berserking')
		ArcanePower = InitialiseBuff('Arcane Power')
		--PowerInfusion = InitialiseBuff('Power Infusion')

		castTime = ComputeCastTime(baseCastTime, IcyVeins, Berserking) --,PowerInfusion)
		manaCost = ComputeManaCost(baseManaCost, stacks, ArcanePower) --, PowerInfusion)
		time = 0

		--print("Base cast time = " .. baseCastTime)
		--print("Base mana cost = " .. baseManaCost)
		--print("Current cast time = " .. castTime)
		--print("Current mana cost = " .. manaCost)

		local count = 0
		while manaCurrent > manaCost do
			time = time + castTime
			manaCurrent = math.min(manaCurrent + castTime * manaRegen, manaMax) - manaCost
			if stacks < 4 then stacks = stacks + 1 end
			UpdateBuff(IcyVeins, castTime)
			UpdateBuff(Berserking, castTime)
			UpdateBuff(ArcanePower, castTime)
			manaCost = ComputeManaCost(baseManaCost, stacks, ArcanePower) --, PowerInfusion)
			castTime = ComputeCastTime(baseCastTime, IcyVeins, Berserking) --, PowerInfusion)
			count = count + 1
			--print("Count = " .. count .. ", time = " .. time)
		end
		print('Time left = ' .. math.floor(time * 100) / 100 )
		print('Cast left = ' .. count)
	end
end)

--arcane power (+cost)
--icy veins (-cast)
--berserking (-cast)
--bl/hero (-cast)
--pi (-cast, -cost)
--replenish (+mana)
--mana gem (+mana)
--hymn of hope (+mana then -mana)