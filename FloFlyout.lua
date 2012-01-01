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

local FloFlyout = {
	openers = {},
	config = {
		[1] = {
			spells = {
				[1] = 8024,
				[2] = 8033,
				[3] = 8232,
				[4] = 8017,
				[5] = 51730,
			}
		},
	}
}

-------------------------------------------------------------------------------
-- Functions
-------------------------------------------------------------------------------

-- Executed on load, calls general set-up functions
function FloFlyout_OnLoad(self)

	DEFAULT_CHAT_FRAME:AddMessage( NAME.." "..VERSION.." loaded." )

	--SLASH_FLOTOTEMBAR1 = "/flototembar"
	--SLASH_FLOTOTEMBAR2 = "/ftb"
	--SlashCmdList["FLOTOTEMBAR"] = FloTotemBar_ReadCmd

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
		-- Initialise des trucs en dur pour commencer
		FloFlyout:BindFlyoutToAction(1, 13)
		FloFlyout:BindFlyoutToAction(1, 49)
		FloFlyout:BindFlyoutToAction(1, 25)

	--elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_USABLE" then

	elseif event == "ADDON_LOADED" and arg1 == NAME then

		-- Ici, nous avons rechargé notre configuration

	elseif event == "UPDATE_BINDINGS" then

	elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then

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

	local direction, actionButton, actionBarPage
	direction = "UP"

	if idAction <= 12 then
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
	end

	FloFlyout:CreateOpener("FloFlyoutOpener"..idAction, idFlyout, direction, actionButton, actionBarPage)
end

function FloFlyout:CreateOpener(name, idFlyout, direction, actionButton, actionBarPage)

	local floFlyoutFrame = _G["FloFlyoutFrame"]
	local opener = CreateFrame("Button", name, UIParent, "ActionButtonTemplate, SecureHandlerClickTemplate")
	self.openers[name] = opener
	opener:SetAllPoints(actionButton)
	opener:SetFrameStrata("DIALOG")
	opener:SetAttribute("_onclick", [=[
		local ref = self:GetFrameRef("FloFlyoutFrame")
		local direction = "]=]..direction..[=["
		local prevButton = nil;

		if ref:IsShown() then
			ref:Hide()
		else
			ref:Show()
			ref:RegisterAutoHide(1)
			ref:AddToAutoHide(self)
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
		end
	]=])
	opener:RegisterForClicks("AnyUp")
	opener:SetFrameRef("FloFlyoutFrame", floFlyoutFrame)
	opener:SetAttribute("spelllist", strjoin(",", unpack(self.config[idFlyout].spells)))
	opener:SetScript("PreClick", function(self, button, down)
		local spellList = { strsplit(",", self:GetAttribute("spelllist")) }
		local buttonList = { floFlyoutFrame:GetChildren() }
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
		floFlyoutFrame.BgEnd:ClearAllPoints()
		local distance = 3
		if direction == "UP" then
			floFlyoutFrame.BgEnd:SetPoint("TOP")
			SetClampedTextureRotation(floFlyoutFrame.BgEnd, 0)
			floFlyoutFrame.HorizBg:Hide()
			floFlyoutFrame.VertBg:Show()
			floFlyoutFrame.VertBg:ClearAllPoints()
			floFlyoutFrame.VertBg:SetPoint("TOP", floFlyoutFrame.BgEnd, "BOTTOM")
			floFlyoutFrame.VertBg:SetPoint("BOTTOM", 0, distance)
		elseif direction == "DOWN" then
			floFlyoutFrame.BgEnd:SetPoint("BOTTOM")
			SetClampedTextureRotation(floFlyoutFrame.BgEnd, 180)
			floFlyoutFrame.HorizBg:Hide()
			floFlyoutFrame.VertBg:Show()
			floFlyoutFrame.VertBg:ClearAllPoints()
			floFlyoutFrame.VertBg:SetPoint("BOTTOM", self.BgEnd, "TOP")
			floFlyoutFrame.VertBg:SetPoint("TOP", 0, -distance)
		elseif direction == "LEFT" then
			floFlyoutFrame.BgEnd:SetPoint("LEFT")
			SetClampedTextureRotation(floFlyoutFrame.BgEnd, 270)
			floFlyoutFrame.VertBg:Hide()
			floFlyoutFrame.HorizBg:Show()
			floFlyoutFrame.HorizBg:ClearAllPoints()
			floFlyoutFrame.HorizBg:SetPoint("LEFT", floFlyoutFrame.BgEnd, "RIGHT")
			floFlyoutFrame.HorizBg:SetPoint("RIGHT", -distance, 0)
		elseif direction == "RIGHT" then
			floFlyoutFrame.BgEnd:SetPoint("RIGHT")
			SetClampedTextureRotation(floFlyoutFrame.BgEnd, 90)
			floFlyoutFrame.VertBg:Hide()
			floFlyoutFrame.HorizBg:Show()
			floFlyoutFrame.HorizBg:ClearAllPoints()
			floFlyoutFrame.HorizBg:SetPoint("RIGHT", floFlyoutFrame.BgEnd, "LEFT")
			floFlyoutFrame.HorizBg:SetPoint("LEFT", distance, 0)
		end
		floFlyoutFrame:SetBorderColor(0.7, 0.7, 0.7)
	end)

	local icon = _G[opener:GetName().."Icon"]
	if self.config[idFlyout].icon then
		icon:SetTexture(self.config[idFlyout].icon)
	else
		local texture = GetSpellTexture(self.config[idFlyout].spells[1])
		icon:SetTexture(texture)
	end

	local flyoutArrow = _G[opener:GetName().."FlyoutArrow"]
	local arrowDistance = 2

	-- Update arrow
	flyoutArrow:Show()
	flyoutArrow:ClearAllPoints()
	if direction == "LEFT" then
		flyoutArrow:SetPoint("LEFT", opener, "LEFT", -arrowDistance, 0)
		SetClampedTextureRotation(flyoutArrow, 270)
	elseif direction == "RIGHT" then
		flyoutArrow:SetPoint("RIGHT", opener, "RIGHT", arrowDistance, 0)
		SetClampedTextureRotation(flyoutArrow, 90)
	elseif direction == "DOWN" then
		flyoutArrow:SetPoint("BOTTOM", opener, "BOTTOM", 0, -arrowDistance)
		SetClampedTextureRotation(flyoutArrow, 180)
	else
		flyoutArrow:SetPoint("TOP", opener, "TOP", 0, arrowDistance)
		SetClampedTextureRotation(flyoutArrow, 0)
	end

	if actionBarPage then
		RegisterStateDriver(opener, "visibility", "[bar:"..actionBarPage.."] show; hide")
	end
end

