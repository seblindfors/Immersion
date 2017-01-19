----------------------------------
-- These are things that
-- are more easily handled in lua
-- than XML, but have to do with
-- the initial setup.
----------------------------------
local _, L = ...
local frame = _G[ _ .. 'Frame' ]
local talkbox = frame.TalkBox
L.frame = frame

----------------------------------
-- Prepare propagation, so that we
-- can catch certain key strokes
-- but propagate the event otherwise.
----------------------------------
frame:SetPropagateKeyboardInput(true)

----------------------------------
-- Register events
----------------------------------
for _, event in pairs({
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
-- TitleButtons
----------------------------------
frame.TitleButtons.Active = {}
frame.TitleButtons.Buttons = {
	Gossip = {},
	Quest = {},
}

-- Create 2 sets of 32 buttons
-- to mimic gossip/quest title buttons.
for _, bType in pairs({'Gossip', 'Quest'}) do
	for i=1, NUMGOSSIPBUTTONS do
		local button = CreateFrame('Button', nil, frame.TitleButtons)
		-- Button.lua, Extras.lua
		L.Mixin(button, L.ButtonMixin, L.Mixins.ScaleOnFocus)
		button:SetID(i)
		button.NPC = bType
		button:Init()
	end
end

----------------------------------
-- Hide regular frames
----------------------------------
L.HideFrame(GossipFrame)
L.HideFrame(QuestFrame)
----------------------------------

----------------------------------
-- Set talkbox look on elements
----------------------------------
talkbox.Elements:SetBackdrop(L.Backdrops.TALKBOX)

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
model:SetLight(true, false, -250, 0, 0, 0.25, 1, 1, 1, 75, 1, 1, 1)
model:SetScript('OnAnimFinished', function(self)
	if self.reading then
		self:SetAnimation(520)
	elseif self.delay and self.timestamp then
		local time = GetTime()
		local diff = time - self.timestamp
		-- shave off a second to avoid awkwardly long animation sequences
		if diff < ( self.delay - 1 ) then
			self.timestamp = time
			self.delay = ( self.delay - 1 ) - diff
			self.talking = true
			if self.asking then
				self:SetAnimation(65)
			else
				local yell = self.yelling and ( random(2) == 2 )
				self:SetAnimation(yell and 64 or 60)
			end
		else
			self.timestamp = nil
			self.delay = nil
			self.talking = nil
			self.yelling = nil
			self.asking = nil
			self:SetAnimation(0)
		end 
	elseif self.talking then
		self.talking = nil
		self.yelling = nil
		self:SetAnimation(0)
	end
end)

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
		if ( model.unit == 'npc' or model.unit == 'questnpc' ) then
			if not text:match('%b<>') then
				self:SetVertexColor(1, 1, 1)
				model.delay = self.delays and self.delays[1]
				model.timestamp = GetTime()
				model.asking = text:match('?')
				model.yelling = text:match('!')
				model.reading = false
				model.talking = true
				if model.asking and not self:IsSequence() then
					model:SetAnimation(65)
				else
					local yell = model.yelling and random(2) == 2
					model:SetAnimation(yell and 64 or 60)
				end
			else
				self:SetVertexColor(1, 0.5, 0)
			end
		elseif model.unit == 'player' then
			model.reading = true
			model:SetAnimation(520)
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
talkbox.TextFrame.SpeechProgress:SetFont('Fonts\\MORPHEUS.ttf', 16, '')
talkbox:SetScale(1.1) -- a bit small with 1.0 on default UI scale

----------------------------------
-- Animation things
----------------------------------
frame.FadeIns = {
	talkbox.MainFrame.InAnim,
	talkbox.NameFrame.FadeIn,
	talkbox.TextFrame.FadeIn,
	talkbox.PortraitFrame.FadeIn,
}

frame.FadeIn = function(self, fadeTime)
	L.UIFrameFadeIn(self, fadeTime or 0.2, self:GetAlpha(), 1)
	if self.timeStamp ~= GetTime() then
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
-- Hook the regular talking head,
-- so that the offset is increased
-- when they are shown at the same time.
----------------------------------
hooksecurefunc('TalkingHead_LoadUI', function()
	local thf = TalkingHeadFrame
	if thf:IsVisible() then
		talkbox:SetOffset(thf:GetTop() + 4)
	end
	thf:HookScript('OnShow', function(self)
		talkbox:SetOffset(self:GetTop() + 4)
	end)
	thf:HookScript('OnHide', function(self)
		talkbox:SetOffset(150)
	end)
end)