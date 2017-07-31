----------------------------------
-- These are things that
-- are more easily handled in Lua
-- than XML, but have to do with
-- the initial setup.
----------------------------------
local _, L = ...
local frame = _G[ _ .. 'Frame' ]
local talkbox = frame.TalkBox
local titles = frame.TitleButtons
local inspector = frame.Inspector
local elements = talkbox.Elements
local _Mixin = L.Mixin
L.frame = frame

----------------------------------
-- Prepare propagation, so that we
-- can catch certain key strokes
-- but propagate the event otherwise.
----------------------------------
frame:SetPropagateKeyboardInput(true)

----------------------------------
-- Register events for main frame
----------------------------------
for _, event in pairs({
	'ADDON_LOADED',
--	'ITEM_TEXT_BEGIN', 	-- Starting to read a book
--	'ITEM_TEXT_READY', 	-- New book text is ready
--	'ITEM_TEXT_CLOSED', -- Stop reading a book
	'GOSSIP_CLOSED',	-- Close gossip frame
	'GOSSIP_SHOW',		-- Show gossip options, can be a mix of gossip/quests
	'QUEST_ACCEPTED', 	-- Use this event for on-the-fly quest text tracking.
	'QUEST_COMPLETE',	-- Quest completed
	'QUEST_DETAIL',		-- Quest details/objectives/accept frame
	'QUEST_FINISHED',	-- Fires when quest frame is closed
	'QUEST_GREETING',	-- Multiple quests to choose from, but no gossip options
--	'QUEST_IGNORED',	-- Ignore the currently shown quest
	'QUEST_PROGRESS',	-- Fires when you click on a quest you're currently on
	'QUEST_ITEM_UPDATE', -- Item update while in convo, refresh frames.
--	'MERCHANT_SHOW', 	-- Force close gossip on merchant interaction.
}) do frame:RegisterEvent(event) end

----------------------------------
-- Register events for titlebuttons
----------------------------------
for _, event in pairs({
	'GOSSIP_CLOSED',	-- Hide buttons
	'GOSSIP_SHOW',		-- Show gossip options, can be a mix of gossip/quests
	'QUEST_COMPLETE',	-- Hide when going from gossip -> complete
	'QUEST_DETAIL',		-- Hide when going from gossip -> detail
	'QUEST_FINISHED',	-- Hide when going from gossip -> finished 
	'QUEST_GREETING',	-- Show quest options, why is this a thing again?
--	'QUEST_IGNORED',	-- Hide when using ignore binding?
	'QUEST_PROGRESS',	-- Hide when going from gossip -> active quest
--	'QUEST_LOG_UPDATE',	-- If quest changes while interacting
}) do titles:RegisterEvent(event) end

titles:RegisterUnitEvent('UNIT_QUEST_LOG_CHANGED', 'player')

----------------------------------
-- Compatibility list
----------------------------------
local compatibility = {
----------------------------------
	['NomiCakes'] = function(self)
		NomiCakesGossipButtonName = _ .. 'TitleButton'
	end,
----------------------------------
	['!KalielsTracker'] = function(self)
		local KTF = _G['!KalielsTrackerFrame']
		L.ToggleIgnoreFrame(KTF, not L('hidetracker'))
		L.options.args.general.args.hide.args.hidetracker.set = function(_, val)
			L.cfg.hidetracker = val 
			L.ToggleIgnoreFrame(ObjectiveTrackerFrame, not val)
			L.ToggleIgnoreFrame(KTF, not val)
		end

		-- this override keeps the tracker from popping back up due to events when faded
		function KTF:SetAlpha(...)
			local newAlpha = ...
			if newAlpha and self.fadeInfo and abs(self:GetAlpha() - newAlpha) > 0.5 then
				return
			end
			getmetatable(self).__index.SetAlpha(self, ...)
		end
	end,
----------------------------------
	['ls_Toasts'] = function(self)
		local type = _G.type
		hooksecurefunc('CreateFrame', function(_, name)
			if type(name) == 'string' and name:match('LSToast') then
				L.ToggleIgnoreFrame(_G[name], true)
			end
		end)
	end,
----------------------------------
}

----------------------------------
-- Load SavedVaribles
----------------------------------
frame.ADDON_LOADED = function(self, name)
	if name == _ then
		local svref = _ .. 'Setup'
		L.cfg = _G[svref] or L.GetDefaultConfig()
		_G[svref] = L.cfg

		-- Set module scales
		talkbox:SetScale(L('boxscale'))
		titles:SetScale(L('titlescale'))
		elements:SetScale(L('elementscale'))
		self:SetScale(L('scale'))

		-- Set the module points
		talkbox:SetPoint(L('boxpoint'), UIParent, L('boxoffsetX'), L('boxoffsetY'))
		titles:SetPoint('CENTER', UIParent, 'CENTER', L('titleoffset'), L('titleoffsetY'))

		self:SetFrameStrata(L('strata'))
		talkbox:SetFrameStrata(L('strata'))

		-- If previous version and flyins were disabled, set anidivisor to instant
		if L.cfg.disableflyin then
			L.cfg.disableflyin = nil
			L.cfg.anidivisor = 1
		end

		-- Set frame ignore for hideUI features on load.
		L.ToggleIgnoreFrame(Minimap, not L('hideminimap'))
		L.ToggleIgnoreFrame(MinimapCluster, not L('hideminimap'))
		L.ToggleIgnoreFrame(ObjectiveTrackerFrame, not L('hidetracker'))

		-- Register options table
		LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable(_, L.options)
		L.config = LibStub('AceConfigDialog-3.0'):AddToBlizOptions(_)

		-- Slash handler
		_G['SLASH_' .. _:upper() .. '1'] = '/' .. _:lower()
		SlashCmdList[_:upper()] = function() LibStub('AceConfigDialog-3.0'):Open(_) end

		-- Add some sexiness to the config frame.
		local logo = CreateFrame('Frame', nil, L.config)
		logo:SetFrameLevel(4)
		logo:SetSize(64, 64)
		logo:SetPoint('TOPRIGHT', 8, 24)
		logo:SetBackdrop({bgFile = ('Interface\\AddOns\\%s\\Textures\\Logo'):format(_)})

		-- Run functions for compatibility with other addons on load.
		-- If the addon in question is already loaded, run the function and remove from list.
		for addOn, func in pairs(compatibility) do
			if select(4, GetAddOnInfo(addOn)) then
				if IsAddOnLoaded(addOn) then
					func(self)
					compatibility[addOn] = nil
				end
			else -- the addon is not going to load, remove it from table.
				compatibility[addOn] = nil
			end
		end
	-- If the compatibility addon loads after Immersion, run the function and remove from list.
	elseif compatibility and compatibility[name] then
		compatibility[name](self)
		compatibility[name] = nil
	end

	-- The compatibility table is empty -> all addons are loaded, disabled or missing.
	-- Garbage collect the table. 
	if not next(compatibility) then
		compatibility = nil
	end

	-- Immersion is loaded, no more addons to track. Garbage collect this function.
	if not compatibility and IsAddOnLoaded(_) then
		self:UnregisterEvent('ADDON_LOADED')
		self.ADDON_LOADED = nil
	end
end

----------------------------------
-- Hide regular frames
----------------------------------
L.HideFrame(GossipFrame)
L.HideFrame(QuestFrame)
--L.HideFrame(ItemTextFrame)
----------------------------------

----------------------------------
-- Set backdrops on elements
----------------------------------
elements:SetBackdrop(L.Backdrops.TALKBOX)
talkbox.Hilite:SetBackdrop(L.Backdrops.GOSSIP_HILITE)

----------------------------------
-- Initiate titlebuttons
----------------------------------
_Mixin(titles, L.TitlesMixin)

----------------------------------
-- Initiate elements
----------------------------------
_Mixin(elements, L.ElementsMixin)

----------------------------------
-- Set up dynamically sized frames
----------------------------------
do
	local AdjustToChildren = L.AdjustToChildren
	_Mixin(elements, AdjustToChildren)
	_Mixin(elements.Content, AdjustToChildren)
	_Mixin(elements.Progress, AdjustToChildren)
	_Mixin(elements.Content.RewardsFrame, AdjustToChildren)
	_Mixin(inspector, AdjustToChildren)
	_Mixin(inspector.Extras, AdjustToChildren)
	_Mixin(inspector.Choices, AdjustToChildren)
end

----------------------------------
-- Set this point here
-- since the anchorpoint didn't
-- exist on load. XML sucks.
----------------------------------
local name = talkbox.NameFrame.Name
name:SetPoint('TOPLEFT', talkbox.PortraitFrame.Portrait, 'TOPRIGHT', 2, -19)


----------------------------------
-- Model script, light
----------------------------------
local model = talkbox.MainFrame.Model
model:SetLight(unpack(L.ModelMixin.LightValues))
_Mixin(model, L.ModelMixin)

----------------------------------
-- Main text things
----------------------------------
local text = talkbox.TextFrame.Text
Mixin(text, L.TextMixin) -- see Text.lua
-- Set array of fonts so the fontstring can be as big as possible without truncating the text
text:SetFontObjectsToTry(SystemFont_Shadow_Large, SystemFont_Shadow_Med2, SystemFont_Shadow_Med1)
-- Run a 'talk' animation on the portrait model whenever a new text is set
hooksecurefunc(text, 'SetNext', function(self, ...)
	local text = ...
	local counter = talkbox.TextFrame.SpeechProgress
	talkbox.TextFrame.FadeIn:Play()
	if text then
		model:PrepareAnimation(model:GetUnit(), text)
		if model:IsNPC() then
			-- Suggests that this phrase is an emote description
			if text:match('%b<>') then
				self:SetVertexColor(1, 0.5, 0)
			else
				self:SetVertexColor(1, 1, 1)
				model:SetRemainingTime(GetTime(), ( self.delays and self.delays[1]))
				if model.asking and not self:IsSequence() then
					model:Ask()
				else
					local yell = model.yelling and random(2) == 2
					if yell then model:Yell() else model:Talk() end
				end
			end
		elseif model:IsPlayer() then
			model:Read()
		end
	end
	
	counter:Hide()
	if self:IsSequence() then
		if not self:IsFinished() then
			counter:Show()
			counter:SetText(self:GetProgress())
		end
	end

	if self:IsVisible() then
		if L('disableprogression') then
			self:StopProgression()
		end
	end
end)

text.OnFinishedCallback = function(self)
	if frame.lastEvent == 'GOSSIP_ONTHEFLY' then
		frame:FadeOut()
	end
end

----------------------------------
-- Misc fixes
----------------------------------
talkbox:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
talkbox:RegisterForDrag('LeftButton')
talkbox.TextFrame.SpeechProgress:SetFont('Fonts\\MORPHEUS.ttf', 16, '')

----------------------------------
-- Set movable frames
----------------------------------
talkbox:SetMovable(true)
talkbox:SetUserPlaced(false)
talkbox:SetClampedToScreen(true)

titles:SetMovable(true)
titles:SetUserPlaced(false)
titles:SetClampedToScreen(true)

----------------------------------
-- Animation things
----------------------------------
local ignoreFrames = {
	[frame] = true,
	[talkbox] = true,
	[inspector] = true,
	[GameTooltip] = true,
	[StaticPopup1] = true,
	[StaticPopup2] = true,
	[StaticPopup3] = true,
	[StaticPopup4] = true,
	[SubZoneTextFrame] = true,
	[OverrideActionBar] = true,
	[ShoppingTooltip1] = true,
	[ShoppingTooltip2] = true,
}

local hideFrames = {
	[Minimap] = true,
	[MinimapCluster] = true,
}

function L.ToggleIgnoreFrame(frame, ignore)
	ignoreFrames[frame] = ignore
end

local function GetUIFrames()
	local frames = {}
	for i, child in pairs({UIParent:GetChildren()}) do
		if not child:IsForbidden() and not ignoreFrames[child] then
			frames[child] = {
				origAlpha = child.fadeInfo and child.fadeInfo.endAlpha or child:GetAlpha(),
				throttle = 0,
			}
		end
	end
	return frames
end

frame.FadeIns = {
	talkbox.MainFrame.InAnim,
	talkbox.NameFrame.FadeIn,
	talkbox.TextFrame.FadeIn,
	talkbox.PortraitFrame.FadeIn,
}

function frame:FadeIn(fadeTime, playAnimations, ignoreFrameFade)
	self.fadeState = 'in'
	L.UIFrameFadeIn(self, fadeTime or 0.2, self:GetAlpha(), 1)
	if ( playAnimations ) and ( self.timeStamp ~= GetTime() ) then
		for _, animation in pairs(self.FadeIns) do
			animation:Play()
		end
	end
	if not ignoreFrameFade and L('hideui') and not self.fadeFrames then
		local frames = GetUIFrames()
		for frame in pairs(frames) do
			L.UIFrameFadeOut(frame, fadeTime or 0.2, frame:GetAlpha(), 0, hideFrames[frame] and {
				finishedFunc = frame.Hide,
				finishedArg1 = frame,
			})
		end
		self.fadeFrames = frames

		-- Track hidden frames and fade them back in if moused over.
		local time = 0
		self:SetScript('OnUpdate', function(self, elapsed)
			time = time + elapsed
			if time > 0.5 then
				if self.fadeFrames then
					for frame, info in pairs(self.fadeFrames) do
						if frame:IsMouseOver() and frame:IsMouseEnabled() then
							if hideFrames[frame] then
								frame:Show()
							end
							L.UIFrameFadeIn(frame, 0.2, frame:GetAlpha(), info.origAlpha)
							info.throttle = 0
						elseif frame:GetAlpha() > 0.1 then
							-- If this frame keeps fading back in then something else is
							-- affecting the alpha change. Stop manipulating the alpha value
							-- of the frame and remove it from the table.
							info.throttle = info.throttle + 1
							if info.throttle > 2 then
								self.fadeFrames[frame] = nil
								L.ToggleIgnoreFrame(frame, true)
								L.UIFrameStopFading(frame)
							else
								L.UIFrameFadeOut(frame, 0.2, frame:GetAlpha(), 0, hideFrames[frame] and {
									finishedFunc = frame.Hide,
									finishedArg1 = frame,
								}) 
							end
						end
					end
				else
					self:SetScript('OnUpdate', nil)
				end
				time = 0
			end
		end)
	end
end

function frame:RestoreFadedFrames()
	if self.fadeFrames then
		for frame, info in pairs(self.fadeFrames) do
			if hideFrames[frame] then
				frame:Show()
			end
			L.UIFrameFadeIn(frame, fadeTime or 0.5, frame:GetAlpha(), info.origAlpha)
		end
		self.fadeFrames = nil
	end
end

function frame:FadeOut(fadeTime, ignoreOnTheFly)
	self.fadeState = 'out'
	L.UIFrameFadeOut(self, fadeTime or 1, self:GetAlpha(), 0, {
		finishedFunc = self.Hide,
		finishedArg1 = self,
	})
	self:RestoreFadedFrames()
end

----------------------------------
-- Hacky hacky
-- Hook the regular talking head,
-- so that the offset is increased
-- when they are shown at the same time.
----------------------------------
hooksecurefunc('TalkingHead_LoadUI', function()
	local thf = TalkingHeadFrame
	if L('boxpoint') == 'Bottom' and thf:IsVisible() then
		talkbox:SetOffset(nil, thf:GetTop() + 8)
	end
	thf:HookScript('OnShow', function(self)
		if L('boxpoint') == 'Bottom' then
			talkbox:SetOffset(nil, self:GetTop() + 8)
		end
	end)
	thf:HookScript('OnHide', function(self)
		if L('boxpoint') == 'Bottom' then
			talkbox:SetOffset()
		end
	end)
end)