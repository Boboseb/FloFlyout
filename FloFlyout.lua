-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local VERSION = "4.3.1"
local NAME = "FloFlyout"
local SPELLFLYOUT_DEFAULT_SPACING = 4
local SPELLFLYOUT_INITIAL_SPACING = 7
local SPELLFLYOUT_FINAL_SPACING = 4
local STRIPE_COLOR = {r=0.9, g=0.9, b=1}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------

FLOFLYOUT_CONFIG = {
	flyouts = {
		--[[ Sample config : each flyout can have a list of spell and an icon
		[1] = {
			spells = {
				[1] = 8024, -- Flametongue
				[2] = 8033, -- Frostbite
				[3] = 8232, -- Windfury
				[4] = 8017, -- RockBite
				[5] = 51730, -- earthliving
			},
			icon = ""
		},
		]]
	},
	actions = {
		[1] = {
			--[[ Sample config : for each talent group there is a list of actions bound to flyouts
			[13] = 1,
			[49] = 1,
			[25] = 1,
			]]
		},
		[2] = {
		},
	}
}

local FloFlyout = {
	openers = {},
	config = FLOFLYOUT_CONFIG
}

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

local function FloFlyout_ReadCmd(line)
	local i, v, flyoutid;
	local cmd, arg1, arg2 = strsplit(' ', line or "", 3);

	if cmd == "addflyout" then
		DEFAULT_CHAT_FRAME:AddMessage("New flyout : "..FloFlyout:AddFlyout())
	elseif cmd == "removeflyout" and FloFlyout:IsValidFlyoutId(arg1) then
		FloFlyout:RemoveFlyout(arg1)
		FloFlyout:ApplyConfig()
	elseif cmd == "addspell" and FloFlyout:IsValidFlyoutId(arg1) then
		DEFAULT_CHAT_FRAME:AddMessage("New spell : "..FloFlyout:AddSpell(arg1, arg2))
		FloFlyout:ApplyConfig()
	elseif cmd == "removespell" and FloFlyout:IsValidFlyoutId(arg1) and FloFlyout:IsValidSpellPos(arg1, arg2) then
		FloFlyout:RemoveSpell(arg1, arg2)
		FloFlyout:ApplyConfig()
	elseif cmd == "bind" and tonumber(arg1) and FloFlyout:IsValidFlyoutId(arg2) then
		FloFlyout:AddAction(arg1, arg2)
		FloFlyout:ApplyConfig()
	elseif cmd == "unbind" and tonumber(arg1) then
		FloFlyout:RemoveAction(arg1)
		FloFlyout:ApplyConfig()
	else
		DEFAULT_CHAT_FRAME:AddMessage( "FloFlyout usage :" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo addflyout : add a new flyout" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo removeflyout <flyoutid> : remove flyout" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo addspell <flyoutid> <spellid> : add a new spell to flyout" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo removespell <flyoutid> <spellpos> : remove spell from flyout" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo bind <actionid> <flyoutid> : bind action to flyout" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo unbind <actionid> : unbind action" );
		DEFAULT_CHAT_FRAME:AddMessage( "/ffo panic||reset : Reset FloFlyout" );
		return;
	end
end

-- Executed on load, calls general set-up functions
function FloFlyout_OnLoad(self)

	DEFAULT_CHAT_FRAME:AddMessage( NAME.." "..VERSION.." loaded." )

	SLASH_FLOFLYOUT1 = "/floflyout"
	SLASH_FLOFLYOUT2 = "/ffo"
	SlashCmdList["FLOFLYOUT"] = FloFlyout_ReadCmd

	StaticPopupDialogs["CONFIRM_DELETE_FLO_FLYOUT"] = {
		text = CONFIRM_DELETE_EQUIPMENT_SET,
		button1 = YES,
		button2 = NO,
		OnAccept = function (self) FloFlyout:RemoveFlyout(self.data); FloFlyoutConfigPane_Update(); FloFlyout:ApplyConfig(); end,
		OnCancel = function (self) end,
		hideOnEscape = 1,
		timeout = 0,
		exclusive = 1,
		whileDead = 1,
	}

	self:RegisterEvent("ADDON_LOADED")
	--self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	--self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_ALIVE")
	--self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	--self:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
	self:RegisterEvent("UPDATE_BINDINGS")

end

function FloFlyout_OnEvent(self, event, arg1, ...)

	if event == "PLAYER_ENTERING_WORLD" --[[or event == "PLAYER_ALIVE"]] then
		FloFlyout:ApplyConfig()

	--elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_USABLE" then

	elseif event == "ADDON_LOADED" and arg1 == NAME then

		-- Ici, nous avons rechargé notre configuration
		FloFlyout.config = FLOFLYOUT_CONFIG

		local button
		for _, button in ipairs({FloFlyoutFrame:GetChildren()}) do
			SecureHandlerWrapScript(button, "OnClick", button, "self:GetParent():Hide()")
		end

	elseif event == "UPDATE_BINDINGS" then

	elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
		FloFlyout:ApplyConfig()
	else

	end
end

function FloFlyoutFrame_OnEvent(self, event, ...)
	if event == "SPELL_UPDATE_COOLDOWN" then
		local i = 1
		local button = _G["FloFlyoutFrameButton"..i]
		while (button and button:IsShown()) do
			SpellFlyoutButton_UpdateCooldown(button)
			i = i+1
			button = _G["FloFlyoutFrameButton"..i]
		end
	elseif event == "CURRENT_SPELL_CAST_CHANGED" then
		local i = 1
		local button = _G["FloFlyoutFrameFlyoutButton"..i]
		while (button and button:IsShown()) do
			SpellFlyoutButton_UpdateState(button)
			i = i+1
			button = _G["FloFlyoutFrameButton"..i]
		end
	elseif event == "SPELL_UPDATE_USABLE" then
		local i = 1
		local button = _G["FloFlyoutFrameFlyoutButton"..i]
		while (button and button:IsShown()) do
			SpellFlyoutButton_UpdateUsable(button)
			i = i+1
			button = _G["FloFlyoutFrameButton"..i]
		end
	elseif event == "BAG_UPDATE" then
		local i = 1
		local button = _G["FloFlyoutFrameButton"..i]
		while (button and button:IsShown()) do
			SpellFlyoutButton_UpdateCount(button)
			SpellFlyoutButton_UpdateUsable(button)
			i = i+1
			button = _G["FloFlyoutFrameButton"..i]
		end
	elseif event == "SPELL_FLYOUT_UPDATE" then
		local i = 1
		local button = _G["FloFlyoutFrameButton"..i]
		while (button and button:IsShown()) do
			SpellFlyoutButton_UpdateCooldown(button)
			SpellFlyoutButton_UpdateState(button)
			SpellFlyoutButton_UpdateUsable(button)
			SpellFlyoutButton_UpdateCount(button)
			i = i+1
			button = _G["FloFlyoutFrameButton"..i]
		end
	elseif event == "ACTIONBAR_PAGE_CHANGED" then
		self:Hide()
	end
end

function FloFlyout:BindFlyoutToAction(idFlyout, idAction)

	local direction, actionButton, actionBarPage, bonusBar
	direction = "UP"

	if idAction <= 12 then
		bonusBar = 0
		actionBarPage = 1
		actionButton = _G["ActionButton"..idAction]
	elseif idAction <= 24 then
		actionBarPage = 2
		actionButton = _G["ActionButton"..(idAction - 12)]
	elseif idAction <= 36 then
		if SHOW_MULTI_ACTIONBAR_3 then
			actionButton = _G["MultiBarRightButton"..(idAction - 24)]
			direction = "LEFT"
		else
			actionBarPage = 3
			actionButton = _G["ActionButton"..(idAction - 24)]
		end
	elseif idAction <= 48 then
		if SHOW_MULTI_ACTIONBAR_4 then
			actionButton = _G["MultiBarLeftButton"..(idAction - 36)]
			direction = "RIGHT"
		else
			actionBarPage = 4
			actionButton = _G["ActionButton"..(idAction - 36)]
		end
	elseif idAction <= 60 then
		if SHOW_MULTI_ACTIONBAR_2 then
			actionButton = _G["MultiBarBottomRightButton"..(idAction - 48)]
		else
			actionBarPage = 5
			actionButton = _G["ActionButton"..(idAction - 48)]
		end
	elseif idAction <= 72 then
		if SHOW_MULTI_ACTIONBAR_1 then
			actionButton = _G["MultiBarBottomLeftButton"..(idAction - 60)]
		else
			actionBarPage = 6
			actionButton = _G["ActionButton"..(idAction - 60)]
		end
	elseif idAction <= 84 then
		bonusBar = 1
		actionBarPage = 1
		actionButton = _G["ActionButton"..(idAction - 72)]
	elseif idAction <= 96 then
		bonusBar = 2
		actionBarPage = 1
		actionButton = _G["ActionButton"..(idAction - 84)]
	elseif idAction <= 108 then
		bonusBar = 3
		actionBarPage = 1
		actionButton = _G["ActionButton"..(idAction - 96)]
	elseif idAction <= 120 then
		bonusBar = 4
		actionBarPage = 1
		actionButton = _G["ActionButton"..(idAction - 108)]
	end

	FloFlyout:CreateOpener("FloFlyoutOpener"..idAction, idFlyout, direction, actionButton, actionBarPage, bonusBar)
end

local function Opener_UpdateFlyout(self)
	-- Update border and determine arrow position
	local arrowDistance;
	if ((FloFlyoutFrame and FloFlyoutFrame:IsShown() and FloFlyoutFrame:GetParent() == self) or GetMouseFocus() == self) then
		self.FlyoutBorder:Show();
		self.FlyoutBorderShadow:Show();
		arrowDistance = 5;
	else
		self.FlyoutBorder:Hide();
		self.FlyoutBorderShadow:Hide();
		arrowDistance = 2;
	end

	-- Update arrow
	self.FlyoutArrow:Show();
	self.FlyoutArrow:ClearAllPoints();
	local direction = self:GetAttribute("flyoutDirection");
	if (direction == "LEFT") then
		self.FlyoutArrow:SetPoint("LEFT", self, "LEFT", -arrowDistance, 0);
		SetClampedTextureRotation(self.FlyoutArrow, 270);
	elseif (direction == "RIGHT") then
		self.FlyoutArrow:SetPoint("RIGHT", self, "RIGHT", arrowDistance, 0);
		SetClampedTextureRotation(self.FlyoutArrow, 90);
	elseif (direction == "DOWN") then
		self.FlyoutArrow:SetPoint("BOTTOM", self, "BOTTOM", 0, -arrowDistance);
		SetClampedTextureRotation(self.FlyoutArrow, 180);
	else
		self.FlyoutArrow:SetPoint("TOP", self, "TOP", 0, arrowDistance);
		SetClampedTextureRotation(self.FlyoutArrow, 0);
	end
end

local function Opener_PreClick(self, button, down)
	local direction = self:GetAttribute("flyoutDirection");
	local spellList = { strsplit(",", self:GetAttribute("spelllist")) }
	local buttonList = { FloFlyoutFrame:GetChildren() }
	for i, buttonRef in ipairs(buttonList) do
		if spellList[i] then
			buttonRef.spellID = spellList[i]
			local icon = GetSpellTexture(spellList[i])
			_G[buttonRef:GetName().."Icon"]:SetTexture(icon)
			SpellFlyoutButton_UpdateCooldown(buttonRef)
			SpellFlyoutButton_UpdateState(buttonRef)
			SpellFlyoutButton_UpdateUsable(buttonRef)
			SpellFlyoutButton_UpdateCount(buttonRef)
		end
	end
	FloFlyoutFrame.BgEnd:ClearAllPoints()
	local distance = 3
	if direction == "UP" then
		FloFlyoutFrame.BgEnd:SetPoint("TOP")
		SetClampedTextureRotation(FloFlyoutFrame.BgEnd, 0)
		FloFlyoutFrame.HorizBg:Hide()
		FloFlyoutFrame.VertBg:Show()
		FloFlyoutFrame.VertBg:ClearAllPoints()
		FloFlyoutFrame.VertBg:SetPoint("TOP", FloFlyoutFrame.BgEnd, "BOTTOM")
		FloFlyoutFrame.VertBg:SetPoint("BOTTOM", 0, distance)
	elseif direction == "DOWN" then
		FloFlyoutFrame.BgEnd:SetPoint("BOTTOM")
		SetClampedTextureRotation(FloFlyoutFrame.BgEnd, 180)
		FloFlyoutFrame.HorizBg:Hide()
		FloFlyoutFrame.VertBg:Show()
		FloFlyoutFrame.VertBg:ClearAllPoints()
		FloFlyoutFrame.VertBg:SetPoint("BOTTOM", self.BgEnd, "TOP")
		FloFlyoutFrame.VertBg:SetPoint("TOP", 0, -distance)
	elseif direction == "LEFT" then
		FloFlyoutFrame.BgEnd:SetPoint("LEFT")
		SetClampedTextureRotation(FloFlyoutFrame.BgEnd, 270)
		FloFlyoutFrame.VertBg:Hide()
		FloFlyoutFrame.HorizBg:Show()
		FloFlyoutFrame.HorizBg:ClearAllPoints()
		FloFlyoutFrame.HorizBg:SetPoint("LEFT", FloFlyoutFrame.BgEnd, "RIGHT")
		FloFlyoutFrame.HorizBg:SetPoint("RIGHT", -distance, 0)
	elseif direction == "RIGHT" then
		FloFlyoutFrame.BgEnd:SetPoint("RIGHT")
		SetClampedTextureRotation(FloFlyoutFrame.BgEnd, 90)
		FloFlyoutFrame.VertBg:Hide()
		FloFlyoutFrame.HorizBg:Show()
		FloFlyoutFrame.HorizBg:ClearAllPoints()
		FloFlyoutFrame.HorizBg:SetPoint("RIGHT", FloFlyoutFrame.BgEnd, "LEFT")
		FloFlyoutFrame.HorizBg:SetPoint("LEFT", distance, 0)
	end
	FloFlyoutFrame:SetBorderColor(0.7, 0.7, 0.7)
end

local snippet_Opener_Click = [=[
	local ref = self:GetFrameRef("FloFlyoutFrame")
	local direction = self:GetAttribute("flyoutDirection")
	local prevButton = nil;

	if ref:IsShown() and ref:GetParent() == self then
		ref:Hide()
	else
		ref:SetParent(self)
		ref:ClearAllPoints()
		if direction == "UP" then
			ref:SetPoint("BOTTOM", self, "TOP", 0, 0)
		elseif direction == "DOWN" then
			ref:SetPoint("TOP", self, "BOTTOM", 0, 0)
		elseif direction == "LEFT" then
			ref:SetPoint("RIGHT", self, "LEFT", 0, 0)
		elseif direction == "RIGHT" then
			ref:SetPoint("LEFT", self, "RIGHT", 0, 0)
		end

		local spellList = table.new(strsplit(",", self:GetAttribute("spelllist")))
		local buttonList = table.new(ref:GetChildren())
		for i, buttonRef in ipairs(buttonList) do
			if spellList[i] then
				buttonRef:ClearAllPoints()
				if direction == "UP" then
					if prevButton then
						buttonRef:SetPoint("BOTTOM", prevButton, "TOP", 0, ]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[)
					else
						buttonRef:SetPoint("BOTTOM", "$parent", 0, ]=]..SPELLFLYOUT_INITIAL_SPACING..[=[)
					end
				elseif direction == "DOWN" then
					if prevButton then
						buttonRef:SetPoint("TOP", prevButton, "BOTTOM", 0, -]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[)
					else
						buttonRef:SetPoint("TOP", "$parent", 0, -]=]..SPELLFLYOUT_INITIAL_SPACING..[=[)
					end
				elseif direction == "LEFT" then
					if prevButton then
						buttonRef:SetPoint("RIGHT", prevButton, "LEFT", -]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[, 0)
					else
						buttonRef:SetPoint("RIGHT", "$parent", -]=]..SPELLFLYOUT_INITIAL_SPACING..[=[, 0)
					end
				elseif direction == "RIGHT" then
					if prevButton then
						buttonRef:SetPoint("LEFT", prevButton, "RIGHT", ]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[, 0)
					else
						buttonRef:SetPoint("LEFT", "$parent", ]=]..SPELLFLYOUT_INITIAL_SPACING..[=[, 0)
					end
				end

				buttonRef:SetAttribute("type", "spell")
				buttonRef:SetAttribute("spell", spellList[i])
				buttonRef:Show()

				prevButton = buttonRef
			else
				buttonRef:Hide()
			end
		end
		local numButtons = table.maxn(spellList)
		if direction == "UP" or direction == "DOWN" then
			ref:SetWidth(prevButton:GetWidth())
			ref:SetHeight((prevButton:GetHeight()+]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[) * numButtons - ]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[ + ]=]..SPELLFLYOUT_INITIAL_SPACING..[=[ + ]=]..SPELLFLYOUT_FINAL_SPACING..[=[)
		else
			ref:SetHeight(prevButton:GetHeight())
			ref:SetWidth((prevButton:GetWidth()+]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[) * numButtons - ]=]..SPELLFLYOUT_DEFAULT_SPACING..[=[ + ]=]..SPELLFLYOUT_INITIAL_SPACING..[=[ + ]=]..SPELLFLYOUT_FINAL_SPACING..[=[)
		end
		ref:Show()
		ref:RegisterAutoHide(1)
		ref:AddToAutoHide(self)
	end
]=]

function FloFlyout:CreateOpener(name, idFlyout, direction, actionButton, actionBarPage, bonusBar)

	local opener = self.openers[name] or CreateFrame("Button", name, UIParent, "ActionButtonTemplate, SecureHandlerClickTemplate")
	self.openers[name] = opener

	opener:SetAllPoints(actionButton)
	opener:SetFrameStrata("DIALOG")

	opener:SetAttribute("flyoutDirection", direction)
	opener:SetFrameRef("FloFlyoutFrame", FloFlyoutFrame)
	opener:SetAttribute("spelllist", strjoin(",", unpack(self.config.flyouts[idFlyout].spells)))

	opener:SetScript("OnUpdate", Opener_UpdateFlyout)
	opener:SetScript("OnEnter", Opener_UpdateFlyout)
	opener:SetScript("OnLeave", Opener_UpdateFlyout)

	opener:SetScript("PreClick", Opener_PreClick)
	opener:SetAttribute("_onclick", snippet_Opener_Click)
	opener:RegisterForClicks("AnyUp")

	local icon = _G[opener:GetName().."Icon"]
	if self.config.flyouts[idFlyout].icon then
		icon:SetTexture(self.config.flyouts[idFlyout].icon)
	elseif self.config.flyouts[idFlyout].spells[1] then
		local texture = GetSpellTexture(self.config.flyouts[idFlyout].spells[1])
		icon:SetTexture(texture)
	end

	local stateCondition = ""
	if actionBarPage then
		stateCondition = "bar:"..actionBarPage
	end
	if bonusBar then
		stateCondition = stateCondition..",bonusbar:"..bonusBar
	end
	if stateCondition ~= "" then
		RegisterStateDriver(opener, "visibility", "["..stateCondition.."] show; hide")
	else
		opener:Show()
	end
end

function FloFlyout:ClearOpeners()
	for name, opener in pairs(self.openers) do
		opener:Hide()
		UnregisterStateDriver(opener, "visibility")
	end
end

function FloFlyout:ApplyConfig()
	self:ClearOpeners()
	for a,f in pairs(self.config.actions[GetActiveTalentGroup()]) do
		self:BindFlyoutToAction(f, a)
	end
end

function FloFlyout:IsValidFlyoutId(arg1)
	local id = tonumber(arg1)
	return id and self.config.flyouts[id]
end

function FloFlyout:IsValidSpellPos(flyoutId, arg2)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	local pos = tonumber(arg2)
	return pos and self.config.flyouts[flyoutId].spells[pos]
end

function FloFlyout:AddFlyout()
	table.insert(self.config.flyouts, { spells = {} })
	return #self.config.flyouts
end

function FloFlyout:RemoveFlyout(flyoutId)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	table.remove(self.config.flyouts, flyoutId)
	-- shift references
	local i, a, f
	for i = 1, 2 do
		for a,f in pairs(self.config.actions[i]) do
			if f == flyoutId then
				self.config.actions[i][a] = nil
			elseif f > flyoutId then
				self.config.actions[i][a] = f - 1
			end
		end
	end
end

function FloFlyout:AddSpell(flyoutId, spell)
	local spellId
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	if type(spell) == "string" then spellId = tonumber(spell) end
	table.insert(self.config.flyouts[flyoutId].spells, spellId or spell)
	return #self.config.flyouts[flyoutId].spells
end

function FloFlyout:RemoveSpell(flyoutId, spellPos)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	if type(spellPos) == "string" then spellPos = tonumber(spellPos) end
	table.remove(self.config.flyouts[flyoutId].spells, spellPos)
end

function FloFlyout:AddAction(actionId, flyoutId)
	if type(actionId) == "string" then actionId = tonumber(actionId) end
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	self.config.actions[GetActiveTalentGroup()][actionId] = flyoutId
end

function FloFlyout:RemoveAction(actionId)
	if type(actionId) == "string" then actionId = tonumber(actionId) end
	self.config.actions[GetActiveTalentGroup()][actionId] = nil
end

function FloFlyoutConfigPane_OnLoad(self)
	HybridScrollFrame_OnLoad(self)
	self.update = FloFlyoutConfigPane_Update
	DEFAULT_CHAT_FRAME:AddMessage( self:GetName().." "..self:GetHeight() )
	HybridScrollFrame_CreateButtons(self, "FloFlyoutConfigButtonTemplate")
end

function FloFlyoutConfigPane_OnShow(self)
	DEFAULT_CHAT_FRAME:AddMessage( self:GetName().." "..self:GetHeight() )
	HybridScrollFrame_CreateButtons(self, "FloFlyoutConfigButtonTemplate")
	FloFlyoutConfigPane_Update()
end

function FloFlyoutConfigPane_OnHide(self)
	FloFlyoutConfigDialogPopup:Hide()
end

function FloFlyoutConfigPane_OnUpdate(self)
	for i = 1, #self.buttons do
		local button = self.buttons[i]
		if button:IsMouseOver() then
			if button.name then
				button.DeleteButton:Show()
				button.EditButton:Show()
			else
				button.DeleteButton:Hide()
				button.EditButton:Hide()
			end
			button.HighlightBar:Show()
		else
			button.DeleteButton:Hide()
			button.EditButton:Hide()
			button.HighlightBar:Hide()
		end
	end
end

function FloFlyoutConfigPane_Update()
	local numRows = #FloFlyout.config.flyouts + 1
	HybridScrollFrame_Update(FloFlyoutConfigPane, numRows * EQUIPMENTSET_BUTTON_HEIGHT + 20, FloFlyoutConfigPane:GetHeight())
	
	local scrollOffset = HybridScrollFrame_GetOffset(FloFlyoutConfigPane)
	local buttons = FloFlyoutConfigPane.buttons
	local selectedIdx = FloFlyoutConfigPane.selectedIdx
	local name, texture, button, flyout
	for i = 1, #buttons do
		if i+scrollOffset <= numRows then
			button = buttons[i]
			buttons[i]:Show()
			button:Enable()
			
			if i+scrollOffset < numRows then
				-- Normal flyout button
				button.name = i+scrollOffset
				button.text:SetText(button.name);
				button.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
				flyout = FloFlyout.config.flyouts[i+scrollOffset]
				texture = flyout.icon

				if not texture and flyout.spells[1] then
					texture = GetSpellTexture(flyout.spells[1])
				end
				if texture then
					button.icon:SetTexture(texture)
				else
					button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				end
							
				if selectedIdx and (i+scrollOffset) == selectedIdx then
					button.SelectedBar:Show()
				else
					button.SelectedBar:Hide()
				end
				
				button.icon:SetSize(36, 36)
				button.icon:SetPoint("LEFT", 4, 0)
			else
				-- This is the Add New button
				button.name = nil
				button.text:SetText(PAPERDOLL_NEWEQUIPMENTSET)
				button.text:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
				button.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
				button.icon:SetSize(30, 30)
				button.icon:SetPoint("LEFT", 7, 0)
				button.SelectedBar:Hide()
			end
			
			if (i+scrollOffset) == 1 then
				buttons[i].BgTop:Show()
				buttons[i].BgMiddle:SetPoint("TOP", buttons[i].BgTop, "BOTTOM")
			else
				buttons[i].BgTop:Hide()
				buttons[i].BgMiddle:SetPoint("TOP")
			end
			
			if (i+scrollOffset) == numRows then
				buttons[i].BgBottom:Show()
				buttons[i].BgMiddle:SetPoint("BOTTOM", buttons[i].BgBottom, "TOP")
			else
				buttons[i].BgBottom:Hide()
				buttons[i].BgMiddle:SetPoint("BOTTOM")
			end
			
			if (i+scrollOffset)%2 == 0 then
				buttons[i].Stripe:SetTexture(STRIPE_COLOR.r, STRIPE_COLOR.g, STRIPE_COLOR.b)
				buttons[i].Stripe:SetAlpha(0.1)
				buttons[i].Stripe:Show()
			else
				buttons[i].Stripe:Hide()
			end
		else
			buttons[i]:Hide()
		end
	end

end

function FloFlyoutConfigButton_OnClick(self, button, down)
	if self.name and self.name ~= "" then
		PlaySound("igMainMenuOptionCheckBoxOn")		-- inappropriately named, but a good sound.
		FloFlyoutConfigPane.selectedIdx = self.name
		FloFlyoutConfigPane_Update()
		FloFlyoutConfigDialogPopup:Hide()
	else
		-- This is the "New" button
		FloFlyoutConfigDialogPopup:Show()
		FloFlyoutConfigPane.selectedIdx = nil
		FloFlyoutConfigPane_Update()
	end
end

local NUM_FLYOUT_ICONS_SHOWN = 15
local NUM_FLYOUT_ICONS_PER_ROW = 5
local NUM_FLYOUT_ICON_ROWS = 3
local FLYOUT_ICON_ROW_HEIGHT = 36
local FC_ICON_FILENAMES = {}

function FloFlyoutConfigDialogPopup_OnLoad (self)
	self.buttons = {}
	
	local rows = 0
	
	local button = CreateFrame("CheckButton", "FloFlyoutConfigDialogPopupButton1", FloFlyoutConfigDialogPopup, "FloFlyoutConfigPopupButtonTemplate")
	button:SetPoint("TOPLEFT", 24, -37)
	button:SetID(1)
	tinsert(self.buttons, button)
	
	local lastPos
	for i = 2, NUM_FLYOUT_ICONS_SHOWN do
		button = CreateFrame("CheckButton", "FloFlyoutConfigDialogPopupButton" .. i, FloFlyoutConfigDialogPopup, "FloFlyoutConfigPopupButtonTemplate")
		button:SetID(i)
		
		lastPos = (i - 1) / NUM_FLYOUT_ICONS_PER_ROW
		if lastPos == math.floor(lastPos) then
			button:SetPoint("TOPLEFT", self.buttons[i-NUM_FLYOUT_ICONS_PER_ROW], "BOTTOMLEFT", 0, -8)
		else
			button:SetPoint("TOPLEFT", self.buttons[i-1], "TOPRIGHT", 10, 0)
		end
		tinsert(self.buttons, button)
	end

	self.SetSelection = function(self, fTexture, Value)
		if fTexture then
			self.selectedTexture = Value
			self.selectedIcon = nil
		else
			self.selectedTexture = nil
			self.selectedIcon = Value
		end
	end
end

function FloFlyoutConfigDialogPopup_OnShow(self)
	PlaySound("igCharacterInfoOpen")
	self.name = nil
	self.isEdit = false
	RecalculateFloFlyoutConfigDialogPopup()
end

function FloFlyoutConfigDialogPopup_OnHide(self)
	FloFlyoutConfigDialogPopup.name = nil
	FloFlyoutConfigDialogPopup:SetSelection(true, nil)
	--FloFlyoutConfigDialogPopupEditBox:SetText("")
	FC_ICON_FILENAMES = nil
	collectgarbage()
end

function RecalculateFloFlyoutConfigDialogPopup(iconTexture)
	local popup = FloFlyoutConfigDialogPopup;
	
	if iconTexture then
		popup:SetSelection(true, iconTexture)
	else
		popup:SetSelection(false, 1)
	end
	
	--[[ 
	Scroll and ensure that any selected equipment shows up in the list.
	When we first press "save", we want to make sure any selected equipment set shows up in the list, so that
	the user can just make his changes and press Okay to overwrite.
	To do this, we need to find the current set (by icon) and move the offset of the FloFlyoutConfigDialogPopup
	to display it. Issue ID: 171220
	]]
	RefreshFlyoutIconInfo()
	local totalItems = #FC_ICON_FILENAMES
	local texture, _
	if popup.selectedTexture then
		local foundIndex = nil
		for index=1, totalItems do
			texture = GetFlyoutIconInfo(index)
			if string.upper(texture) == popup.selectedTexture then
				foundIndex = index
				break
			end
		end
		if foundIndex == nil then
			foundIndex = 1
		end
		-- now make it so we always display at least NUM_FLYOUT_ICON_ROWS of data
		local offsetnumIcons = floor((totalItems-1)/NUM_FLYOUT_ICONS_PER_ROW)
		local offset = floor((foundIndex-1) / NUM_FLYOUT_ICONS_PER_ROW)
		offset = offset + min((NUM_FLYOUT_ICON_ROWS-1), offsetnumIcons-offset) - (NUM_FLYOUT_ICON_ROWS-1)
		if foundIndex<=NUM_FLYOUT_ICONS_SHOWN then
			offset = 0			--Equipment all shows at the same place.
		end
		FauxScrollFrame_OnVerticalScroll(FloFlyoutConfigDialogPopupScrollFrame, offset*FLYOUT_ICON_ROW_HEIGHT, FLYOUT_ICON_ROW_HEIGHT, nil);
	else
		FauxScrollFrame_OnVerticalScroll(FloFlyoutConfigDialogPopupScrollFrame, 0, FLYOUT_ICON_ROW_HEIGHT, nil);
	end
	FloFlyoutConfigDialogPopup_Update()
end

--[[
RefreshFlyoutIconInfo() counts how many uniquely textured spells the player has in the current flyout. 
]]
function RefreshFlyoutIconInfo ()
	FC_ICON_FILENAMES = {}
	FC_ICON_FILENAMES[1] = "INV_MISC_QUESTIONMARK"
	local index = 2

	local popup = FloFlyoutConfigDialogPopup
	if popup.name then
		local i
		local spells = FloFlyout.config.flyouts[popup.name].spells
		for i = 1, #spells do
			local itemTexture = GetSpellTexture(spells[i])
			if itemTexture then
				FC_ICON_FILENAMES[index] = gsub( strupper(itemTexture), "INTERFACE\\ICONS\\", "" )
				if FC_ICON_FILENAMES[index] then
					index = index + 1
					for j=1, (index-1) do
						if FC_ICON_FILENAMES[index] == FC_ICON_FILENAMES[j] then
							FC_ICON_FILENAMES[index] = nil
							index = index - 1
							break
						end
					end
				end
			end
		end
	end
	GetMacroIcons(FC_ICON_FILENAMES)
	GetMacroItemIcons(FC_ICON_FILENAMES)
end

function GetFlyoutIconInfo(index)
	return FC_ICON_FILENAMES[index]
end

function FloFlyoutConfigDialogPopup_Update()
	RefreshFlyoutIconInfo()

	local popup = FloFlyoutConfigDialogPopup
	local buttons = popup.buttons
	local offset = FauxScrollFrame_GetOffset(FloFlyoutConfigDialogPopupScrollFrame) or 0
	local button
	-- Icon list
	local texture, index, button, realIndex, _
	for i=1, NUM_FLYOUT_ICONS_SHOWN do
		local button = buttons[i]
		index = (offset * NUM_FLYOUT_ICONS_PER_ROW) + i
		if index <= #FC_ICON_FILENAMES then
			texture = GetFlyoutIconInfo(index)

			button.icon:SetTexture("INTERFACE\\ICONS\\"..texture)
			button:Show()
			if index == popup.selectedIcon then
				button:SetChecked(1)
			elseif string.upper(texture) == popup.selectedTexture then
				button:SetChecked(1)
				popup:SetSelection(false, index)
			else
				button:SetChecked(nil)
			end
		else
			button.icon:SetTexture("")
			button:Hide()
		end
		
	end
	
	-- Scrollbar stuff
	FauxScrollFrame_Update(FloFlyoutConfigDialogPopupScrollFrame, ceil(#FC_ICON_FILENAMES / NUM_FLYOUT_ICONS_PER_ROW), NUM_FLYOUT_ICON_ROWS, FLYOUT_ICON_ROW_HEIGHT)
end

function FloFlyoutConfigDialogPopupOkay_Update()
	local popup = FloFlyoutConfigDialogPopup
	local button = FloFlyoutConfigDialogPopupOkay
	
	if popup.selectedIcon --[[and popup.name]] then
		button:Enable()
	else
		button:Disable()
	end
end

function FloFlyoutConfigDialogPopupOkay_OnClick(self, button, pushed)
	local popup = FloFlyoutConfigDialogPopup
	local iconTexture
	if popup.selectedIcon ~= 1 then
		iconTexture = "INTERFACE\\ICONS\\"..GetFlyoutIconInfo(popup.selectedIcon)
	end

	if popup.isEdit then
		-- Modifying a flyout
		FloFlyout.config.flyouts[popup.name].icon = iconTexture
	else
		-- Saving a new flyout
		FloFlyout.config.flyouts[FloFlyout:AddFlyout()].icon = iconTexture
	end
	popup:Hide()
	FloFlyoutConfigPane_Update()
	FloFlyout:ApplyConfig()
end

function FloFlyoutConfigDialogPopupCancel_OnClick ()
	FloFlyoutConfigDialogPopup:Hide()
end

function FloFlyoutConfigPopupButton_OnClick(self, button, down)
	local popup = FloFlyoutConfigDialogPopup
	local offset = FauxScrollFrame_GetOffset(FloFlyoutConfigDialogPopupScrollFrame) or 0
	popup.selectedIcon = (offset * NUM_FLYOUT_ICONS_PER_ROW) + self:GetID()
 	popup.selectedTexture = nil
	FloFlyoutConfigDialogPopup_Update()
	FloFlyoutConfigDialogPopupOkay_Update()
end


