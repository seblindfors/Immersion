local _, L = ...
----------------------------------
-- Native settings panel
----------------------------------
-- Every option is a proxy setting over L.cfg (ImmersionSetup), so values keep
-- falling back to L.defaults the same way L.Get does, and the panel's
-- "Defaults" button resets through the same setters (side effects included).

local VarType = Settings.VarType
local PREFIX = _:upper() .. '_'

function L.GetSettingVariable(key)
	return PREFIX .. key
end

local function Round(value, step)
	return floor(value / step + 0.5) * step
end

local function CreateOptions(list)
	return function()
		local container = Settings.CreateControlTextContainer()
		for _, option in ipairs(type(list) == 'function' and list() or list) do
			container:Add(option[1], option[2])
		end
		return container:GetData()
	end
end

----------------------------------
-- Builders
----------------------------------
local function Register(category, key, name, varType, onSet)
	local default = L.defaults[key]
	if default == nil then
		default = (varType == VarType.Boolean and false) or (varType == VarType.String and '') or 0
	end
	local function GetValue()
		local value = L.Get(key)
		if varType == VarType.Boolean then
			return not not value
		elseif type(value) ~= varType then
			return default
		end
		return value
	end
	local function SetValue(value)
		L.cfg[key] = value
		if onSet then onSet(value) end
	end
	return Settings.RegisterProxySetting(category, L.GetSettingVariable(key), varType, name, default, GetValue, SetValue)
end

local function Header(layout, name, tooltip)
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(name, tooltip))
end

local function Checkbox(category, key, name, tooltip, onSet)
	return Settings.CreateCheckbox(category, Register(category, key, name, VarType.Boolean, onSet), tooltip)
end

local function Slider(category, key, name, min, max, step, tooltip, onSet)
	local setting = Register(category, key, name, VarType.Number, function(value)
		value = Round(value, step)
		L.cfg[key] = value
		if onSet then onSet(value) end
	end)
	local fmt = step < 1 and '%.1f' or '%d'
	local options = Settings.CreateSliderOptions(min, max, step)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
		return fmt:format(Round(value, step))
	end)
	return Settings.CreateSlider(category, setting, options, tooltip)
end

local function Dropdown(category, key, name, varType, list, tooltip, onSet)
	local setting = Register(category, key, name, varType, onSet)
	return Settings.CreateDropdown(category, setting, CreateOptions(list), tooltip)
end

local function Keybind(category, layout, key, name, validate, tooltip)
	local setting = Register(category, key, name, VarType.String, function(value)
		-- false marks an explicit unbind, so L.Get won't fall back to the default key.
		L.cfg[key] = value ~= '' and value or false
	end)
	local initializer = Settings.CreateControlInitializer('ImmersionKeybindControlTemplate', setting, nil, tooltip)
	initializer.data.validate = validate
	layout:AddInitializer(initializer)
	return initializer
end

local function Button(layout, name, text, onClick, tooltip)
	local initializer = CreateSettingsButtonInitializer(name, text, onClick, tooltip, true)
	layout:AddInitializer(initializer)
	return initializer
end

local function DependsOn(parent, predicate, ...)
	for i = 1, select('#', ...) do
		select(i, ...):SetParentInitializer(parent, predicate)
	end
end

----------------------------------
-- Option lists
----------------------------------
local stratas = {
	{ 'LOW',               L['Low'] },
	{ 'MEDIUM',            L['Medium'] },
	{ 'HIGH',              L['High'] },
	{ 'DIALOG',            L['Dialog'] },
	{ 'FULLSCREEN',        L['Fullscreen'] },
	{ 'FULLSCREEN_DIALOG', L['Fullscreen dialog'] },
	{ 'TOOLTIP',           L['Tooltip'] },
}

local modifiers = {
	{ 'SHIFT', SHIFT_KEY_TEXT },
	{ 'CTRL',  CTRL_KEY_TEXT },
	{ 'ALT',   ALT_KEY_TEXT },
	{ 'NOMOD', NONE },
}

local titleanis = {
	{ 0,  OFF },
	{ 1,  SPELL_CAST_TIME_INSTANT },
	{ 5,  FAST },
	{ 10, SLOW },
}

local function GetVoices()
	local list = {}
	for _, voice in ipairs(C_VoiceChat.GetTtsVoices() or {}) do
		list[#list + 1] = { voice.voiceID + 1, voice.name }
	end
	return list
end

local function GetModifierText(key)
	for _, option in ipairs(modifiers) do
		if option[1] == key then return option[2] end
	end
end

-- Matches the delay formula in Text.lua, used to preview the text speed option.
local function GetTextSpeedTooltip()
	local sample = 'I need help with these quests.'
	local fmt = D_SECONDS:gsub('%%[ds]', '%%.2f')
	local function Line(label, divisor)
		local time = (strlen(sample) / (math.log(strlen(sample)) / math.log(30^(1 / divisor)))) + L.TEXT_TIME_PADDING
		return ('%s = %d\n"%s"\n  -> %s'):format(label, divisor, sample, fmt:format(time))
	end
	return L['Change the speed of text delivery.'] .. '\n\n' ..
		Line(MINIMUM, 5) .. '\n\n' .. Line(DEFAULT, 15) .. '\n\n' .. Line(MAXIMUM, 40)
end

----------------------------------
-- Pages
----------------------------------
local function BuildGeneral(category, layout)
	Header(layout, LOCK_FOCUS_FRAME)
	Checkbox(category, 'boxlock', MODEL .. ' / ' .. LOCALE_TEXT_LABEL)
	Checkbox(category, 'titlelock', QUESTS_LABEL .. ' / ' .. GOSSIP_OPTIONS)

	Header(layout, L['Behavior'])
	Slider(category, 'delaydivisor', L['Text speed'], 5, 40, 1, GetTextSpeedTooltip())
	local progression = Checkbox(category, 'disableprogression', L['Disable automatic text progress'],
		L['Stop NPCs from automatically proceeding to the next line of dialogue.'])
	DependsOn(progression, function() return not L.Get('disableprogression') end,
		Checkbox(category, 'showprogressbar', L['Show text progress bar']))

	Header(layout, MOUSE_LABEL)
	local noConsolePort = function() return not ConsolePort end
	Checkbox(category, 'flipshortcuts', L['Flip mouse functions'], L.GetListString(
		L['Left click is used to handle text.'],
		L['Right click is used to accept/hand in quests.'])):AddModifyPredicate(noConsolePort)
	Checkbox(category, 'immersivemode', L['Immersive mode'],
		L['Use your primary mouse button to read through text, accept/turn in quests and select the best available gossip option.'])
		:AddModifyPredicate(noConsolePort)

	Header(layout, L['Hide interface'])
	DependsOn(Checkbox(category, 'hideui', L['Hide interface'], L['Hide my user interface when interacting with an NPC.']),
		function() return L.Get('hideui') end,
		Checkbox(category, 'hideminimap', L['Hide minimap'], nil, function(value)
			L.ToggleIgnoreFrame(Minimap, not value)
			L.ToggleIgnoreFrame(MinimapCluster, not value)
		end),
		Checkbox(category, 'hidetracker', L['Hide objective tracker'], nil, function(value)
			L.ToggleIgnoreFrame(ObjectiveTrackerFrame, not value)
		end),
		Checkbox(category, 'hidetooltip', L['Hide tooltip']))

	Header(layout, PLAYBACK)
	Checkbox(category, 'onthefly', QUICKBUTTON_NAME_EVERYTHING,
		L["The quest/gossip text doesn't vanish when you stop interacting with the NPC or when accepting a new quest. Instead, it vanishes at the end of the text sequence. This allows you to maintain your immersive experience when speed leveling."])
	Checkbox(category, 'supertracked', OBJECTIVES_TRACKER_LABEL,
		L["When a quest is supertracked (clicked on in the objective tracker, or set automatically by proximity), the quest text will play if nothing else is obstructing it."])

	Header(layout, TEXT_TO_SPEECH)
	DependsOn(Checkbox(category, 'ttsenabled', TEXT_TO_SPEECH, L["Reads quest text aloud using text-to-speech based on options selected."]),
		function() return L.Get('ttsenabled') end,
		Slider(category, 'ttsvolume', TEXT_TO_SPEECH_ADJUST_VOLUME, 1, 100, 1),
		Slider(category, 'ttsrate', TEXT_TO_SPEECH_ADJUST_RATE, -5, 5, 0.1),
		Dropdown(category, 'ttsvoice', VOICE, VarType.Number, GetVoices),
		Dropdown(category, 'ttsfemalevoice', L['Female voice'], VarType.Number, GetVoices),
		Dropdown(category, 'ttsmalevoice', L['Male voice'], VarType.Number, GetVoices))

	Header(layout, L['Hook talking head'])
	Checkbox(category, 'movetalkinghead', VIDEO_OPTIONS_ENABLED,
		L["The regular talking head frame appears in the same place as Immersion when you're not interacting with anything and on top of Immersion if they are visible at the same time."])
end

local function BuildKeybindings(category, layout)
	local list = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS)
	Keybind(category, layout, 'accept', ACCEPT, L.ValidateKey,
		L.GetListString(ACCEPT, NEXT, CONTINUE, COMPLETE_QUEST, SPELL_CAST_TIME_INSTANT .. ': ' .. (GetModifierText(L('inspect')) or NONE)))
	Keybind(category, layout, 'goodbye', GOODBYE .. '/' .. CLOSE .. ' (' .. KEY_ESCAPE .. ')', L.ValidateKey, list)
	Keybind(category, layout, 'reset', RESET, L.ValidateKey)
	Checkbox(category, 'enablenumbers', '[1-9] ' .. PET_BATTLE_SELECT_AN_ACTION, list)
end

local function BuildGamepad(category, layout)
	local tooltip = L['Press a gamepad button to assign it. Hints shown by ConsolePort follow these.']
	for _, action in ipairs({
		{ 'padaccept',  ACCEPT               };
		{ 'padinspect', INSPECT              };
		{ 'padnext',    NEXT                 };
		{ 'padgoodbye', GOODBYE              };
		{ 'padup',      L['Previous option'] };
		{ 'paddown',    L['Next option']     };
		{ 'padleft',    L['Previous item']   };
		{ 'padright',   L['Next item']       };
	}) do
		Keybind(category, layout, action[1], action[2], L.ValidatePadKey, tooltip)
	end
end

local function BuildDisplay(category, layout)
	local frame = L.frame
	local talkbox = frame.TalkBox

	Dropdown(category, 'anidivisor', L['Dynamic offset'], VarType.Number, titleanis)
	Dropdown(category, 'strata', L['Frame strata'], VarType.String, stratas, nil, function(value)
		frame:SetFrameStrata(value)
		talkbox:SetFrameStrata(value)
	end)
	Slider(category, 'scale', L['Global scale'], 0.5, 1.5, 0.1, nil, function(value)
		frame:SetScale(value)
	end)

	Header(layout, MODEL .. ' / ' .. LOCALE_TEXT_LABEL, L['Customize the talking head frame.'])
	Checkbox(category, 'solidbackground', L['Solid background'], nil, function(value)
		talkbox.BackgroundFrame.SolidBackground:SetShown(value)
		talkbox.Elements:SetBackdrop(value and L.Backdrops.TALKBOX_SOLID or L.Backdrops.TALKBOX)
	end)
	Checkbox(category, 'disablebgtextures', L['Disable overlay backgrounds'])
	Checkbox(category, 'disableglowani', L['Disable sheen animation'])
	Checkbox(category, 'disableportrait', L['Disable portrait border'], nil, function(value)
		talkbox.PortraitFrame:SetShown(not value)
		talkbox.MainFrame.Model.PortraitBG:SetShown(not value)
	end)
	Checkbox(category, 'disableanisequence', L['Disable model animations'])
	Checkbox(category, 'disableboxhighlight', L['Disable mouseover highlight'])
	Slider(category, 'boxscale', L['Scale'], 0.5, 1.5, 0.1, nil, function(value)
		talkbox:SetScale(value)
	end)
	Button(layout, RESET_POSITION, RESET, function()
		L.Set('boxpoint', L.defaults.boxpoint)
		L.Set('boxoffsetX', L.defaults.boxoffsetX)
		L.Set('boxoffsetY', L.defaults.boxoffsetY)
		talkbox.extraY = 0
		talkbox.offsetX = L('boxoffsetX')
		talkbox.offsetY = L('boxoffsetY')
		talkbox:ClearAllPoints()
		talkbox:SetPoint(L('boxpoint'), UIParent, L('boxoffsetX'), L('boxoffsetY'))
	end)

	Header(layout, QUESTS_LABEL .. ' / ' .. GOSSIP_OPTIONS, L['Change the placement and scale of your dialogue options.'])
	Slider(category, 'titlescale', L['Scale'], 0.5, 1.5, 0.1, nil, function(value)
		frame.TitleButtons:SetScale(value)
	end)
	Checkbox(category, 'gossipatcursor', L['Show at mouse location'])

	Header(layout, QUEST_OBJECTIVES .. ' / ' .. QUEST_REWARDS)
	Slider(category, 'elementscale', L['Scale'], 0.5, 1.5, 0.1, nil, function(value)
		talkbox.Elements:SetScale(value)
	end)
	Dropdown(category, 'inspect', INSPECT .. ' (' .. ITEMS .. ')', VarType.String, modifiers)
end

function L.SetupSettings()
	local category, layout = Settings.RegisterVerticalLayoutCategory(_)
	BuildGeneral(category, layout)

	for _, page in ipairs({
		{ KEY_BINDINGS,  BuildKeybindings };
		{ L['Gamepad'],  BuildGamepad     };
		{ DISPLAY,       BuildDisplay     };
	}) do
		page[2](Settings.RegisterVerticalLayoutSubcategory(category, page[1]))
	end

	Settings.RegisterAddOnCategory(category)
	L.settingsCategory = category
end

function L.OpenSettings()
	Settings.OpenToCategory(L.settingsCategory:GetID())
end

----------------------------------
-- Keybind control
----------------------------------
-- The Settings API has no keybind widget for addon-defined keys, so this row
-- captures a single raw key (or gamepad button) and stores it in the setting.
-- Right click or Escape unbinds.

local IGNORED_KEYS = {
	LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true,
	LALT = true, RALT = true, UNKNOWN = true,
}

ImmersionKeybindControlMixin = CreateFromMixins(SettingsControlMixin)

function ImmersionKeybindControlMixin:OnLoad()
	SettingsControlMixin.OnLoad(self)
	local button = self.Button
	button:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
	button:SetScript('OnClick', function(_, mouseButton) self:OnButtonClick(mouseButton) end)
	button:SetScript('OnKeyDown', function(_, key) self:OnInput(key) end)
	button:SetScript('OnGamePadButtonDown', function(_, key) self:OnInput(key) end)
	button:SetScript('OnHide', function() self:SetCapturing(false) end)
	button:SetScript('OnEnter', function() self.Tooltip:OnEnter() end)
	button:SetScript('OnLeave', function() self.Tooltip:OnLeave() end)
end

function ImmersionKeybindControlMixin:Init(initializer)
	SettingsControlMixin.Init(self, initializer)
	self:SetCapturing(false)
	self:EvaluateState()
end

function ImmersionKeybindControlMixin:Release()
	self:SetCapturing(false)
	SettingsControlMixin.Release(self)
end

function ImmersionKeybindControlMixin:OnSettingValueChanged(setting, value)
	SettingsControlMixin.OnSettingValueChanged(self, setting, value)
	self:Refresh()
end

function ImmersionKeybindControlMixin:EvaluateState()
	SettingsListElementMixin.EvaluateState(self)
	local enabled = self:IsEnabled()
	self.Button:SetEnabled(enabled)
	self:DisplayEnabled(enabled)
end

function ImmersionKeybindControlMixin:Refresh()
	local key = self:GetSetting():GetValue()
	if self.capturing then
		self.Button:SetText(L['Press a key...'])
	elseif key ~= '' then
		self.Button:SetText(GetBindingText(key))
	else
		self.Button:SetText(GRAY_FONT_COLOR:WrapTextInColorCode(NOT_BOUND))
	end
end

function ImmersionKeybindControlMixin:SetCapturing(capturing)
	local button = self.Button
	self.capturing = capturing
	button:EnableKeyboard(capturing)
	if button.EnableGamePadButton then
		button:EnableGamePadButton(capturing)
	end
	if capturing then
		button:LockHighlight()
	else
		button:UnlockHighlight()
	end
	if self.data then
		self:Refresh()
	end
end

function ImmersionKeybindControlMixin:OnButtonClick(mouseButton)
	if mouseButton == 'RightButton' then
		self:SetCapturing(false)
		self:GetSetting():SetValue('')
	else
		self:SetCapturing(not self.capturing)
	end
end

function ImmersionKeybindControlMixin:OnInput(key)
	if not self.capturing or IGNORED_KEYS[key] then return end
	self:SetCapturing(false)
	if key == 'ESCAPE' then
		self:GetSetting():SetValue('')
		return
	end
	local valid = self.data.validate(key)
	if valid then
		self:GetSetting():SetValue(valid)
	end
end
