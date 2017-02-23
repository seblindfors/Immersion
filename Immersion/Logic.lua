local _, L = ...
local NPC, TalkBox = {}, {}
local frame, GetTime = L.frame, GetTime

----------------------------------
-- Event handler
----------------------------------
function NPC:OnEvent(event, ...)
	self:ResetElements()
	if self[event] then
		if event:match('QUEST') then
			CloseGossip()
		end
		event = self[event](self, ...) or event
	end
	self.TalkBox.lastEvent = event
	self.lastEvent = event
	self.timeStamp = GetTime()
end

----------------------------------
-- Events
----------------------------------
function NPC:GOSSIP_SHOW(...)
	if self:IsGossipAvailable() then
		self:PlayIntro('GOSSIP_SHOW')
		self:UpdateTalkingHead(GetUnitName('npc'), GetGossipText(), 'GossipGossip')
	end
end

function NPC:GOSSIP_CLOSED(...)
	CloseGossip()
	self:PlayOutro()
end

function NPC:QUEST_GREETING(...)
	self:PlayIntro('QUEST_GREETING')
	self:UpdateTalkingHead(GetUnitName('questnpc') or GetUnitName('npc'), GetGreetingText(), 'AvailableQuest')
end

function NPC:QUEST_PROGRESS(...) -- special case, doesn't use QuestInfo
	self:PlayIntro('QUEST_PROGRESS')
	self:UpdateTalkingHead(GetTitleText(), GetProgressText(), IsQuestCompletable() and 'ActiveQuest' or 'IncompleteQuest')
	local elements = self.TalkBox.Elements
	local hasItems = elements:ShowProgress('Stone')
	elements:UpdateBoundaries()
	if hasItems then
		local width, height = elements.Progress:GetSize()
		-- Extra: 32 padding + 8 offset from talkbox + 8 px bottom offset
		self.TalkBox:SetExtraOffset(height + 48) 
		return
	end
	self:ResetElements()
end

function NPC:QUEST_COMPLETE(...)
	self:PlayIntro('QUEST_COMPLETE')
	self:UpdateTalkingHead(GetTitleText(), GetRewardText(), 'ActiveQuest')
	self:AddQuestInfo('QUEST_REWARD')
end

function NPC:QUEST_FINISHED(...)
	CloseQuest()
	self:PlayOutro()
end

function NPC:QUEST_DETAIL(...)
	local questStartItemID = ...
	if ( QuestIsFromAdventureMap() ) or
		( QuestGetAutoAccept() and QuestIsFromAreaTrigger()) or
		(questStartItemID ~= nil and questStartItemID ~= 0) then
		self:PlayOutro()
		return
	end
	self:PlayIntro('QUEST_DETAIL')
	self:UpdateTalkingHead(GetTitleText(), GetQuestText(), 'AvailableQuest')
	self:AddQuestInfo('QUEST_DETAIL', QuestFrameAcceptButton)
end


function NPC:QUEST_ITEM_UPDATE()
	local questEvent = (self.lastEvent ~= 'QUEST_ITEM_UPDATE') and self.lastEvent or self.questEvent
	self.questEvent = questEvent

	if questEvent and self[questEvent] then
		self[questEvent](self)
		return questEvent
	end
end

----------------------------------
-- Content handlers
----------------------------------
function NPC:AddQuestInfo(template, acceptButton)
	local elements = self.TalkBox.Elements
	local content = elements.Content
	local height = elements:Display(template, acceptButton, 'Stone')

	-- hacky fix to stop a content frame that only contains a spacer from showing.
	if height > 20 then
		elements:Show()
		content:Show()
		elements:UpdateBoundaries()
	else
		elements:Hide()
		content:Hide()
	end 
	-- Extra: 32 px padding 
	self.TalkBox:SetExtraOffset(height + 32)
	self.TalkBox.NameFrame.FadeIn:Play()
end

function NPC:IsGossipAvailable()
	-- if there is only a non-gossip option, then go to it directly
	if ( (GetNumGossipAvailableQuests() == 0) and 
		(GetNumGossipActiveQuests() == 0) and 
		(GetNumGossipOptions() == 1) and
		not ForceGossip() ) then
		local text, gossipType = GetGossipOptions()
		if ( gossipType ~= "gossip" ) then
			SelectGossipOption(1)
			return false
		end
	end
	return true
end

function NPC:SelectBestOption()
	local titles = self.TitleButtons.Buttons
	local numActive = self.TitleButtons.numActive
	if numActive > 1 then
		local button = titles[1]
		if button then
			for i=2, numActive do
				local title = titles[i]
				button = button:ComparePriority(title)
			end
			button.Hilite:SetAlpha(1)
			button:Click()
			button:OnLeave()
			PlaySound("igQuestListSelect")
		end
	end
end

function NPC:ResetElements()
	local elements = self.TalkBox.Elements
	for _, frame in pairs(elements.Active) do
		frame:Hide()
	end
	wipe(elements.Active)
	elements:Hide()
	elements.Content:Hide()
	elements.Progress:Hide()
end

function NPC:UpdateTalkingHead(title, text, npcType)
	local unit
	if ( UnitExists('questnpc') and not UnitIsUnit('questnpc', 'player') and not UnitIsDead('questnpc') ) then
		unit = 'questnpc'
	elseif ( UnitExists('npc') and not UnitIsUnit('npc', 'player') and not UnitIsDead('npc') ) then
		unit = 'npc'
	else
		unit = npcType
	end
	local talkBox = self.TalkBox
	talkBox:SetExtraOffset(0)
	talkBox.StatusBar:Show()
	talkBox.MainFrame.Indicator:SetTexture('Interface\\GossipFrame\\' .. npcType .. 'Icon')
	talkBox.MainFrame.Model:SetUnit(unit)
	talkBox.NameFrame.Name:SetText(title)
	talkBox.TextFrame.Text:SetText(text)
end

----------------------------------
-- Animation players
----------------------------------
function NPC:PlayIntro(event)
	local isShown = self:IsVisible()
	self:Show()
	if IsOptionFrameOpen() then
		self:ForceClose()
	else
		self:EnableKeyboard(true)
		local box = self.TalkBox
		self:FadeIn(nil, isShown)
		local point = L('boxpoint')
		local x, y = L('boxoffsetX'), L('boxoffsetY')
		box:ClearAllPoints()
		if not isShown then
			box:SetPoint(point, UIParent, point, -x, -y)
		end
		box:SetOffset(box.offsetX or x, box.offsetY or y)
	end
end

-- This will also hide the frames after the animation is done.
function NPC:PlayOutro()
	self:EnableKeyboard(false)
	self:FadeOut(0.5)
end

function NPC:ForceClose()
	CloseGossip()
	CloseQuest()
	self:PlayOutro()
end

----------------------------------
-- Key input handler
----------------------------------
local inputs = {
	accept = function(self)
		local text = self.TalkBox.TextFrame.Text
		local numActive = self.TitleButtons.numActive
		if IsShiftKeyDown() then
			text:RepeatTexts()
		elseif text:GetNumRemaining() > 1 and text:IsSequence() then
			text:ForceNext()
		elseif self.lastEvent == 'GOSSIP_SHOW' and numActive < 1 then
			CloseGossip()
		elseif self.lastEvent == 'GOSSIP_SHOW' and numActive == 1 then
			SelectGossipOption(1)
		elseif (self.lastEvent == 'GOSSIP_SHOW' or self.lastEvent == 'QUEST_GREETING') and numActive > 1 then
			self:SelectBestOption()
		else
			self.TalkBox:Click(L('flipshortcuts') and 'RightButton' or 'LeftButton')
		end
	end,
	reset = function(self)
		self.TalkBox.TextFrame.Text:RepeatTexts()
	end,
	ignore = function(self)
		if CanIgnoreQuest() then
			IgnoreQuest()
		elseif IsQuestIgnored() then
			UnignoreQuest()
		end
	end,
	goodbye = function(self)
		CloseGossip()
		CloseQuest()
	end,
	number = function(self, id)
		local button = self.TitleButtons.Buttons[id]
		if button then
			button.Hilite:SetAlpha(1)
			button:Click()
			button:OnLeave()
			PlaySound("igQuestListSelect")
		end
	end,
}

function NPC:OnKeyDown(button)
	if button == 'ESCAPE' then
		self:ForceClose()
		return
	end
	local input
	for action, func in pairs(inputs) do
		if L.cfg[action] == button then
			input = func
			break
		end
	end
	if input then
		input(self)
		self:SetPropagateKeyboardInput(false)
	elseif L.cfg.enablenumbers and tonumber(button) then
		inputs.number(self, tonumber(button))
		self:SetPropagateKeyboardInput(false)
	else
		self:SetPropagateKeyboardInput(true)
	end
end

----------------------------------
-- TalkBox button
----------------------------------
function TalkBox:SetOffset(x, y)
	local point = L('boxpoint')
	x = x or L('boxoffsetX')
	y = y or L('boxoffsetY')

	self.offsetX = x
	self.offsetY = y

	local isBottom = ( point == 'Bottom' )
	local isVert = ( isBottom or point == 'Top' )

	y = y +  ( isBottom and self.extraY or 0 )

	local evaluator = self[ 'Get' .. point ]
	local parent = UIParent
	local comp = isVert and y or x
	local func = self[point]

	if not evaluator then
		self:SetPoint(point, parent, x, y)
		return
	end

	self:SetScript('OnUpdate', function(self)
		local offset = (evaluator(self) or 0) - (evaluator(parent) or 0)
		local diff = ( comp - offset )
		if (offset == 0) or abs( comp - offset ) < 0.3 then
			self:SetPoint(point, parent, x, y)
			self:SetScript('OnUpdate', nil)
		elseif isVert then
			self:SetPoint(point, parent, x, offset + ( diff / 10 ))
		else
			self:SetPoint(point, parent, offset + (diff / 10), y)
		end
	end)
end

function TalkBox:OnEnter()
	-- Highlight the button when it can be clicked
	if 	( ( self.lastEvent == 'QUEST_COMPLETE' ) and
		not (self.Elements.itemChoice == 0 and GetNumQuestChoices() > 1) ) or
		( self.lastEvent == 'QUEST_DETAIL' ) or
		( self.lastEvent ~= 'GOSSIP_SHOW' and IsQuestCompletable() ) then
		L.UIFrameFadeIn(self.Hilite, 0.15, self.Hilite:GetAlpha(), 1)
	end
end

function TalkBox:OnLeave()
	L.UIFrameFadeOut(self.Hilite, 0.15, self.Hilite:GetAlpha(), 0)
end

function TalkBox:OnClick(button)
	if L('flipshortcuts') then
		button = button == 'LeftButton' and 'RightButton' or 'LeftButton'
	end
	if button == 'LeftButton' then
		-- Complete quest
		if self.lastEvent == 'QUEST_COMPLETE' then
			self.Elements:CompleteQuest()
		-- Accept quest
		elseif self.lastEvent == 'QUEST_DETAIL' then
			QuestFrameAcceptButton:Click()
		-- Progress quest to completion
		elseif IsQuestCompletable() then
			CompleteQuest()
		end
	elseif button == 'RightButton' then
		local text = self.TextFrame.Text
		if text:GetNumRemaining() > 1 and text:IsSequence() then
			text:ForceNext()
		elseif text:IsSequence() then
			text:RepeatTexts()
		end
	end
end

function TalkBox:SetExtraOffset(newOffset)
	local currX = ( self.offsetX or L('boxoffsetX') )
	local currY = ( self.offsetY or L('boxoffsetY') )
	self.extraY = newOffset
	self:SetOffset(currX, currY)
end

----------------------------------
-- Mixin with scripts
----------------------------------
L.Mixin(frame, NPC)
L.Mixin(frame.TalkBox, TalkBox)