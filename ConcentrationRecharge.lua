local addonName, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore

local function FindSpellButtons(spellID)
	local bars = {
		"ActionButton",
		"MultiBarBottomLeftButton",
		"MultiBarBottomRightButton",
		"MultiBarLeftButton",
		"MultiBarRightButton",
		"MultiBar5Button",
		"MultiBar6Button",
		"MultiBar7Button",
	}

	local buttons = {}
	local function Match(button)
		if button and button.action then
			local actionType, id = GetActionInfo(button.action)

			if actionType == "spell" and id == spellID then
				Util:Debug("Found:", button:GetName())
				table.insert(buttons, button)
			end
		end
	end

	for _, bar in ipairs(bars) do
		for i = 1, NUM_ACTIONBAR_BUTTONS do
			Match(_G[bar .. i])
		end
	end

	return buttons
end

local ConcentrationCooldownMixin = {}

function ConcentrationCooldownMixin:OnLoad()
	local text = self:CreateFontString("$parentCooldownText", "OVERLAY")
	text:SetFontObject("SystemFont_Shadow_Large_Outline")
	text:SetPoint("CENTER")
	self.text = text

	local button = self:GetParent()
	self:SetAllPoints(button)
	self:SetHideCountdownNumbers(true)

	if button.Update then
		hooksecurefunc(button, "Update", function()
			self:UpdateOverlayGlow()
		end)
	end
end

function ConcentrationCooldownMixin:UpdateOverlayGlow()
	ActionButton_HideOverlayGlow(self:GetParent())

	if self.concentration:IsFull() then
		ActionButton_ShowOverlayGlow(self:GetParent())
	end
end

function ConcentrationCooldownMixin:Update()
	Util:Debug("Updating cooldown:", self:GetParent():GetName())

	self:Clear()
	self.text:SetText("")

	self:UpdateOverlayGlow()

	if self.concentration:IsRecharging() then
		self:SetCooldownUNIX(GetServerTime() - self.concentration:SecondsRecharged(), self.concentration:SecondsOfRecharge(), 60)
		self.text:SetText(self.concentration:GetLatestV())
	end
end

local ConcentrationRecharge = {}

function ConcentrationRecharge:Init()
	self.cooldowns = {}
	self.spells = {}

	self.characterStore = CharacterStore.Get()
	self.characterStore:SetSortField("concentration")

	self.character = self.characterStore:CurrentPlayer()
	self.character:Update()

	for skillLine, concentration in pairs(self.character.concentration) do
		local buttons = FindSpellButtons(concentration.spell)
		self.spells[concentration.spell] = concentration

		for _, button in ipairs(buttons) do
			self:CreateCooldown(button, concentration)
		end
	end

	hooksecurefunc("ProfessionsBook_LoadUI", function()
		for _, concentration in pairs(self.character.concentration) do
			self:CreateCooldown(_G[format("PrimaryProfession%dSpellButtonBottom", concentration.i)], concentration)
		end

		hooksecurefunc("ProfessionsBookFrame_Update", function()
			self:Update()
		end)
	end)

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
		local spellID = tooltip:GetPrimaryTooltipData().id

		if not self:IsLearnedProfessionSpell(spellID) then
			return
		end

		local concentration = self.spells[spellID]

		tooltip:AddLine(" ")

		if IsControlKeyDown() then
			self:AddWarbandConcentrationToTooltip(tooltip, concentration.skillLine)
		else
			self:AddRechargeToTooltip(tooltip, concentration)
		end
	end)
end

function ConcentrationRecharge:FormatConcentration(concentration)
	return format("|cn%s:%d/1000|r", concentration:IsFull() and "RED_FONT_COLOR" or "WHITE_FONT_COLOR", concentration:GetLatestV())
end

function ConcentrationRecharge:AddRechargeToTooltip(tooltip, concentration)
	tooltip:AddLine(
		format("%s %s: %s", CreateSimpleTextureMarkup(5747318, 15, 15), PROFESSIONS_CRAFTING_STAT_CONCENTRATION, self:FormatConcentration(concentration))
	)

	local indent = CreateSimpleTextureMarkup(0, 15, 15) .. " "
	if concentration:IsRecharging() then
		local timeLeft = WHITE_FONT_COLOR:WrapTextInColorCode(Util.FormatTimeDuration(concentration:SecondsToFull()))

		tooltip:AddLine(indent .. SPELL_RECHARGE_TIME:format(timeLeft))
	end

	tooltip:AddLine("|n|cnGREEN_FONT_COLOR:<Press CTRL to show all characters>|r")
end

function ConcentrationRecharge:AddWarbandConcentrationToTooltip(tooltip, skillLine)
	local sortOrder, ascending = self.characterStore:GetSortOrder()

	if sortOrder ~= skillLine then
		self.characterStore:SetSortOrder("name")
		self.characterStore:SetSortOrder(skillLine)
	end

	if ascending then
		self.characterStore:SetSortOrder(skillLine)
	end

	tooltip:AddLine(format("%s %s:", CreateSimpleTextureMarkup(5747318, 15, 15), PROFESSIONS_CRAFTING_STAT_CONCENTRATION))

	local indent = CreateSimpleTextureMarkup(0, 15, 15) .. " "
	self.characterStore:ForEach(function(character)
		tooltip:AddDoubleLine(
			Util.WrapTextInClassColor(character.class, format("%s%s - %s", indent, character.name, character.realmName)),
			self:FormatConcentration(character.concentration[skillLine])
		)
	end, function(character)
		return character.concentration[skillLine]
	end)
end

function ConcentrationRecharge:IsLearnedProfessionSpell(spellID)
	return spellID and self.spells[spellID] ~= nil
end

function ConcentrationRecharge:CreateCooldown(button, concentration)
	if button.ConcentrationRecharge then
		Util:Debug("Error: Button has been initialized", button:GetName())
		button.ConcentrationRecharge:Show()
		return
	end

	local cooldown = CreateFrame("Cooldown", "$parentCooldown", button, "CooldownFrameTemplate")
	Mixin(cooldown, ConcentrationCooldownMixin)
	cooldown.concentration = concentration
	cooldown:OnLoad()

	button.ConcentrationRecharge = cooldown
	table.insert(self.cooldowns, cooldown)

	return cooldown
end

function ConcentrationRecharge:Update()
	self.character:Update()

	for _, cooldown in ipairs(self.cooldowns) do
		cooldown:Update()
	end
end

if _G["ConcentrationRecharge"] == nil then
	_G["ConcentrationRecharge"] = ConcentrationRecharge

	local DefaultConcentrationRechargeDB = {
		characters = {},
	}

	ConcentrationRecharge.frame = CreateFrame("Frame")

	ConcentrationRecharge.frame:SetScript("OnEvent", function(self, event, ...)
		ConcentrationRecharge.eventsHandler[event](event, ...)
	end)

	function ConcentrationRecharge:RegisterEvent(name, handler)
		if self.eventsHandler == nil then
			self.eventsHandler = {}
		end
		self.eventsHandler[name] = handler
		self.frame:RegisterEvent(name)
	end

	ConcentrationRecharge:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)
		if isInitialLogin == false and isReloadingUi == false then
			return
		end

		ConcentrationRecharge:Init()
		ConcentrationRecharge:Update()
	end)

	ConcentrationRecharge:RegisterEvent("PLAYER_LEAVING_WORLD", function()
		ConcentrationRecharge.character:Update()
	end)

	ConcentrationRecharge:RegisterEvent("TRADE_SKILL_CLOSE", function()
		ConcentrationRecharge:Update()
	end)

	ConcentrationRecharge:RegisterEvent("ADDON_LOADED", function(event, name)
		if name ~= addonName then
			return
		end

		ConcentrationRechargeDB = ConcentrationRechargeDB or DefaultConcentrationRechargeDB

		Util.debug = ConcentrationRechargeDB.debug
		CharacterStore.Load(ConcentrationRechargeDB.characters)
	end)
end
