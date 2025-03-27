local addonName, ns = ...

local Util = ns.Util
local CharacterStore = ns.CharacterStore
local ConcentrationCooldown = {}

local function GetProfessionSpell(skillLine)

	local professionSpells = {
		[171] = 2259, -- Alchemy
		-- [794] = 278910, -- Archaeology
		[164] = 2018, -- Blacksmithing
		-- [185] = 2550, -- Cooking
		[333] = 7411, -- Enchanting
		[202] = 4036, -- Engineering
		-- [356] = 131474, -- Fishing
		-- [182] = 2366, -- Herbalism
		[773] = 45357, -- Inscription
		[755] = 25229, -- Jewelcrafting
		[165] = 2108, -- Leatherworking
		-- [186] = 2575, -- Mining
		-- [393] = 8613, -- Skinning
		[197] = 3908, -- Tailoring
	}

	local profession = C_TradeSkillUI.GetProfessionInfoBySkillLineID(skillLine).parentProfessionID

	return professionSpells[profession]
	-- local professions = C_TradeSkillUI.GetAllProfessionTradeSkillLines()

	-- local spells = {}

	-- for _, skillLine in ipairs(C_TradeSkillUI.GetAllProfessionTradeSkillLines() or {}) do
	-- 	table.insert(spells, professionSpells[skillLine])
	-- end

	-- return spells
end

local function AddCooldown(button, duration)
	if button.concentrationCooldown then
		print("Already added X to the button:", button:GetName())
		button.concentrationCooldown:Show()
		return
	end

	local cooldown = CreateFrame("Cooldown", "$parentCooldown", button, "CooldownFrameTemplate")
	cooldown:SetAllPoints(button)
	cooldown:SetCooldown(GetTime(), 10, 300)
	-- cooldown:SetDrawBling(true)
	-- cooldown:SetBlingTexture("Inter
	-- face\\Cooldown\\ping5")
	ActionButton_ShowOverlayGlow(button)
	cooldown:Show()

	local text = cooldown:CreateFontString("$parentCooldownText", "OVERLAY")
	text:SetFontObject("NumberFontNormal")
	text:SetPoint("CENTER")
	button.concentrationText = text

	-- cooldown.timeElapsed = 0
	-- cooldown:HookScript("OnUpdate", function(self, elapsed)
	-- 	self.timeElapsed = self.timeElapsed + elapsed
	-- 	if self.timeElapsed == nil or self.timeElapsed > 60 then
	-- 		self.timeElapsed = 0
	-- 		text:SetText()
	-- 	end
	-- end)

	button.concentrationCooldown = cooldown
	button.concentrationText = text

	-- button.xLines = { l1, l2 }
end



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
			-- local button = _G[bar .. i]
			Match(_G[bar .. i])
		end
	end

	for i=1, 2 do
		-- PrimaryProfession2SpellButtonBottom
		Match(_G[format("PrimaryProfession%dSpellButtonBottom", i)])

	end


	return buttons
end

function ConcentrationCooldown:Init()
	-- local characterStore = CharacterStore.Get()
	self.cooldowns = {}
	self.spells = {}
	self.character = CharacterStore.Get():CurrentPlayer()

	-- ConcentrationCooldown.character = character
	self.character:Update()

	for skillLine, concentration in pairs(self.character.concentration) do
		local spellID = GetProfessionSpell(skillLine)
		local buttons = FindSpellButtons(spellID)

		self.spells[spellID] = concentration

		print(skillLine, spellID, #buttons)
		for _, button in ipairs(buttons) do

			print(button:GetName())
			self:CreateCooldown(button, skillLine)
		end
	end

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)

		local spellID = tooltip:GetPrimaryTooltipData().id
		print(tooltip:GetPrimaryTooltipData().id)

		if not self:IsLearnedProfessionSpell(spellID) then
			return
		end
		-- if tooltip:GetPrimaryTooltipData().id ~= DELVE_KEY_CURRENCY_ID then
		-- 	return
		-- end


		-- local
		local progress = format("%d/%d", self.spells[spellID], 1000)
		local color =  self.spells[spellID] == 1000 and RED_FONT_COLOR or WHITE_FONT_COLOR

		tooltip:AddLine(" ")
		tooltip:AddDoubleLine("sdfsfds", color:WrapTextInColorCode(progress))
	end)
end

function ConcentrationCooldown:IsLearnedProfessionSpell(spellID)
	return spellID and self.spells[spellID] ~= nil
end

function ConcentrationCooldown:CreateCooldown(button, skillLine)
	if button.concentrationCooldown then
		print("Already added X to the button:", button:GetName())
		button.concentrationCooldown:Show()
		return
	end

	local cooldown = CreateFrame("Cooldown", "$parentCooldown", button, "CooldownFrameTemplate")
	cooldown.skillLine = skillLine
	cooldown:SetAllPoints(button)
	cooldown:SetHideCountdownNumbers(true)
	-- cooldown:SetReverse(true)
	-- cooldown:SetDrawEdge(false)
	-- cooldown:SetDrawSwipe(false)
	-- cooldown:SetCooldown(GetTime(), 10, 300)
	-- cooldown:SetDrawBling(true)
	-- cooldown:SetBlingTexture("Inter
	-- face\\Cooldown\\ping5")
	-- ActionButton_ShowOverlayGlow(button)
	-- cooldown:Show()
	local text = cooldown:CreateFontString("$parentCooldownText", "OVERLAY")
	-- text:SetFontObject("NumberFontNormalLarge")
	text:SetFontObject("SystemFont_Shadow_Large_Outline")

	text:SetPoint("CENTER")
	cooldown.text = text

	-- button:HookScript("Update", function(f)
	hooksecurefunc(button, "Update", function(f)
		print("Update", f:GetName())
		local concentration = self.character.concentration[cooldown.skillLine]
		if concentration == 1000 then
			ActionButton_ShowOverlayGlow(f)
		else
			ActionButton_HideOverlayGlow(f)
		end
	end)
	button.concentrationCooldown = cooldown



	-- self.cooldowns = self.cooldowns or {}
	table.insert(self.cooldowns, cooldown)

	-- button.xLines = { l1, l2 }
end

function ConcentrationCooldown:UpdateOverlayGlow(cooldown)
	local button = cooldown:GetParent()

	local concentration = self.character.concentration[cooldown.skillLine]

	if concentration == 1000 then
		ActionButton_ShowOverlayGlow(button)
	else
		ActionButton_HideOverlayGlow(button)
	end
end

function ConcentrationCooldown:Update()
	self.character:Update()

	-- local concentration = self.character.concentration

	for _, cooldown in ipairs(self.cooldowns) do
		local concentration = self.character.concentration[cooldown.skillLine]


		self:UpdateOverlayGlow(cooldown)
		cooldown:Clear()
		cooldown.text:SetText("")

		if concentration ~= nil and concentration ~= 1000 then
		-- 	cooldown:Clear()
		-- -- elseif concentration < 1000 then
		-- else
			cooldown:SetCooldownDuration(concentration/30, 60)
			cooldown.text:SetText(concentration)

		else
			print("Invalid concentration:", cooldown.skillLine)
		end
	end
end


if _G["ConcentrationCooldown"] == nil then
	_G["ConcentrationCooldown"] = ConcentrationCooldown

	ConcentrationCooldown.frame = CreateFrame("Frame")

	ConcentrationCooldown.frame:SetScript("OnEvent", function(self, event, ...)
		ConcentrationCooldown.eventsHandler[event](event, ...)
	end)

	function ConcentrationCooldown:RegisterEvent(name, handler)
		if self.eventsHandler == nil then
			self.eventsHandler = {}
		end
		self.eventsHandler[name] = handler
		self.frame:RegisterEvent(name)
	end


	ConcentrationCooldown:RegisterEvent("PLAYER_ENTERING_WORLD", function(event, isInitialLogin, isReloadingUi)


		ConcentrationCooldown:Init()
		ConcentrationCooldown:Update()

	end)

	ConcentrationCooldown:RegisterEvent("ADDON_LOADED", function(event, name)
		-- print(event, name, addonName)
		if name ~= addonName then return end


		ConcentrationCooldownDB = ConcentrationCooldownDB or {characters={}}
		-- ConcentrationCooldownDB ={characters={}, debug=true}

		Util.debug = ConcentrationCooldownDB.debug
		CharacterStore.Load(ConcentrationCooldownDB.characters)

		ConcentrationCooldown.db = ConcentrationCooldownDB
	end)


end

local function Hook()
for _, button in ipairs(FindSpellButtons(WARBAND_BANK_SPELL_ID)) do
	AddXToButton(button, 4, 2)
end

hooksecurefunc(SpellFlyout, "Show", function()
	for i = 1, 19 do
		local button = _G["SpellFlyoutButton" .. i]

		if button == nil or not button:IsShown() then
			break
		end

		RemoveXFromButton(button)
		if button.spellID == WARBAND_BANK_SPELL_ID then
			AddXToButton(button, 4, 2)
		end
	end
end)
end

