-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local VERSION = "4.3.1"
local NAME = "FloFlyout"
local SPELLFLYOUT_DEFAULT_SPACING = 4;
local SPELLFLYOUT_INITIAL_SPACING = 7;
local SPELLFLYOUT_FINAL_SPACING = 4;

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
	};

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

