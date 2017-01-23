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
		self:UnregisterEvent('ADDON_LOADED')
		self.ADDON_LOADED = nil

		local svref = _ .. 'Setup'
		L.cfg = _G[svref] or L.GetDefaultConfig()
		_G[svref] = L.cfg

		talkbox:SetScale(L.Get('boxscale'))
		titles:SetScale(L.Get('titlescale'))
		self:SetScale(L.Get('scale'))

		local bPoint = L.Get('boxpoint')
		talkbox:SetPoint(bPoint, UIParent, bPoint, L.Get('boxoffsetX'), L.Get('boxoffsetY'))

		titles:SetPoint('CENTER', UIParent, 'CENTER', L.Get('titleoffset'), 0)

		LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable(_, L.options)
		L.config = LibStub('AceConfigDialog-3.0'):AddToBlizOptions(_)

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
L.HideFrame(QuestFrame)
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
end

frame.FadeOut = function(self, fadeTime)
	L.UIFrameFadeOut(self, fadeTime or 1, self:GetAlpha(), 0, {
		finishedFunc = self.Hide,
		finishedArg1 = self,
	})
end

----------------------------------
-- Hacky hacky
-- Hook the regular talking head,
-- so that the offset is increased
-- when they are shown at the same time.
----------------------------------
hooksecurefunc('TalkingHead_LoadUI', function()
	local thf = TalkingHeadFrame
	if L.Get('boxpoint') == 'Bottom' and thf:IsVisible() then
		talkbox:SetOffset(nil, thf:GetTop() + 8)
	end
	thf:HookScript('OnShow', function(self)
		if L.Get('boxpoint') == 'Bottom' then
			talkbox:SetOffset(nil, self:GetTop() + 8)
		end
	end)
	thf:HookScript('OnHide', function(self)
		if L.Get('boxpoint') == 'Bottom' then
			talkbox:SetOffset()
		end
	end)
end)