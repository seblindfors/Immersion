----------------------------------
-- These are things that
-- are more easily handled in lua
-- than XML, but have to do with
-- the initial setup.
----------------------------------
local _, L = ...
local frame = _G[ _ .. 'Frame' ]
local talkbox = frame.TalkBox
local titles = frame.TitleButtons
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
	'GOSSIP_CLOSED',	-- Close gossip frame
	'GOSSIP_SHOW',		-- Show gossip options, can be a mix of gossip/quests
	'QUEST_COMPLETE',	-- Quest completed
	'QUEST_DETAIL',		-- Quest details/objectives/accept frame
	'QUEST_FINISHED',	-- Fires when quest frame is closed
	'QUEST_GREETING',	-- Multiple quests to choose from, but no gossip options
	'QUEST_IGNORED',	-- Ignore the currently shown quest
	'QUEST_PROGRESS',	-- Fires when you click on a quest you're currently on
	'QUEST_ITEM_UPDATE', -- Item update while in convo, refresh frames.
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
	'QUEST_IGNORED',	-- Hide when using ignore binding?
	'QUEST_PROGRESS',	-- Hide when going from gossip -> active quest
	'QUEST_LOG_UPDATE',	-- If quest changes while interacting
}) do titles:RegisterEvent(event) end

----------------------------------
-- Load SavedVaribles
----------------------------------
frame.ADDON_LOADED = function(self, name)
	if name == _ then
		-- NomiCakes fix
		if select(4, GetAddOnInfo('NomiCakes')) then
			function self:ADDON_LOADED(name)
				if name == 'NomiCakes' then
					NomiCakesGossipButtonName = _ .. 'TitleButton'
					self.ADDON_LOADED = nil
					self:UnregisterEvent('ADDON_LOADED')
				end
			end
		else
			self.ADDON_LOADED = nil
			self:UnregisterEvent('ADDON_LOADED')
		end

		local svref = _ .. 'Setup'
		L.cfg = _G[svref] or L.GetDefaultConfig()
		_G[svref] = L.cfg

		talkbox:SetScale(L('boxscale'))
		titles:SetScale(L('titlescale'))
		self:SetScale(L('scale'))

		talkbox:SetPoint(L('boxpoint'), UIParent, L('boxoffsetX'), L('boxoffsetY'))
		titles:SetPoint('CENTER', UIParent, 'CENTER', L('titleoffset'), 0)

		self:SetFrameStrata(L('strata'))
		talkbox:SetFrameStrata(L('strata'))

		-- Register options table
		LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable(_, L.options)
		L.config = LibStub('AceConfigDialog-3.0'):AddToBlizOptions(_)

		-- Slash handler
		_G['SLASH_' .. _:upper() .. '1'] = '/' .. _:lower()
		SlashCmdList[_:upper()] = function() LibStub('AceConfigDialog-3.0'):Open(_) end

		local logo = CreateFrame('Frame', nil, L.config)
		logo:SetFrameLevel(4)
		logo:SetSize(100, 100)
		logo:SetPoint('BOTTOMRIGHT', -16, 16)
		logo:SetBackdrop({bgFile = ('Interface\\AddOns\\%s\\Textures\\Logo'):format(_)})
	end
end

----------------------------------
-- Hide regular frames
----------------------------------
L.HideFrame(GossipFrame) GossipFrame:UnregisterAllEvents()
L.HideFrame(QuestFrame) QuestFrame:UnregisterAllEvents()
----------------------------------

----------------------------------
-- Set backdrops on elements
----------------------------------
talkbox.Elements:SetBackdrop(L.Backdrops.TALKBOX)
talkbox.Hilite:SetBackdrop(L.Backdrops.GOSSIP_HILITE)

----------------------------------
-- Initiate titlebuttons
----------------------------------
L.Mixin(titles, L.TitlesMixin)

----------------------------------
-- Initiate elements
----------------------------------
L.Mixin(talkbox.Elements, L.ElementsMixin)

----------------------------------
-- Set this point here
-- since the anchorpoint didn't
-- exist on load.
----------------------------------
local name = talkbox.NameFrame.Name
name:SetPoint('TOPLEFT', talkbox.PortraitFrame.Portrait, 'TOPRIGHT', 2, -19)


----------------------------------
-- Model script, light
----------------------------------
local model = talkbox.MainFrame.Model
model:SetLight(unpack(L.ModelMixin.LightValues))
L.Mixin(model, L.ModelMixin)

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
			if not text:match('%b<>') then
				self:SetVertexColor(1, 1, 1)
				model:SetRemainingTime(GetTime(), ( self.delays and self.delays[1]))
				if model.asking and not self:IsSequence() then
					model:Ask()
				else
					local yell = model.yelling and random(2) == 2
					if yell then model:Yell() else model:Talk() end
				end
			else
				self:SetVertexColor(1, 0.5, 0)
			end
		elseif model:IsPlayer() then
			model:Read()
		end
	end

	if self:IsVisible() then
		counter:Hide()
		if self:IsSequence() then
			if not self:IsFinished() then
				counter:Show()
				counter:SetText(self:GetProgress())
			end
		end
		if L('disableprogression') then
			self:StopProgression()
		end
	end
end)

----------------------------------
-- Misc fixes
----------------------------------
talkbox:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
talkbox.TextFrame.SpeechProgress:SetFont('Fonts\\MORPHEUS.ttf', 16, '')
L.Mixin(talkbox.Elements, L.AdjustToChildren)
L.Mixin(talkbox.Elements.Content, L.AdjustToChildren)
L.Mixin(talkbox.Elements.Progress, L.AdjustToChildren)

----------------------------------
-- Animation things
----------------------------------
local ignoreFrames = {
	[frame] = true,
	[talkbox] = true,
	[GameTooltip] = true,
	[StaticPopup1] = true,
	[StaticPopup2] = true,
	[StaticPopup3] = true,
	[StaticPopup4] = true,
	[ShoppingTooltip1] = true,
	[ShoppingTooltip2] = true,
}

local function GetUIFrames()
	local frames = {}
	for i, child in pairs({UIParent:GetChildren()}) do
		if not child:IsForbidden() and not ignoreFrames[child] then
			frames[child] = child.fadeInfo and child.fadeInfo.endAlpha or child:GetAlpha()
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

frame.FadeIn = function(self, fadeTime, stopPlay)
	L.UIFrameFadeIn(self, fadeTime or 0.2, self:GetAlpha(), 1)
	if ( not stopPlay ) and ( self.timeStamp ~= GetTime() ) then
		for _, Fader in pairs(self.FadeIns) do
			Fader:Play()
		end
	end
	if L('hideui') and not self.fadeFrames then
		local frames = GetUIFrames()
		for frame in pairs(frames) do
			L.UIFrameFadeOut(frame, fadeTime or 0.2, frame:GetAlpha(), 0)
		end
		self.fadeFrames = frames

		-- Track hidden frames and fade them back in if moused over.
		local time = 0
		self:SetScript('OnUpdate', function(self, elapsed)
			time = time + elapsed
			if time > 0.5 then
				if self.fadeFrames then
					for frame, origAlpha in pairs(self.fadeFrames) do
						if frame:IsMouseOver() and frame:IsMouseEnabled() then
							L.UIFrameFadeIn(frame, 0.2, frame:GetAlpha(), origAlpha)
						elseif frame:GetAlpha() > 0.1 then
							L.UIFrameFadeOut(frame, 0.2, frame:GetAlpha(), 0) 
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

frame.FadeOut = function(self, fadeTime)
	L.UIFrameFadeOut(self, fadeTime or 1, self:GetAlpha(), 0, {
		finishedFunc = self.Hide,
		finishedArg1 = self,
	})
	if self.fadeFrames then
		for frame, origAlpha in pairs(self.fadeFrames) do
			L.UIFrameFadeIn(frame, fadeTime or 0.5, frame:GetAlpha(), origAlpha)
		end
		self.fadeFrames = nil
	end
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