local _, ns = ...

local Util = ns.Util

local Concentration = {
	skillLineToCurrencyCache = {},
	skillLinesTWW = {
		[171] = 2871, -- Alchemy
		-- [794] = 278910, -- Archaeology
		[164] = 2872, -- Blacksmithing
		-- [185] = 2873, -- Cooking
		[333] = 2874, -- Enchanting
		[202] = 2875, -- Engineering
		-- [356] = 2876, -- Fishing
		-- [182] = 2877, -- Herbalism
		[773] = 2878, -- Inscription
		[755] = 2879, -- Jewelcrafting
		[165] = 2880, -- Leatherworking
		-- [186] = 2881, -- Mining
		-- [393] = 2882, -- Skinning
		[197] = 2883, -- Tailoring
	},
}

Concentration.__index = Concentration

local CONCENTRATION_MAX = 1000
local CONCENTRATION_RECHARGE_RATE_IN_SECONDS = 250 / 24 / 3600

function Concentration.__eq(a, b)
	return a.fullTime == b.fullTime
end

function Concentration.__lt(a, b)
	return a.fullTime < b.fullTime
end

function Concentration:Create(name, skillLine, spelloffset, buttonIndex)
	if self.skillLinesTWW[skillLine] == nil then
		Util:Debug("Unsupported profession:", name)
		return
	end

	local itemType, actionID, spellID = C_SpellBook.GetSpellBookItemType(1 + spelloffset, Enum.SpellBookSpellBank.Player)

	local o = {}
	o.i = buttonIndex
	o.skillLine = skillLine
	o.spell = spellID

	setmetatable(o, self)

	Util:Debug("Concentration Init:", name, skillLine)

	return o
end

function Concentration:Update()
	local currencyID = self.skillLineToCurrencyCache[self.skillLine]
	if not currencyID then
		currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(self.skillLinesTWW[self.skillLine])

		if not currencyID then
			return false
		end

		self.skillLineToCurrencyCache[self.skillLine] = currencyID
	end

	local currency = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not currency then
		return false
	end

	self.v = currency.quantity
	self.fullTime = GetServerTime() + (CONCENTRATION_MAX - self.v) / CONCENTRATION_RECHARGE_RATE_IN_SECONDS

	Util:Debug("Concentration Updated:", self.skillLine, self.v)

	return true
end

function Concentration:GetLatestV()
	if self.v == CONCENTRATION_MAX then
		return CONCENTRATION_MAX, true
	end

	local now = GetServerTime()
	if now >= self.fullTime then
		return CONCENTRATION_MAX, true
	end

	return math.floor(0.5 + CONCENTRATION_MAX - (self.fullTime - now) * CONCENTRATION_RECHARGE_RATE_IN_SECONDS), false
end

function Concentration:IsFull()
	return select(2, self:GetLatestV())
end

function Concentration:IsRecharging()
	return self.v and not select(2, self:GetLatestV())
end

function Concentration:SecondsToFull()
	return self.fullTime - GetServerTime()
end

function Concentration:SecondsOfRecharge()
	return CONCENTRATION_MAX / CONCENTRATION_RECHARGE_RATE_IN_SECONDS
end

function Concentration:SecondsRecharged()
	return self.v / CONCENTRATION_RECHARGE_RATE_IN_SECONDS
end

ns.Concentration = Concentration

local Character = {}

function Character:New(o)
	o = o or {}
	self.__index = self
	setmetatable(o, self)

	if next(o) == nil then
		Character._Init(o)
	end

	for _, concentration in pairs(o.concentration) do
		setmetatable(concentration, Concentration)
	end

	return o
end

function Character:_Init()
	local _localizedClassName, classFile, _classID = UnitClass("player")
	local _englishFactionName, localizedFactionName = UnitFactionGroup("player")

	self.name = UnitName("player")
	self.GUID = UnitGUID("player")
	self.realmName = GetRealmName()
	self.level = UnitLevel("player")
	self.factionName = localizedFactionName
	self.class = classFile
	self.concentration = {}
	self.updatedAt = GetServerTime()

	Util:Debug("Initialized new character:", self.name)
end

function Character:Update()
	local indices = { GetProfessions() }

	for i = 1, 2 do
		local tabIndex = indices[i]
		if tabIndex then
			local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, _ = GetProfessionInfo(tabIndex)
			local concentration = self.concentration[skillLine]

			if concentration == nil then
				concentration = Concentration:Create(name, skillLine, spelloffset, i)
				self.concentration[skillLine] = concentration
			end

			if concentration then
				concentration:Update()
			end
		end
	end

	self.updatedAt = GetServerTime()
end

ns.Character = Character
