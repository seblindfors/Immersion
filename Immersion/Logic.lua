local _, L = ...
local TEMPLATE, NPC, TalkBox = {}, {}, {}
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
		self[event](self, ...)
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
	local textColor, titleTextColor = GetMaterialTextColors('Stone')
	elements.Progress.ReqText:SetTextColor(unpack(titleTextColor))
	elements.Progress.MoneyText:SetTextColor(unpack(textColor))
	elements:Show()
	elements:SetHeight(1)
	elements.Progress:Show()
	QuestFrameProgressItems_Update() -- remove this later
	elements:AdjustToChildren()
	for _, child in pairs({elements.Progress:GetChildren()}) do
		if child:IsVisible() then
			-- add some padding to get the backdrop to wrap the frame properly.
			local height = elements.Progress:GetHeight() + 90
			elements:SetSize(364, height)
			elements.Progress:SetHeight(height)
			self.TalkBox:SetExtraOffset(height - 16)
			return -- something was visible, break out.
		end
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

----------------------------------
-- Content handlers
----------------------------------
function NPC:AddQuestInfo(template, acceptButton)
	local elements = self.TalkBox.Elements
	local content = elements.Content
	local height = elements:Display(template, QuestFrameAcceptButton, 'Stone')


	-- QuestInfo_Display(template, content, QuestFrameAcceptButton, 'Stone')
	-- local elementsTable = template.elements
	-- local height, lastFrame = 0
	-- for i = 1, #elementsTable, 3 do -- a wonderfully confusing vanilla relic
	-- 	local shownFrame, bottomShownFrame = elementsTable[i]()
	-- 	if ( shownFrame ) then
	-- 		shownFrame:SetParent(content)
	-- 		height = height + shownFrame:GetHeight() + abs(elementsTable[i+2])
	-- 		if ( lastFrame ) then
	-- 			shownFrame:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', elementsTable[i+1], elementsTable[i+2])
	-- 		else
	-- 			shownFrame:SetPoint('TOPLEFT', content, 'TOPLEFT', elementsTable[i+1] + 32, elementsTable[i+2] - 16)	
	-- 		end
	-- 		shownFrame:Show()
	-- 		elements.Active[#elements.Active + 1] = shownFrame
	-- 		lastFrame = bottomShownFrame or shownFrame
	-- 	end
	-- end

	-- hacky fix to stop a content frame that only contains a spacer from showing.
	if height > 20 then
		elements:SetSize(570, height + 32)
		elements:Show()
		content:Show()
	else
		elements:Hide()
		content:Hide()
	end
	self.TalkBox:SetExtraOffset(height)
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
		unit = 'player'
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
		local point = L.Get('boxpoint')
		local x, y = L.Get('boxoffsetX'), L.Get('boxoffsetY')
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
			self.TalkBox:Click('LeftButton')
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
	local point = L.Get('boxpoint')
	x = x or L.Get('boxoffsetX')
	y = y or L.Get('boxoffsetY')

	self.offsetX = x
	self.offsetY = y

	local isBottom = ( point == 'Bottom' )
	local isVert = ( isBottom or point == 'Top' )

	y = y +  ( isBottom and self.extraY or 0 )

	local evaluator = self[ 'Get' .. point ]
	local parent = UIParent
	local comp = isVert and y or x
	local func = self[point]

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
		not (QuestInfoFrame.itemChoice == 0 and GetNumQuestChoices() > 1) ) or
		( self.lastEvent == 'QUEST_DETAIL' ) or
		( self.lastEvent ~= 'GOSSIP_SHOW' and IsQuestCompletable() ) then
		L.UIFrameFadeIn(self.Hilite, 0.15, self.Hilite:GetAlpha(), 1)
	end
end

function TalkBox:OnLeave()
	L.UIFrameFadeOut(self.Hilite, 0.15, self.Hilite:GetAlpha(), 0)
end

function TalkBox:OnClick(button)
	if button == 'LeftButton' then
		-- Complete quest
		if self.lastEvent == 'QUEST_COMPLETE' then
			-- check if multiple items to choose between and none chosen
			if not (QuestInfoFrame.itemChoice == 0 and GetNumQuestChoices() > 1) then
				QuestFrameCompleteQuestButton:Click()
			end
		-- Accept quest
		elseif self.lastEvent == 'QUEST_DETAIL' then
			QuestFrameAcceptButton:Click()
		-- Progress quest (why are these functions named like this?)
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
	local currX = ( self.offsetX or L.Get('boxoffsetX') )
	local currY = ( self.offsetY or L.Get('boxoffsetY') )
	self.extraY = newOffset
	self:SetOffset(currX, currY)
end

----------------------------------
-- Mixin with scripts
----------------------------------
L.Mixin(frame, NPC)
L.Mixin(frame.TalkBox, TalkBox)

----------------------------------
-- Quest templates
----------------------------------
TEMPLATE.QUEST_DETAIL = { questLog = nil, chooseItems = nil, contentWidth = 450,
	canHaveSealMaterial = nil, sealXOffset = 160, sealYOffset = -6,
	elements = {
		QuestInfo_ShowObjectivesHeader, 0, -15,	
		QuestInfo_ShowObjectivesText, 0, -5,
		QuestInfo_ShowSpecialObjectives, 0, -10,
		QuestInfo_ShowGroupSize, 0, -10,
		QuestInfo_ShowRewards, 0, -15,
		QuestInfo_ShowSpacer, 0, -15,
	}
}

TEMPLATE.QUEST_REWARD = { questLog = nil, chooseItems = true, contentWidth = 450,
	canHaveSealMaterial = nil, sealXOffset = 160, sealYOffset = -6,
	elements = {
	--	QuestInfo_ShowTitle, 5, -10,
	--	QuestInfo_ShowRewardText, 0, -5,
		QuestInfo_ShowRewards, 0, -10,
		QuestInfo_ShowSpacer, 0, -10
	}
}