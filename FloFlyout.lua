-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this file,
-- You can obtain one at http://mozilla.org/MPL/2.0/.

local MY_NAME, MY_GLOBALS = ...
local L = FLOFLYOUT_L10N_STRINGS -- auto loaded from locales directory

FloFlyout = LibStub("AceAddon-3.0"):NewAddon(MY_NAME, "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
FloFlyout.openers = {} -- copies of flyouts that sit on the action bars

-------------------------------------------------------------------------------
-- Constants
-------------------------------------------------------------------------------

local VERSION = "10.0.16"
local NAME = MY_NAME
local MAX_FLYOUT_SIZE = 20
local NON_SPEC_SLOT = 5
local SPELLFLYOUT_DEFAULT_SPACING = 4
local SPELLFLYOUT_INITIAL_SPACING = 7
local SPELLFLYOUT_FINAL_SPACING = 4
local STRIPE_COLOR = {r=0.9, g=0.9, b=1}
local STRATA_DEFAULT = "MEDIUM"
local STRATA_MAX = "TOOLTIP"
local DUMMY_MACRO_NAME = "__ffodnd"
local MAX_GLOBAL_MACRO_ID = 120
local STRUCT_FLYOUT_DEF = { spells = {}, actionTypes = {}, mountIndex = {}, spellNames = {}, macroOwners = {} } -- "spell" can mean also item, mount, macro, etc.
local BLIZ_BAR_METADATA = {
	[1]  = {name="Action",              visibleIf="bar:1,nobonusbar:1,nobonusbar:2,nobonusbar:3,nobonusbar:4"}, -- primary "ActionBar" - page #1 - no stance/shapeshift --- ff: actionBarPage = 1
	[2]  = {name="Action",              visibleIf="bar:2"}, -- primary "ActionBar" - page #2 (regardless of stance/shapeshift) --- ff: actionBarPage = 2
	[3]  = {name="MultiBarRight",       classicType=2}, -- config UI -> Action Bars -> checkbox #4
	[4]  = {name="MultiBarLeft",        classicType=2}, -- config UI -> Action Bars -> checkbox #5
	[5]  = {name="MultiBarBottomRight", classicType=1}, -- config UI -> Action Bars -> checkbox #3
	[6]  = {name="MultiBarBottomLeft",  classicType=1}, -- config UI -> Action Bars -> checkbox #2
	[7]  = {name="Action",              visibleIf="bar:1,bonusbar:1"}, -- primary "ActionBar" - page #1 - bonusbar 1 - druid CAT
	[8]  = {name="Action",              visibleIf="bar:1,bonusbar:2"}, -- primary "ActionBar" - page #1 - bonusbar 2 - unknown?
	[9]  = {name="Action",              visibleIf="bar:1,bonusbar:3"}, -- primary "ActionBar" - page #1 - bonusbar 3 - druid BEAR
	[10] = {name="Action",              visibleIf="bar:1,bonusbar:4"}, -- primary "ActionBar" - page #1 - bonusbar 4 - druid MOONKIN
	[11] = {name="Action",              visibleIf="bar:1,bonusbar:5"}, -- primary "ActionBar" - page #1 - bonusbar 5 - dragon riding
	[12] = {name="Action",              visibleIf="bar:1,bonusbar:6"--[[just a guess]]}, -- unknown?
	[13] = {name="MultiBar5"}, -- config UI -> Action Bars -> checkbox #6
	[14] = {name="MultiBar6"}, -- config UI -> Action Bars -> checkbox #7
	[15] = {name="MultiBar7"}, -- config UI -> Action Bars -> checkbox #8
}

-- unique flyout definitions shown in the config panel
local DEFAULT_FLOFLYOUT_CONFIG = {
	flyouts = {
		--[[ Sample config : each flyout can have a list of actions and an icon
		[1] = {
			actionTypes = {
				[1] = "spell",
				[2] = "item",
				[3] = "macro",
				[4] = "pet"
			},
			spells,
				[1] = 8024, -- Flametongue
				[2] = 8033, -- Frostbite
				[3] = 8232, -- Windfury
				[4] = 8017, -- RockBite
				[5] = 51730, -- earthliving
			},
			icon = ""
		},
		[2] = { ... etc ... }, etc...
		]]
	},
}

-- assigned action bar button slots
local DEFAULT_PLACEMENTS_CONFIG = {
	-- each class spec has its own set of placements
	[1] = {
		-- config format:
		-- [action bar slot] = flyout Id
		-- each button on the bliz action bars has a slot ID which is which we place a flyout ID (see above)
		-- [13] = 1, -- button #13 holds flyout #1
		-- [49] = 3, -- button #49 holds flyout #3
		-- [125] = 2, -- button #125 holds flyout #2
	},
	[2] = {
	},
	[3] = {
	},
	[4] = {
	},
	-- spec-agnostic slot
	[5] = {
	},
}

-------------------------------------------------------------------------------
-- Variables
-------------------------------------------------------------------------------
local _
local _classicUI
local Db = nil -- initialized by Ace in OnInitialize

-------------------------------------------------------------------------------
-- Ace -> Bliz Config UI definition
-------------------------------------------------------------------------------

local escMenuConfigDef = {
	name = MY_NAME,
	type = "group",
	args = {
		respectSpec = {
			name = "Swap with spec",
			desc = "Auto swap flyout locations on the action bars when you change your class spec.",
			type = "toggle",
			set = function(info, val)
				Db.profile.respectSpec = val
			end,
			get = function()
				return Db.profile.respectSpec
			end
		},
		debug = {
			name = "Show debug info",
			desc = "Enable / disable debug information",
			type = "toggle",
			set = function(info, val)
				Db.profile.debug = val
			end,
			get = function()
				return Db.profile.debug
			end
		},
		--aceProfileUi = {} -- will be populated by Ace in OnInitialize()
	}
}

local defaultConfigOptions = {
	profile = { -- required by AceDB
		debug = false,
		respectSpec = true,
	}
}

-------------------------------------------------------------------------------
-- Ace Addon lifecycle
-------------------------------------------------------------------------------

-- called by Ace directly after the addon is fully loaded
function FloFlyout:OnInitialize()
	--print("FloFlyout:OnInitialize() aces! -- this happens after FloFlyout_OnLoad")

	-- AceDB manages SavedVariables and adds profile management -- must match the .toc ## SavedVariables
	Db = LibStub("AceDB-3.0"):New("FLOFLYOUT_ACCOUNT_CONFIG", defaultConfigOptions)

	-- grabs Ace's profile management UI def and adds it as another submenu of ours
	--escMenuConfigDef.args.aceProfileUi = LibStub("AceDBOptions-3.0"):GetOptionsTable(Db)

	-- Ace-only config registry (required by AceConfigDialog below).  Also adds slash commands {the, stuff, on, the, end}
	LibStub("AceConfig-3.0"):RegisterOptionsTable(MY_NAME, escMenuConfigDef, { "ff", MY_NAME, string.lower(MY_NAME) })

	-- inserts our custom config into the Bliz addon config UI
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions(MY_NAME)

	-- if the user switches to a different profile in the addon config options
	--Db.RegisterCallback(self, "OnProfileChanged", "HandleConfigChanges")
	--Db.RegisterCallback(self, "OnProfileCopied", "HandleConfigChanges")
	--Db.RegisterCallback(self, "OnProfileReset", "HandleConfigChanges")

	self:InitializeFlyoutConfigIfEmpty(true)
	self:InitializePlacementConfigIfEmpty(true)
	initializeOnClickHandlersForFlyouts()
end

--[[
-- called by Ace during the PLAYER_LOGIN event, when most of the data provided by the game is already present
function FloFlyoutAce:OnEnable()
end

-- called by Ace only when your addon is manually being disabled
function FloFlyoutAce:OnDisable()
end
]]

-------------------------------------------------------------------------------
-- FloFlyout Methods
-------------------------------------------------------------------------------

function FloFlyout:HandleConfigChanges()
	self:InitializeFlyoutConfigIfEmpty()
	self:InitializePlacementConfigIfEmpty()
	self:ApplyConfig()
end

function FloFlyout:InitializeFlyoutConfigIfEmpty(mayUseLegacyData)
	if self:GetFlyoutsConfig() then
		return
	end

	local flyouts

	-- support older versions of the addon
	local legacyData = mayUseLegacyData and FLOFLYOUT_CONFIG and FLOFLYOUT_CONFIG.flyouts
	if legacyData then
		flyouts = deepcopy(legacyData)
		fixLegacyFlyoutsNils(flyouts)
		FLOFLYOUT_CONFIG.flyouts_note = "the flyouts field is old and no longer used by the current version of this addon"
	else
		flyouts = deepcopy(DEFAULT_FLOFLYOUT_CONFIG)
	end

	self:PutFlyoutConfig(flyouts)
end

function FloFlyout:InitializePlacementConfigIfEmpty(mayUseLegacyData)
	if self:GetFlyoutPlacementsForToon() then
		return
	end

	local placementsForAllSpecs
	local legacyData = mayUseLegacyData and FLOFLYOUT_CONFIG and FLOFLYOUT_CONFIG.actions
	if legacyData then
		placementsForAllSpecs = deepcopy(legacyData)
		fixLegacyActionsNils(placementsForAllSpecs)
		FLOFLYOUT_CONFIG.actions_note = "the actions field is old and no longer used by the current version of this addon"
	else
		placementsForAllSpecs = deepcopy(DEFAULT_PLACEMENTS_CONFIG)
	end

	self:PutFlyoutPlacementsForToon(placementsForAllSpecs)
end

-- the flyout definitions are stored account-wide and thus shared between all toons
function FloFlyout:PutFlyoutConfig(flyouts)
	FLOFLYOUT_ACCOUNT_CONFIG.flyouts = flyouts
end

function FloFlyout:GetFlyoutsConfig()
	return FLOFLYOUT_ACCOUNT_CONFIG.flyouts
	--return Db.profile.flyouts
end

local doneChecked = {} -- flag for the GetFlyoutConfig() method

-- get and validate the requested flyout config
function FloFlyout:GetFlyoutConfig(flyoutId)
	local config = self:GetFlyoutsConfig()
	local flyoutConfig = config and (config[flyoutId])

	-- check that the data structure is complete
	-- because old versions of the addon may have saved less data than now needed
	-- but check each specific flyoutId only once
	if doneChecked[flyoutId] then return flyoutConfig end
	doneChecked[flyoutId] = true
	if not flyoutConfig then return nil end

	-- init any missing parts
	for k,_ in pairs(STRUCT_FLYOUT_DEF) do
		if not flyoutConfig[k] then

			flyoutConfig[k] = {}
		end
	end

	return flyoutConfig
end

function FloFlyout:GetSpecificConditionalFlyoutPlacements()
	local placements = self:GetFlyoutPlacementsForToon()
	local spec = self:GetSpecSlotId()
	return placements and placements[spec]
end

-- the placement of flyouts on the action bars is stored separately for each toon
function FloFlyout:PutFlyoutPlacementsForToon(flyoutPlacements)
	FLOFLYOUT_CONFIG.flyoutPlacements = flyoutPlacements

	--if not Db.profile.placementsPerToonAndSpec then
	--	Db.profile.placementsPerToonAndSpec = {}
	--end

	--local playerId = getIdForCurrentToon()
	--Db.profile.placementsPerToonAndSpec[playerId] = flyoutPlacements
end

function FloFlyout:GetFlyoutPlacementsForToon()
	return FLOFLYOUT_CONFIG.flyoutPlacements
	--local playerId = getIdForCurrentToon()
	--local ppts = Db.profile.placementsPerToonAndSpec
	--return ppts and ppts[playerId]
end

function getIdForCurrentToon()
	local name, realm = UnitFullName("player") -- FU Bliz, realm is arbitrarily nil sometimes but not always
	realm = GetRealmName()
	return name.." - "..realm
end

function FloFlyout:GetSpecSlotId()
	if 	Db.profile.respectSpec then
		return GetSpecialization()
	else
		return NON_SPEC_SLOT
	end
end

function initializeOnClickHandlersForFlyouts()
	for i, button in ipairs({FloFlyoutFrame:GetChildren()}) do
		if button:GetObjectType() == "CheckButton" then
			SecureHandlerWrapScript(button, "OnClick", button, "self:GetParent():Hide()")
		end
	end

	FloFlyoutConfigFlyoutFrame.IsConfig = true
end

function fixLegacyFlyoutsNils(flyouts)
	for _, flyout in ipairs(flyouts) do
		if flyout.actionTypes == nil then
			flyout.actionTypes = {}
			for i, _ in ipairs(flyout.spells) do
				flyout.actionTypes[i] = "spell"
			end
		end
		if flyout.mountIndex == nil then
			flyout.mountIndex = {}
		end
		if flyout.spellNames == nil then
			flyout.spellNames = {}
		end
	end
end

function fixLegacyActionsNils(actions)
	for i=3,5 do
		if actions[i] == nil then
			actions[i] = {}
		end
	end
end

function FloFlyout.ReadCmd(line)
	local cmd, arg1, arg2 = strsplit(' ', line or "", 3);

	if cmd == "addflyout" then
		DEFAULT_CHAT_FRAME:AddMessage("New flyout : "..FloFlyout:AddFlyout().flyoutId)
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
	elseif cmd == "apply" then
		FloFlyout:ApplyConfig()
	else
		DEFAULT_CHAT_FRAME:AddMessage(L["USAGE"]);
		return;
	end
end

-- Executed on load, calls general set-up functions
function FloFlyout_OnLoad(self)
	--print("FloFlyout_OnLoad() -- this happens before Ace's FloFlyout:OnInitialize")

	DEFAULT_CHAT_FRAME:AddMessage( "|cffd78900"..NAME.." v"..VERSION.."|r loaded." )

	SLASH_FLOFLYOUT1 = "/floflyout"
	SLASH_FLOFLYOUT2 = "/ffo"
	SlashCmdList["FLOFLYOUT"] = FloFlyout.ReadCmd

	StaticPopupDialogs["CONFIRM_DELETE_FLO_FLYOUT"] = {
		text = L["CONFIRM_DELETE"],
		button1 = YES,
		button2 = NO,
		OnAccept = function (self) FloFlyout:RemoveFlyout(self.data); FloFlyout.ConfigPane_Update(); FloFlyout:ApplyConfig(); end,
		OnCancel = function (self) end,
		hideOnEscape = 1,
		timeout = 0,
		exclusive = 1,
		whileDead = 1,
	}

	-- self:RegisterEvent("ADDON_LOADED") -- replaced with Ace
	self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	--self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")

	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_ALIVE")
	self:RegisterEvent("UPDATE_BINDINGS")
	self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

	_classicUI = _G["ClassicUI"]
	if _classicUI then
		DEFAULT_CHAT_FRAME:AddMessage( NAME.." : |cffd78900ClassicUI v".._classicUI.VERSION.."|r detected." )
		local cuipew = _classicUI.MF_PLAYER_ENTERING_WORLD
		_classicUI.MF_PLAYER_ENTERING_WORLD = function (cui)
			cuipew(cui)
			FloFlyout:ApplyConfig()
		end
	end

end

function FloFlyout_OnEvent(FloFlyoutListener, event, arg1, ...)

	if event == "PLAYER_ENTERING_WORLD" --[[or event == "PLAYER_ALIVE"]] then

		if not _classicUI or not _classicUI:IsEnabled() then
			FloFlyout:ApplyConfig()
		end

		--elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_USABLE" then

	elseif event == "ACTIONBAR_SLOT_CHANGED" then
		local idAction = arg1
		-- Dans tous les cas, si nous avions un flyout sur cette action, il faut l'enlever de l'action et le mettre dans le curseur
		local configChanged
		local oldFlyoutId = FloFlyout:GetSpecificConditionalFlyoutPlacements()[idAction]

		local actionType, id, subType = GetActionInfo(idAction)
		-- Si actionType vide, c'est sans doute que l'on vient de détruire la macro bidon
		if not actionType then
			return
		elseif actionType == "macro" then
			local name, texture, body = GetMacroInfo(id)
			--print("GetMacroInfo: for ID = ", id, "name =",name, "texture =",texture, "body =",body)
			if name == DUMMY_MACRO_NAME then
				FloFlyout:AddAction(idAction, body)
				-- La pseudo macro a fait son travail
				DeleteMacro(DUMMY_MACRO_NAME)
				configChanged = true
			end
		end
		if oldFlyoutId then
			FloFlyout:PickupFlyout(oldFlyoutId)
			if not configChanged then
				FloFlyout:RemoveAction(idAction)
				configChanged = true
			end
		end
		if configChanged then
			FloFlyout:ApplyConfig()
		end

	elseif event == "UPDATE_BINDINGS" then

	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		FloFlyout:ApplyConfig()

	else

	end
end

function FloFlyout:ApplyOperationToAllOpenerInstancesUnlessInCombat(callback)
	if InCombatLockdown() then return end
	self:ApplyOperationToAllOpenerInstances(callback)
end

function FloFlyoutFrame_OnEvent(self, event, ...)
	if event == "SPELL_UPDATE_COOLDOWN" then
		local i = 1
		local button = _G[self:GetName().."Button"..i]
		while (button and button:IsShown() and not isEmpty(button.spellID)) do
			SpellFlyoutButton_UpdateCooldown(button)
			i = i+1
			button = _G[self:GetName().."Button"..i]
		end
	elseif event == "CURRENT_SPELL_CAST_CHANGED" then
		local i = 1
		local button = _G[self:GetName().."Button"..i]
		while (button and button:IsShown() and button.spellID) do
			SpellFlyoutButton_UpdateState(button)
			i = i+1
			button = _G[self:GetName().."Button"..i]
		end
	elseif event == "SPELL_UPDATE_USABLE" then
		local i = 1
		local button = _G[self:GetName().."Button"..i]
		while (button and button:IsShown() and button.spellID) do
			SpellFlyoutButton_UpdateUsable(button)
			i = i+1
			button = _G[self:GetName().."Button"..i]
		end
	elseif event == "BAG_UPDATE" then
		local i = 1
		local button = _G[self:GetName().."Button"..i]
		while (button and button:IsShown() and button.spellID) do
			SpellFlyoutButton_UpdateCount(button)
			SpellFlyoutButton_UpdateUsable(button)
			i = i+1
			button = _G[self:GetName().."Button"..i]
		end
	elseif event == "SPELL_FLYOUT_UPDATE" then
		local i = 1
		local button = _G[self:GetName().."Button"..i]
		while (button and button:IsShown() and button.spellID) do
			SpellFlyoutButton_UpdateCooldown(button)
			SpellFlyoutButton_UpdateState(button)
			SpellFlyoutButton_UpdateUsable(button)
			SpellFlyoutButton_UpdateCount(button)
			i = i+1
			button = _G[self:GetName().."Button"..i]
		end
	end
end

function getTexture(actionType, id)
	if actionType == "spell" then
		return GetSpellTexture(id)
	elseif actionType == "item" then
		return GetItemIcon(id)
	elseif actionType == "macro" then
		local _, texture, _ = GetMacroInfo(id)
		return texture
	end
end

function getItemOrSpellNameById(actionType, id)
	if actionType == "spell" then
		return GetSpellInfo(id)
	elseif actionType == "item" then
		return GetItemInfo(id)
	elseif actionType == "macro" then
		local name, _, _ = GetMacroInfo(id)
		return name
	end
end

function isThingyUsable(id, actionType, mountId, macroOwner)
	if mountId then
		-- TODO: figure out how to find a mount
		return true -- GetMountInfoByID(mountId)
	elseif actionType == "spell" then
		return IsSpellKnown(id)
	elseif  actionType == "item" then
		local n = GetItemCount(id)
		local t = PlayerHasToy(id) -- TODO: update the config code so it sets actionType = toy
		return t or n > 0
	elseif actionType == "macro" then
		return isMacroGlobal(id) or getIdForCurrentToon() == macroOwner
	end
end

function isMacroGlobal(macroId)
	return macroId <= MAX_GLOBAL_MACRO_ID
end

function FloFlyout:BindFlyoutToAction(ffUniqueId, slotIndex)
	-- examine the action/bonus/multi bar
	local barNum = ActionButtonUtil.GetPageForSlot(slotIndex)
	local blizBarDef = BLIZ_BAR_METADATA[barNum]
	assert(blizBarDef, "No "..MY_NAME.." config defined for button bar #"..barNum) -- in case Blizzard adds more bars, complain here clearly.
	local blizBarName = blizBarDef.name
	local visibleIf = blizBarDef.visibleIf
	local typeActionButton = blizBarDef.classicType -- for WoW classic

	-- examine the button
	local btnNum = (slotIndex % NUM_ACTIONBAR_BUTTONS)  -- defined in bliz internals ActionButtonUtil.lua
	if (btnNum == 0) then btnNum = NUM_ACTIONBAR_BUTTONS end -- button #12 divided by 12 is 1 remainder 0.  Thus, treat a 0 as a 12
	local btnName = blizBarName .. "Button" .. btnNum
	local btnObj = _G[btnName] -- grab the button object from Blizzard's GLOBAL dumping ground

	-- ask the bar instance what direction to fly
	local barObj = btnObj and btnObj.bar
	local direction = barObj and barObj:GetSpellFlyoutDirection() or "UP" -- TODO: fix bug where edit-mode -> change direction doesn't automatically update existing openers

	--local foo = btnObj and "FOUND" or "NiL"
	--print ("###--->>> ffUniqueId =", ffUniqueId, "barNum =",barNum, "slotId = ", slotIndex, "btnObj =",foo, "blizBarName = ",blizBarName,  "btnName =",btnName,  "btnNum =",btnNum, "direction =",direction, "visibleIf =", visibleIf)

	self:CreateOpener(slotIndex, ffUniqueId, direction, btnObj, visibleIf, typeActionButton)
end

function Opener_OnReceiveDrag(self)
	if InCombatLockdown() then
		return
	end

	local cursor = GetCursorInfo()
	if cursor then
		PlaceAction(self.actionId)
	end
end

function Opener_OnDragStart(self)
	if not InCombatLockdown() and (LOCK_ACTIONBAR ~= "1" or IsShiftKeyDown()) then
		FloFlyout:PickupFlyout(self.flyoutId)
		FloFlyout:RemoveAction(self.actionId)
		FloFlyout:ApplyConfig()
	end
end

function Opener_UpdateFlyout(self)
	-- print("========== Opener_UpdateFlyout()") this is being called continuously while a flyout exists on any bar
	-- Update border and determine arrow position
	local arrowDistance;
	-- Update border
	local isMouseOverButton =  GetMouseFocus() == self;
	local isFlyoutShown = FloFlyoutFrame and FloFlyoutFrame:IsShown() and FloFlyoutFrame:GetParent() == self;
	if isFlyoutShown or isMouseOverButton then
		self.FlyoutBorderShadow:Show();
		arrowDistance = 5;
	else
		self.FlyoutBorderShadow:Hide();
		arrowDistance = 2;
	end

	-- Update arrow
	local isButtonDown = self:GetButtonState() == "PUSHED"
	local flyoutArrowTexture = self.FlyoutArrowContainer.FlyoutArrowNormal

	if isButtonDown then
		flyoutArrowTexture = self.FlyoutArrowContainer.FlyoutArrowPushed;

		self.FlyoutArrowContainer.FlyoutArrowNormal:Hide();
		self.FlyoutArrowContainer.FlyoutArrowHighlight:Hide();
	elseif isMouseOverButton then
		flyoutArrowTexture = self.FlyoutArrowContainer.FlyoutArrowHighlight;

		self.FlyoutArrowContainer.FlyoutArrowNormal:Hide();
		self.FlyoutArrowContainer.FlyoutArrowPushed:Hide();
	else
		self.FlyoutArrowContainer.FlyoutArrowHighlight:Hide();
		self.FlyoutArrowContainer.FlyoutArrowPushed:Hide();
	end

	self.FlyoutArrowContainer:Show();
	flyoutArrowTexture:Show();
	flyoutArrowTexture:ClearAllPoints();

	local direction = self:GetAttribute("flyoutDirection");
	if (direction == "LEFT") then
		flyoutArrowTexture:SetPoint("LEFT", self, "LEFT", -arrowDistance, 0);
		SetClampedTextureRotation(flyoutArrowTexture, 270);
	elseif (direction == "RIGHT") then
		flyoutArrowTexture:SetPoint("RIGHT", self, "RIGHT", arrowDistance, 0);
		SetClampedTextureRotation(flyoutArrowTexture, 90);
	elseif (direction == "DOWN") then
		flyoutArrowTexture:SetPoint("BOTTOM", self, "BOTTOM", 0, -arrowDistance);
		SetClampedTextureRotation(flyoutArrowTexture, 180);
	else
		flyoutArrowTexture:SetPoint("TOP", self, "TOP", 0, arrowDistance);
		SetClampedTextureRotation(flyoutArrowTexture, 0);
	end
end

-- throttle OnUpdate because it fires as often as FPS and is very resource intensive
local ON_UPDATE_TIMER_FREQUENCY = 1.5
local onUpdateTimer = 0
function Opener_UpdateFlyout_OnUpdate(self, elapsed)
	onUpdateTimer = onUpdateTimer + elapsed
	if onUpdateTimer < ON_UPDATE_TIMER_FREQUENCY then
		return
	end
	onUpdateTimer = 0
	Opener_UpdateFlyout(self)
end

function Opener_PreClick(self, button, down)
	self:SetChecked(not self:GetChecked())
	local direction = self:GetAttribute("flyoutDirection");
	local spellList = { strsplit(",", self:GetAttribute("spelllist")) }
	local typeList = { strsplit(",", self:GetAttribute("typelist")) }
	local buttonList = { FloFlyoutFrame:GetChildren() }
	table.remove(buttonList, 1)
	for i, buttonRef in ipairs(buttonList) do
		buttonRef.spellID = spellList[i]
		buttonRef.actionType = typeList[i]
		local icon = getTexture(typeList[i], spellList[i])
		_G[buttonRef:GetName().."Icon"]:SetTexture(icon)
		if not isEmpty(spellList[i]) then
			SpellFlyoutButton_UpdateCooldown(buttonRef)
			SpellFlyoutButton_UpdateState(buttonRef)
			SpellFlyoutButton_UpdateUsable(buttonRef)
			SpellFlyoutButton_UpdateCount(buttonRef)
		end
	end
	FloFlyoutFrame.Background.End:ClearAllPoints()
	FloFlyoutFrame.Background.Start:ClearAllPoints()
	local distance = 3
	if (direction == "UP") then
		FloFlyoutFrame.Background.End:SetPoint("TOP", 0, SPELLFLYOUT_INITIAL_SPACING);
		SetClampedTextureRotation(FloFlyoutFrame.Background.End, 0);
		SetClampedTextureRotation(FloFlyoutFrame.Background.VerticalMiddle, 0);
		FloFlyoutFrame.Background.Start:SetPoint("TOP", FloFlyoutFrame.Background.VerticalMiddle, "BOTTOM");
		SetClampedTextureRotation(FloFlyoutFrame.Background.Start, 0);
		FloFlyoutFrame.Background.HorizontalMiddle:Hide();
		FloFlyoutFrame.Background.VerticalMiddle:Show();
		FloFlyoutFrame.Background.VerticalMiddle:ClearAllPoints();
		FloFlyoutFrame.Background.VerticalMiddle:SetPoint("TOP", FloFlyoutFrame.Background.End, "BOTTOM");
		FloFlyoutFrame.Background.VerticalMiddle:SetPoint("BOTTOM", 0, distance);
	elseif (direction == "DOWN") then
		FloFlyoutFrame.Background.End:SetPoint("BOTTOM", 0, -SPELLFLYOUT_INITIAL_SPACING);
		SetClampedTextureRotation(FloFlyoutFrame.Background.End, 180);
		SetClampedTextureRotation(FloFlyoutFrame.Background.VerticalMiddle, 180);
		FloFlyoutFrame.Background.Start:SetPoint("BOTTOM", FloFlyoutFrame.Background.VerticalMiddle, "TOP");
		SetClampedTextureRotation(FloFlyoutFrame.Background.Start, 180);
		FloFlyoutFrame.Background.HorizontalMiddle:Hide();
		FloFlyoutFrame.Background.VerticalMiddle:Show();
		FloFlyoutFrame.Background.VerticalMiddle:ClearAllPoints();
		FloFlyoutFrame.Background.VerticalMiddle:SetPoint("BOTTOM", FloFlyoutFrame.Background.End, "TOP");
		FloFlyoutFrame.Background.VerticalMiddle:SetPoint("TOP", 0, -distance);
	elseif (direction == "LEFT") then
		FloFlyoutFrame.Background.End:SetPoint("LEFT", -SPELLFLYOUT_INITIAL_SPACING, 0);
		SetClampedTextureRotation(FloFlyoutFrame.Background.End, 270);
		SetClampedTextureRotation(FloFlyoutFrame.Background.HorizontalMiddle, 180);
		FloFlyoutFrame.Background.Start:SetPoint("LEFT", FloFlyoutFrame.Background.HorizontalMiddle, "RIGHT");
		SetClampedTextureRotation(FloFlyoutFrame.Background.Start, 270);
		FloFlyoutFrame.Background.VerticalMiddle:Hide();
		FloFlyoutFrame.Background.HorizontalMiddle:Show();
		FloFlyoutFrame.Background.HorizontalMiddle:ClearAllPoints();
		FloFlyoutFrame.Background.HorizontalMiddle:SetPoint("LEFT", FloFlyoutFrame.Background.End, "RIGHT");
		FloFlyoutFrame.Background.HorizontalMiddle:SetPoint("RIGHT", -distance, 0);
	elseif (direction == "RIGHT") then
		FloFlyoutFrame.Background.End:SetPoint("RIGHT", SPELLFLYOUT_INITIAL_SPACING, 0);
		SetClampedTextureRotation(FloFlyoutFrame.Background.End, 90);
		SetClampedTextureRotation(FloFlyoutFrame.Background.HorizontalMiddle, 0);
		FloFlyoutFrame.Background.Start:SetPoint("RIGHT", FloFlyoutFrame.Background.HorizontalMiddle, "LEFT");
		SetClampedTextureRotation(FloFlyoutFrame.Background.Start, 90);
		FloFlyoutFrame.Background.VerticalMiddle:Hide();
		FloFlyoutFrame.Background.HorizontalMiddle:Show();
		FloFlyoutFrame.Background.HorizontalMiddle:ClearAllPoints();
		FloFlyoutFrame.Background.HorizontalMiddle:SetPoint("RIGHT", FloFlyoutFrame.Background.End, "LEFT");
		FloFlyoutFrame.Background.HorizontalMiddle:SetPoint("LEFT", distance, 0);
	end
	FloFlyoutFrame:SetBorderColor(0.7, 0.7, 0.7)
	FloFlyoutFrame:SetBorderSize(47);
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

		local spellList = table.new(strsplit(",", self:GetAttribute("spellnamelist")))
		local typeList = table.new(strsplit(",", self:GetAttribute("typelist")))
		local buttonList = table.new(ref:GetChildren())
		table.remove(buttonList, 1)
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

				buttonRef:SetAttribute("type", typeList[i])
				buttonRef:SetAttribute(typeList[i], spellList[i])
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
		--ref:RegisterAutoHide(1)
		--ref:AddToAutoHide(self)
	end
]=]

-- ##########################################################################################
-- CLASS: FloFlyout
-- ##########################################################################################

function FloFlyout:CreateOpener(actionId, flyoutId, direction, actionButton, visibleIf, typeActionButton)

	local flyoutConf = self:GetFlyoutConfig(flyoutId)
	local name = "FloFlyoutOpener"..actionId
	local opener = self.openers[name] or CreateFrame("CheckButton", name, actionButton, "ActionButtonTemplate, SecureHandlerClickTemplate")
	self.openers[name] = opener
	opener.flyoutId = flyoutId
	opener.actionId = actionId

	if _classicUI then
		_classicUI.LayoutActionButton(opener, typeActionButton)
		opener:SetScale(actionButton:GetScale())
	end
	if actionButton then
		if actionButton:GetSize() and actionButton:IsRectValid() then
			opener:SetAllPoints(actionButton)
		else
			local spacerName = "ActionBarButtonSpacer"..tostring(actionButton.index)
			local children = {actionButton:GetParent():GetChildren()}
			for _, child in ipairs(children) do
				if child:GetName() == spacerName then
					opener:SetAllPoints(child)
					break;
				end
			end
		end
	end

	opener:SetFrameStrata(STRATA_DEFAULT)
	opener:SetFrameLevel(100)
	opener:SetToplevel(true)

	opener:SetAttribute("flyoutDirection", direction)
	opener:SetFrameRef("FloFlyoutFrame", FloFlyoutFrame)

	for i, spellID in ipairs(flyoutConf.spells) do
		if flyoutConf.spellNames[i] == nil then
			flyoutConf.spellNames[i] = getItemOrSpellNameById(flyoutConf.actionTypes[i], spellID)
		end
	end

	local spells = {}
	local spellNames = {}
	local actionTypes = {}
	for i, spellID in ipairs(flyoutConf.spells) do
		if isThingyUsable(spellID, flyoutConf.actionTypes[i], flyoutConf.mountIndex[i], flyoutConf.macroOwners[i]) then
			table.insert(spells, flyoutConf.spells[i])
			table.insert(spellNames, flyoutConf.spellNames[i])
			table.insert(actionTypes, flyoutConf.actionTypes[i])
		end
	end
	opener:SetAttribute("spelllist", strjoin(",", unpack(spells)))
	opener:SetAttribute("spellnamelist", strjoin(",", unpack(spellNames)))
	opener:SetAttribute("typelist", strjoin(",", unpack(actionTypes)))


	--[[
        opener:SetAttribute("spelllist", strjoin(",", unpack(flyoutConf.spells)))
        local spellnameList = flyoutConf.spellNames
        for i, spellID in ipairs(flyoutConf.spells) do
            if spellnameList[i] == nil then
                spellnameList[i] = getItemOrSpellNameById(flyoutConf.actionTypes[i], spellID)
            end
        end
        opener:SetAttribute("spellnamelist", strjoin(",", unpack(flyoutConf.spellNames)))
        opener:SetAttribute("typelist", strjoin(",", unpack(flyoutConf.actionTypes)))
    ]]

	-- TODO: find a way to eliminate the need for OnUpdate
	opener:SetScript("OnUpdate", Opener_UpdateFlyout_OnUpdate)
	opener:SetScript("OnEnter", Opener_UpdateFlyout)
	opener:SetScript("OnLeave", Opener_UpdateFlyout)

	opener:SetScript("OnReceiveDrag", Opener_OnReceiveDrag)
	opener:SetScript("OnMouseUp", Opener_OnReceiveDrag) -- Hmmm... needed?
	opener:SetScript("OnDragStart", Opener_OnDragStart)

	opener:SetScript("PreClick", Opener_PreClick)
	opener:SetAttribute("_onclick", snippet_Opener_Click)
	opener:RegisterForClicks("AnyUp")
	opener:RegisterForDrag("LeftButton")

	local icon = _G[opener:GetName().."Icon"]
	if flyoutConf.icon then
		if type(flyoutConf.icon) == "number" then
			icon:SetTexture(flyoutConf.icon)
		else
			icon:SetTexture("INTERFACE\\ICONS\\"..flyoutConf.icon)
		end
	elseif flyoutConf.spells[1] then
		local texture = getTexture(flyoutConf.actionTypes[1], flyoutConf.spells[1])
		icon:SetTexture(texture)
	end

	if visibleIf then
		local stateCondition = "nopetbattle,nooverridebar,novehicleui,nopossessbar," .. visibleIf
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
	if InCombatLockdown() then
		return
	end
	self:ClearOpeners()
	for a,f in pairs(self:GetSpecificConditionalFlyoutPlacements()) do
		self:BindFlyoutToAction(f, a)
	end
end

function FloFlyout:IsValidFlyoutId(arg1)
	local id = tonumber(arg1)
	return id and self:GetFlyoutConfig(id)
end

function FloFlyout:IsValidSpellPos(flyoutId, arg2)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	local pos = tonumber(arg2)
	return pos and self:GetFlyoutConfig(flyoutId).spells[pos]
end

function getNewFlyoutDef()
	return deepcopy(STRUCT_FLYOUT_DEF)
end

function FloFlyout:AddFlyout()
	-- TODO: support macros and battle pets
	local newFlyoutDef = getNewFlyoutDef()
	local flyoutsConfig = self:GetFlyoutsConfig()
	table.insert(flyoutsConfig, newFlyoutDef)
	return newFlyoutDef
end

function FloFlyout:RemoveFlyout(flyoutId)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	table.remove(self:GetFlyoutsConfig(), flyoutId)
	-- shift references -- TODO: stop this.  Indicees are not a precious resource.  And, this will get really complicated for mixing global & toon
	local placementsForEachSpec = self:GetFlyoutPlacementsForToon()
	for i = 1, #placementsForEachSpec do
		local placements = placementsForEachSpec[i]
		for slotId, fId in pairs(placements) do
			if fId == flyoutId then
				placements[slotId] = nil
			elseif fId > flyoutId then
				placements[slotId] = fId - 1
			end
		end
	end
end

function FloFlyout:AddSpell(flyoutId, actionType, spellId)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	if type(spellId) == "string" then spellId = tonumber(spellId) end
	local flyoutConf = self:GetFlyoutConfig(flyoutId)
	table.insert(flyoutConf.spells, spellId)
	local newPos = #flyoutConf.spells
	flyoutConf.actionTypes[newPos] = actionType
	return newPos
end

function FloFlyout:RemoveSpell(flyoutId, spellPos)
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	if type(spellPos) == "string" then spellPos = tonumber(spellPos) end
	local flyoutConf = self:GetFlyoutConfig(flyoutId)
	-- TODO: support macros and battle pets
	table.remove(flyoutConf.spells, spellPos)
	table.remove(flyoutConf.actionTypes, spellPos)
	table.remove(flyoutConf.mountIndex, spellPos)
	table.remove(flyoutConf.spellNames, spellPos)
	table.remove(flyoutConf.macroOwners, spellPos)
end

function FloFlyout:AddAction(slotId, flyoutId)
	if type(slotId) == "string" then slotId = tonumber(slotId) end
	if type(flyoutId) == "string" then flyoutId = tonumber(flyoutId) end
	self:GetSpecificConditionalFlyoutPlacements()[slotId] = flyoutId
end

function FloFlyout:RemoveAction(slotId)
	if type(slotId) == "string" then slotId = tonumber(slotId) end
	self:GetSpecificConditionalFlyoutPlacements()[slotId] = nil
end

-- when the user picks up a flyout, we need a draggable UI element, so create a dummy macro with the same icon as the flyout
function FloFlyout:PickupFlyout(flyoutId)
	-- No drag 'n drop in combat, I use protected API
	if InCombatLockdown() then
		return;
	end

	local flyoutConf = self:GetFlyoutConfig(flyoutId)
	local texture = flyoutConf.icon

	if not texture and flyoutConf.spells[1] then
		texture = getTexture(flyoutConf.actionTypes[1], flyoutConf.spells[1])
	end
	if not texture then
		texture = "INV_Misc_QuestionMark"
	end
	-- Recreate dummy macro
	DeleteMacro(DUMMY_MACRO_NAME)
	local macroId = CreateMacro(DUMMY_MACRO_NAME, texture, flyoutId, nil, nil)
	PickupMacro(macroId)
end

-- ##########################################################################################
-- CLASS: FloFlyoutButton
-- ##########################################################################################

-- TODO: support macros and battle pets
function FloFlyoutButton_SetTooltip(self)
	if GetCVar("UberTooltips") == "1" then
		GameTooltip_SetDefaultAnchor(GameTooltip, self)

		local tooltipSetter
		if self.actionType == "spell" then
			tooltipSetter = GameTooltip.SetSpellByID
		elseif self.actionType == "item" then
			tooltipSetter = GameTooltip.SetItemByID
		elseif self.actionType == "macro" then
			tooltipSetter = function(zelf, macroId)
				local name, icon, body = GetMacroInfo(macroId)
				--print("tt GetMacroInfo: for ID = ", macroId, "name =",name, "icon =",icon, "body =",body)
				return GameTooltip:SetText("Macro: ".. macroId .." " .. (name or "UNKNOWN"))
			end
		end
		if tooltipSetter and tooltipSetter(GameTooltip, self.spellID) then
			self.UpdateTooltip = FloFlyoutButton_SetTooltip
		else
			self.UpdateTooltip = nil
		end
	else
		local parent = self:GetParent():GetParent():GetParent():GetParent()
		if parent == MultiBarBottomRight or parent == MultiBarRight or parent == MultiBarLeft then
			GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		else
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		end
		local spellName = getItemOrSpellNameById(self.actionType, self.spellID)
		GameTooltip:SetText(spellName, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		self.UpdateTooltip = nil
	end
end

-- TODO: support macros and battle pets
-- pickup a button from an existing flyout
function FloFlyoutButton_OnDragStart(self)
	if InCombatLockdown() then return end

	local actionType = self.actionType
	local spell = self.spellID
	local mountIndex = self.mountIndex
	if actionType == "spell" then
		if mountIndex == nil then
			PickupSpell(spell)
		else
			C_MountJournal.Pickup(mountIndex)
		end
		FloFlyout.mountIndex = mountIndex
	elseif actionType == "item" then
		PickupItem(spell)
	elseif actionType == "macro" then
		PickupMacro(spell)
	end

	--print("#### FloFlyoutButton_OnDragStart-->  actionType =",actionType, " spellID =", spell, " mountIndex =,mountIndex")

	local parent = self:GetParent()
	if parent.IsConfig then
		FloFlyout:RemoveSpell(parent.idFlyout, self:GetID())
		FloFlyout:ApplyConfig()
		FloFlyoutConfigFlyoutFrame_Update(parent, parent.idFlyout)
	end
end

FloFlyout.mountIndex = nil;
function FloFlyout.MountJournal_PickupHook(index)
	FloFlyout.mountIndex = index;
end
hooksecurefunc(C_MountJournal, "Pickup", FloFlyout.MountJournal_PickupHook);

-- add a spell/item/etc to a flyout
function FloFlyoutButton_OnReceiveDrag(btn)
	local flyoutFrame = btn:GetParent()
	if not flyoutFrame.IsConfig then return end
	local flyoutId = flyoutFrame.idFlyout

	local kind, info1, info2, info3 = GetCursorInfo()
	local actionType, thingyId, mountIndex, macroOwner

	-- TODO: distinguish between toys and spells
	-- TODO: support battle pets and macros
	--print("FloFlyoutButton_OnReceiveDrag-->  kind =",kind, " --  info1 =",info1, " --  info1 =",info1, " --  info3 =",info3)
	if kind == "spell" then
		actionType = "spell"
		thingyId = info3
	elseif kind == "mount" then
		actionType = "spell" -- TODO: Hurm
		_, thingyId, _, _, _, _, _, _, _, _, _ = C_MountJournal.GetDisplayedMountInfo(FloFlyout.mountIndex);
		mountIndex = FloFlyout.mountIndex
	elseif kind == "item" then
		actionType = "item"
		thingyId = info1
	elseif kind == "macro" then
		actionType = "macro"
		thingyId = info1
		if not isMacroGlobal(thingyId) then
			macroOwner = getIdForCurrentToon()
		end
	end

	if actionType then
		local flyoutConf = FloFlyout:GetFlyoutConfig(flyoutId)
		local btnIndex = btn:GetID()

		local oldThingyId   = flyoutConf.spells[btnIndex]
		local oldActionType = flyoutConf.actionTypes[btnIndex]
		local oldMountIndex = flyoutConf.mountIndex[btnIndex]

		flyoutConf.spells[btnIndex] = thingyId
		flyoutConf.actionTypes[btnIndex] = actionType
		flyoutConf.mountIndex[btnIndex] = mountIndex
		flyoutConf.spellNames[btnIndex] = getItemOrSpellNameById(actionType, thingyId)
		flyoutConf.macroOwners[btnIndex] = macroOwner

		-- drop the dragged spell/item/etc
		ClearCursor()
		FloFlyout:ApplyConfig()
		FloFlyoutConfigFlyoutFrame_Update(flyoutFrame, flyoutId)

		-- update the cursor to show the existing spell/item/etc (if any)
		if oldActionType == "spell" then
			if oldMountIndex == nil then
				PickupSpell(oldThingyId)
			else
				C_MountJournal.Pickup(oldMountIndex)
			end
		elseif oldActionType == "item" then
			PickupItem(oldThingyId)
		elseif oldActionType == "macro" then
			PickupMacro(oldThingyId)
		end
	else
		print("sorry, unsupported type:", kind)
	end
end

-- ##########################################################################################
-- CLASS: FloFlyoutConfigFlyoutFrame
-- ##########################################################################################

-- TODO: support macros and battle pets
function FloFlyoutConfigFlyoutFrame_Update(self, idFlyout)
	local direction = "RIGHT"
	local parent = self.parent

	self.idFlyout = idFlyout

	-- Update all spell buttons for this flyout
	local prevButton = nil;
	local numButtons = 0;
	local flyoutConfig = FloFlyout:GetFlyoutConfig(idFlyout)
	local spells = flyoutConfig and flyoutConfig.spells
	local actionTypes = flyoutConfig and flyoutConfig.actionTypes
	local mountIndexes = flyoutConfig and flyoutConfig.mountIndex

	for i=1, math.min(#spells+1, MAX_FLYOUT_SIZE) do
		local spellID = spells[i]
		local actionType = actionTypes[i]
		local mountIndex = mountIndexes[i]
		local button = _G["FloFlyoutConfigFlyoutFrameButton"..numButtons+1]

		button:ClearAllPoints()
		if direction == "UP" then
			if prevButton then
				button:SetPoint("BOTTOM", prevButton, "TOP", 0, SPELLFLYOUT_DEFAULT_SPACING)
			else
				button:SetPoint("BOTTOM", 0, SPELLFLYOUT_INITIAL_SPACING)
			end
		elseif direction == "DOWN" then
			if prevButton then
				button:SetPoint("TOP", prevButton, "BOTTOM", 0, -SPELLFLYOUT_DEFAULT_SPACING)
			else
				button:SetPoint("TOP", 0, -SPELLFLYOUT_INITIAL_SPACING)
			end
		elseif direction == "LEFT" then
			if prevButton then
				button:SetPoint("RIGHT", prevButton, "LEFT", -SPELLFLYOUT_DEFAULT_SPACING, 0)
			else
				button:SetPoint("RIGHT", -SPELLFLYOUT_INITIAL_SPACING, 0)
			end
		elseif direction == "RIGHT" then
			if prevButton then
				button:SetPoint("LEFT", prevButton, "RIGHT", SPELLFLYOUT_DEFAULT_SPACING, 0)
			else
				button:SetPoint("LEFT", SPELLFLYOUT_INITIAL_SPACING, 0)
			end
		end

		button:Show()

		-- TODO: support macros and battle pets
		if spellID then
			button.spellID = spellID -- this is read by Bliz code in SpellFlyout.lua
			button.actionType = actionType
			button.mountIndex = mountIndex
			local texture = getTexture(actionType, spellID)
			_G[button:GetName().."Icon"]:SetTexture(texture)
			SpellFlyoutButton_UpdateCooldown(button)
			SpellFlyoutButton_UpdateState(button)
			SpellFlyoutButton_UpdateUsable(button)
			SpellFlyoutButton_UpdateCount(button)
		else
			_G[button:GetName().."Icon"]:SetTexture(nil)
			button.spellID = nil
			button.actionType = nil
			button.mountIndex = nil
		end

		prevButton = button
		numButtons = numButtons+1
	end

	-- Hide unused buttons
	local unusedButtonIndex = numButtons+1
	while _G["FloFlyoutConfigFlyoutFrameButton"..unusedButtonIndex] do
		_G["FloFlyoutConfigFlyoutFrameButton"..unusedButtonIndex]:Hide()
		unusedButtonIndex = unusedButtonIndex+1
	end

	if numButtons == 0 then
		self:Hide()
		return
	end

	-- Show the flyout
	self:SetFrameStrata("DIALOG")
	self:ClearAllPoints()

	local distance = 3

	self.Background.End:ClearAllPoints()
	self.Background.Start:ClearAllPoints()
	if (direction == "UP") then
		self:SetPoint("BOTTOM", parent, "TOP");
		self.Background.End:SetPoint("TOP", 0, SPELLFLYOUT_INITIAL_SPACING);
		SetClampedTextureRotation(self.Background.End, 0);
		SetClampedTextureRotation(self.Background.VerticalMiddle, 0);
		self.Background.Start:SetPoint("TOP", self.Background.VerticalMiddle, "BOTTOM");
		SetClampedTextureRotation(self.Background.Start, 0);
		self.Background.HorizontalMiddle:Hide();
		self.Background.VerticalMiddle:Show();
		self.Background.VerticalMiddle:ClearAllPoints();
		self.Background.VerticalMiddle:SetPoint("TOP", self.Background.End, "BOTTOM");
		self.Background.VerticalMiddle:SetPoint("BOTTOM", 0, distance);
	elseif (direction == "DOWN") then
		self:SetPoint("TOP", parent, "BOTTOM");
		self.Background.End:SetPoint("BOTTOM", 0, -SPELLFLYOUT_INITIAL_SPACING);
		SetClampedTextureRotation(self.Background.End, 180);
		SetClampedTextureRotation(self.Background.VerticalMiddle, 180);
		self.Background.Start:SetPoint("BOTTOM", self.Background.VerticalMiddle, "TOP");
		SetClampedTextureRotation(self.Background.Start, 180);
		self.Background.HorizontalMiddle:Hide();
		self.Background.VerticalMiddle:Show();
		self.Background.VerticalMiddle:ClearAllPoints();
		self.Background.VerticalMiddle:SetPoint("BOTTOM", self.Background.End, "TOP");
		self.Background.VerticalMiddle:SetPoint("TOP", 0, -distance);
	elseif (direction == "LEFT") then
		self:SetPoint("RIGHT", parent, "LEFT");
		self.Background.End:SetPoint("LEFT", -SPELLFLYOUT_INITIAL_SPACING, 0);
		SetClampedTextureRotation(self.Background.End, 270);
		SetClampedTextureRotation(self.Background.HorizontalMiddle, 180);
		self.Background.Start:SetPoint("LEFT", self.Background.HorizontalMiddle, "RIGHT");
		SetClampedTextureRotation(self.Background.Start, 270);
		self.Background.VerticalMiddle:Hide();
		self.Background.HorizontalMiddle:Show();
		self.Background.HorizontalMiddle:ClearAllPoints();
		self.Background.HorizontalMiddle:SetPoint("LEFT", self.Background.End, "RIGHT");
		self.Background.HorizontalMiddle:SetPoint("RIGHT", -distance, 0);
	elseif (direction == "RIGHT") then
		self:SetPoint("LEFT", parent, "RIGHT");
		self.Background.End:SetPoint("RIGHT", SPELLFLYOUT_INITIAL_SPACING, 0);
		SetClampedTextureRotation(self.Background.End, 90);
		SetClampedTextureRotation(self.Background.HorizontalMiddle, 0);
		self.Background.Start:SetPoint("RIGHT", self.Background.HorizontalMiddle, "LEFT");
		SetClampedTextureRotation(self.Background.Start, 90);
		self.Background.VerticalMiddle:Hide();
		self.Background.HorizontalMiddle:Show();
		self.Background.HorizontalMiddle:ClearAllPoints();
		self.Background.HorizontalMiddle:SetPoint("RIGHT", self.Background.End, "LEFT");
		self.Background.HorizontalMiddle:SetPoint("LEFT", distance, 0);
	end

	if direction == "UP" or direction == "DOWN" then
		self:SetWidth(prevButton:GetWidth())
		self:SetHeight((prevButton:GetHeight()+SPELLFLYOUT_DEFAULT_SPACING) * numButtons - SPELLFLYOUT_DEFAULT_SPACING + SPELLFLYOUT_INITIAL_SPACING + SPELLFLYOUT_FINAL_SPACING)
	else
		self:SetHeight(prevButton:GetHeight())
		self:SetWidth((prevButton:GetWidth()+SPELLFLYOUT_DEFAULT_SPACING) * numButtons - SPELLFLYOUT_DEFAULT_SPACING + SPELLFLYOUT_INITIAL_SPACING + SPELLFLYOUT_FINAL_SPACING)
	end

	self.direction = direction;
	self:SetBorderColor(0.7, 0.7, 0.7);
	self:SetBorderSize(47);
end

function FloFlyoutConfigPane_OnLoad(self)
	HybridScrollFrame_OnLoad(self)
	self.update = FloFlyout.ConfigPane_Update
	HybridScrollFrame_CreateButtons(self, "FloFlyoutConfigButtonTemplate")
end

function FloFlyoutConfigPane_OnShow(self)
	HybridScrollFrame_CreateButtons(self, "FloFlyoutConfigButtonTemplate")
	FloFlyout.ConfigPane_Update()
end

function FloFlyoutConfigPane_OnHide(self)
	FloFlyoutConfigDialogPopup:Hide()
	FloFlyoutConfigFlyoutFrame:Hide()
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

function FloFlyout.ConfigPane_Update()
	local flyouts = FloFlyout:GetFlyoutsConfig()
	local numRows = #flyouts + 1
	HybridScrollFrame_Update(FloFlyoutConfigPane, numRows * EQUIPMENTSET_BUTTON_HEIGHT + 20, FloFlyoutConfigPane:GetHeight())

	local scrollOffset = HybridScrollFrame_GetOffset(FloFlyoutConfigPane)
	local buttons = FloFlyoutConfigPane.buttons
	local selectedIdx = FloFlyoutConfigPane.selectedIdx
	FloFlyoutConfigFlyoutFrame:Hide()
	local texture, button, flyout
	for i = 1, #buttons do
		local pos = i+scrollOffset
		if pos <= numRows then
			button = buttons[i]
			buttons[i]:Show()
			button:Enable()

			if pos < numRows then
				-- Normal flyout button
				button.name = pos
				button.text:SetText(button.name);
				button.text:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
				flyout = FloFlyout:GetFlyoutConfig(pos)
				texture = flyout.icon

				if not texture and flyout.spells[1] then
					texture = getTexture(flyout.actionTypes[1], flyout.spells[1])
				end
				if texture then
					if(type(texture) == "number") then
						button.icon:SetTexture(texture);
					else
						button.icon:SetTexture("INTERFACE\\ICONS\\"..texture);
					end
				else
					button.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
				end

				if selectedIdx and (pos == selectedIdx) then
					button.SelectedBar:Show()
					button.Arrow:Show()
					FloFlyoutConfigFlyoutFrame.parent = button
					FloFlyoutConfigFlyoutFrame_Update(FloFlyoutConfigFlyoutFrame, pos)
					FloFlyoutConfigFlyoutFrame:Show()
				else
					button.SelectedBar:Hide()
					button.Arrow:Hide()
				end

				button.icon:SetSize(36, 36)
				button.icon:SetPoint("LEFT", 4, 0)
			else
				-- This is the Add New button
				button.name = nil
				button.text:SetText(L["NEW_FLYOUT"])
				button.text:SetTextColor(GREEN_FONT_COLOR.r, GREEN_FONT_COLOR.g, GREEN_FONT_COLOR.b)
				button.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
				button.icon:SetSize(30, 30)
				button.icon:SetPoint("LEFT", 7, 0)
				button.SelectedBar:Hide()
				button.Arrow:Hide()
			end

			if (pos) == 1 then
				buttons[i].BgTop:Show()
				buttons[i].BgMiddle:SetPoint("TOP", buttons[i].BgTop, "BOTTOM")
			else
				buttons[i].BgTop:Hide()
				buttons[i].BgMiddle:SetPoint("TOP")
			end

			if (pos) == numRows then
				buttons[i].BgBottom:Show()
				buttons[i].BgMiddle:SetPoint("BOTTOM", buttons[i].BgBottom, "TOP")
			else
				buttons[i].BgBottom:Hide()
				buttons[i].BgMiddle:SetPoint("BOTTOM")
			end

			if (pos)%2 == 0 then
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

-- ##########################################################################################
-- CLASS: FloFlyoutConfigButton
-- ##########################################################################################

function FloFlyoutConfigButton_OnClick(self, button, down)
	if self.name and self.name ~= "" then
		if FloFlyoutConfigPane.selectedIdx == self.name then
			FloFlyoutConfigPane.selectedIdx = nil
		else
			PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)		-- inappropriately named, but a good sound.
			FloFlyoutConfigPane.selectedIdx = self.name
		end
		FloFlyout.ConfigPane_Update()
		FloFlyoutConfigDialogPopup:Hide()
	else
		-- This is the "New" button
		FloFlyoutConfigDialogPopup:Show()
		FloFlyoutConfigPane.selectedIdx = nil
		FloFlyout.ConfigPane_Update()
	end
end

function FloFlyoutConfigButton_OnDragStart(self)
	if self.name and self.name ~= "" then
		FloFlyout:PickupFlyout(self.name)
	end
end

-- ##########################################################################################
-- CLASS: FloFlyoutConfigDialogPopup
-- ##########################################################################################

local NUM_FLYOUT_ICONS_SHOWN = 15
local NUM_FLYOUT_ICONS_PER_ROW = 5
local NUM_FLYOUT_ICON_ROWS = 3
local FLYOUT_ICON_ROW_HEIGHT = 36
local FC_ICON_FILENAMES = {}

function FloFlyoutConfigDialogPopup_OnLoad (self)
	self.buttons = {}

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
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
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
	FloFlyout.RefreshFlyoutIconInfo()
	local totalItems = #FC_ICON_FILENAMES
	local texture, _
	if popup.selectedTexture then
		local foundIndex = nil
		for index=1, totalItems do
			texture = FloFlyout.GetFlyoutIconInfo(index)
			if texture == popup.selectedTexture then
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
function FloFlyout.RefreshFlyoutIconInfo()
	FC_ICON_FILENAMES = {}
	FC_ICON_FILENAMES[1] = "INV_MISC_QUESTIONMARK"
	local index = 2

	local popup = FloFlyoutConfigDialogPopup
	if popup.name then
		local spells = FloFlyout:GetFlyoutsConfig()[popup.name].spells
		local actionTypes = FloFlyout:GetFlyoutsConfig()[popup.name].actionTypes
		for i = 1, #spells do
			local itemTexture = getTexture(actionTypes[i], spells[i])
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
	GetLooseMacroIcons(FC_ICON_FILENAMES)
	GetMacroIcons(FC_ICON_FILENAMES)
end

function FloFlyout.GetFlyoutIconInfo(index)
	return FC_ICON_FILENAMES[index]
end

function FloFlyoutConfigDialogPopup_Update()
	FloFlyout.RefreshFlyoutIconInfo()

	local popup = FloFlyoutConfigDialogPopup
	local buttons = popup.buttons
	local offset = FauxScrollFrame_GetOffset(FloFlyoutConfigDialogPopupScrollFrame) or 0
	-- Icon list
	local texture, index, _
	for i=1, NUM_FLYOUT_ICONS_SHOWN do
		local button = buttons[i]
		index = (offset * NUM_FLYOUT_ICONS_PER_ROW) + i
		if index <= #FC_ICON_FILENAMES then
			texture = FloFlyout.GetFlyoutIconInfo(index)

			if(type(texture) == "number") then
				button.icon:SetTexture(texture);
			else
				button.icon:SetTexture("INTERFACE\\ICONS\\"..texture);
			end
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

function FloFlyout.ConfigDialogPopupOkay_Update()
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
		iconTexture = FloFlyout.GetFlyoutIconInfo(popup.selectedIcon)
	end

	local config
	if popup.isEdit then
		-- Modifying a flyout
		config = FloFlyout:GetFlyoutConfig(popup.name)
	else
		-- Saving a new flyout
		config = FloFlyout:AddFlyout()
	end
	config.icon = iconTexture
	popup:Hide()
	FloFlyout.ConfigPane_Update()
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
	FloFlyout.ConfigDialogPopupOkay_Update()
end

-------------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------------

function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function isEmpty(s)
	return s == nil or s == ''
end

-- TODO: support macros and BP
-- in SpellFlyout.lua
-- SpellFlyoutButton_OnClick
-- is responsible for casting spells, but knows nothing of pets or macros... but somehow understands mounts... because mounts are covered by self.spellName
-- so, I could override it, check for a custom attribute self.petId or self.macroId ... win?
