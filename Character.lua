local _, ns = ...

local Util = ns.Util

local Character = {
}

ns.Character = Character

local CONCENTRATION_MAX = 1000
local CONCENTRATION_RECHARGE_RATE_IN_SECONDS = 10 / 3600

function Character:New(o)
	o = o or {}
	self.__index = self
	setmetatable(o, self)

	if next(o) == nil then
		Character._Init(o)
	end

	return o
end

function Character:_Init()
	local _localizedClassName, classFile, _classID = UnitClass("player")
	local _englishFactionName, localizedFactionName = UnitFactionGroup("player")

	self.name = UnitName("player")
	self.GUID = UnitGUID("player")
	self.realmName = GetRealmName()
	-- self.level = UnitLevel("player")
	self.factionName = localizedFactionName
	self.class = classFile
	self.concentration = {}
	self.updatedAt = GetServerTime()

	Util:Debug("Initialized new character:", self.name)
end

function Character:GetConcentrationRestoreTime(skillLine)

	local concentration = self.sconcentration[skillLine]
	if concentration == nil then
		return
	end

	return self.updatedAt + (CONCENTRATION_MAX - concentration) / CONCENTRATION_RECHARGE_RATE_IN_SECONDS
end

function Character:_UpdateConcentration(skillLine)
	local currencyID = C_TradeSkillUI.GetConcentrationCurrencyID(skillLine)

	if not currencyID then
	    return false
	end

	local concentration = C_CurrencyInfo.GetCurrencyInfo(currencyID)
	if not concentration then return false end

	self.concentration[skillLine] = concentration.quantity

	Util:Debug("Concentration Updated:", skillLine, self.concentration[skillLine])

	return true
end
function Character:Update()
	local tabIndices = { GetProfessions() }

	local skillLinesTWW = {
		[171] = 2871, -- Alchemy
		-- [794] = 278910, -- Archaeology
		[164] = 2872, -- Blacksmithing
		-- [185] = 2550, -- Cooking
		[333] = 2874, -- Enchanting
		[202] = 2875, -- Engineering
		-- [356] = 2876, -- Fishing
		[182] = 2877, -- Herbalism
		[773] = 2878, -- Inscription
		[755] = 2879, -- Jewelcrafting
		[165] = 2880, -- Leatherworking
		[186] = 2881, -- Mining
		[393] = 2882, -- Skinning
		[197] = 2883, -- Tailoring
	}
	for i = 1, 2
	 do
		if tabIndices[i] ~= nil then
			local name, icon, skillLevel, maxSkillLevel, numAbilities, spelloffset, skillLine, _ = GetProfessionInfo(tabIndices[i])
			-- print(name, skillLine)
			Util:Debug("Updating Concentration:", name, skillLine)
			self:_UpdateConcentration(skillLinesTWW[skillLine])
		end
	end

	self.updatedAt = GetServerTime()
end