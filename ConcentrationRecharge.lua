local addonName, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local Concentration = ns.Concentration

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
	local button = self:GetParent()
	self:SetAllPoints(button)

	local swipe = CreateFrame("Cooldown", "$parentCooldown", self, "CooldownFrameTemplate")
	swipe:SetAllPoints(button)
	swipe:SetHideCountdownNumbers(true)
	self.swipe = swipe

	local text = swipe:CreateFontString("$parentCooldownText", "OVERLAY")
	text:SetFontObject("SystemFont_Shadow_Large_Outline")
	text:SetPoint("CENTER")
	self.text = text

	local alert = CreateFrame("Frame", nil, button, "ActionBarButtonSpellActivationAlert")
	local w, h = button:GetSize()
	alert:SetSize(w * 1.4, h * 1.4)
	alert:SetPoint("CENTER", button, "CENTER", 0, 0)
	alert:SetScript("OnShow", function(f)
		f.ProcStartAnim:Play()
	end)
	alert:Hide()
	self.alert = alert

	self:SetScript("OnShow", self.OnShow)
	self:SetScript("OnHide", self.OnHide)

	button:HookScript("OnShow", function()
		self:Show()
	end)
	button:HookScript("OnHide", function()
		self:Hide()
	end)
end

function ConcentrationCooldownMixin:OnShow()
	self.alert:Show()
	self.swipe:Show()
end

function ConcentrationCooldownMixin:OnHide()
	self.alert:Hide()
	self.swipe:Hide()
end

function ConcentrationCooldownMixin:SetGlowShown(show)
	self.glowShown = show
	self:UpdateOverlayGlow()
end

function ConcentrationCooldownMixin:UpdateOverlayGlow()
	if not self.glowShown and not self.alert:IsVisible() then
		return
	end

	if self.concentration:IsFull() and self.glowShown then
		self.alert:Show()
		self.alert.ProcStartAnim:Play()
	else
		self.alert:Hide()
		self.alert.ProcLoop:Stop()
		if self.alert.ProcStartAnim:IsPlaying() then
			self.alert.ProcStartAnim:Stop()
		end
	end
end

function ConcentrationCooldownMixin:Update()
	Util:Debug("Updating cooldown:", self:GetParent():GetName())

	self.swipe:Clear()
	self.text:SetText("")

	self:UpdateOverlayGlow()

	if self.concentration:IsRecharging() then
		self.swipe:SetCooldownUNIX(GetServerTime() - self.concentration:SecondsRecharged(), self.concentration:SecondsOfRecharge(), 60)
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
		elseif not IsModifierKeyDown() then
			self:AddRechargeToTooltip(tooltip, concentration)
		end
	end)

	self:RegisterSettings()
end

function ConcentrationRecharge:FormatConcentration(concentration)
	local v, isFull = concentration:GetLatestV()

	return format("|cn%s:%d/1000|r", isFull and "RED_FONT_COLOR" or "WHITE_FONT_COLOR", v)
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

	local cooldown = CreateFrame("Frame", nil, button)
	Mixin(cooldown, ConcentrationCooldownMixin)
	cooldown.concentration = concentration
	cooldown:OnLoad()

	do
		local function SetGlowShown(show)
			cooldown:SetGlowShown(show and ConcentrationRechargeSettings.glow)
		end
		ns:RegisterOptionCallback("glow", SetGlowShown)
		ns:RegisterOptionCallback("glow-" .. concentration.skillLine, SetGlowShown)
	end

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

function ConcentrationRecharge:SetShown(show)
	for _, cooldown in ipairs(self.cooldowns) do
		if show and not cooldown:IsVisible() then
			cooldown:Show()
		elseif not show and cooldown:IsVisible() then
			cooldown:Hide()
		end
	end
end

function ConcentrationRecharge:ExecuteChatCommands(command)
	if command == "debug" then
		-- Toggle Debug Mode
		self.db.debug = not self.db.debug
		Util.debug = self.db.debug
		print("Debug Mode:", self.db.debug)
		return
	end

	print("Usage: |n/cr debug - Turn on/off debugging mode")
end

function ConcentrationRecharge:RegisterSettings()
	local settings = {}

	for skillLine, _ in pairs(Concentration.skillLinesTWW) do
		local name = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine).professionName
		local title = format("|T%d:30|t %s", Util:GetProfessionIcon(skillLine), name)

		local row = {
			key = "glow-" .. skillLine,
			type = "toggle",
			title = title,
			tooltip = format("Show glow effect on the |cffffffff%s|r spell icon when the concentration is fully recharged", name),
			default = true,
			requires = "glow",
			parent = "glow",
		}
		table.insert(settings, row)
	end

	table.insert(settings, 1, {
		key = "glow",
		type = "toggle",
		title = "Enable cooldown glow effects",
		tooltip = "Show glow effect on the spell icon when the concentration is fully recharged",
		default = true,
	})

	ns:RegisterSettings("ConcentrationRechargeSettings", settings)
end

if _G["ConcentrationRecharge"] == nil then
	_G["ConcentrationRecharge"] = ConcentrationRecharge

	SLASH_CONCENTRATION_RECHARGE1 = "/ConcentrationRecharge"
	SLASH_CONCENTRATION_RECHARGE2 = "/cr"
	function SlashCmdList.CONCENTRATION_RECHARGE(msg, editBox)
		ConcentrationRecharge:ExecuteChatCommands(msg)
	end

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

	ConcentrationRecharge:RegisterEvent("PLAYER_REGEN_DISABLED", function()
		ConcentrationRecharge:SetShown(false)
	end)

	ConcentrationRecharge:RegisterEvent("PLAYER_REGEN_ENABLED", function()
		ConcentrationRecharge:SetShown(true)
	end)

	ConcentrationRecharge:RegisterEvent("ADDON_LOADED", function(event, name)
		if name ~= addonName then
			return
		end

		ConcentrationRechargeDB = ConcentrationRechargeDB or DefaultConcentrationRechargeDB

		ConcentrationRecharge.db = ConcentrationRechargeDB
		Util.debug = ConcentrationRechargeDB.debug
		CharacterStore.Load(ConcentrationRechargeDB.characters)
	end)
end
