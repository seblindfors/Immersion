local _, L = ...
local TEMPLATE, NPC, Titles, TalkBox = {}, {}, {}, {}
local frame, GetTime = L.frame, GetTime

----------------------------------
-- Title button helpers
----------------------------------
function NPC:ResetButtons() self.TitleButtons:Hide() end
function NPC:ShowButtons() self.TitleButtons:Show() end

----------------------------------
-- Event handler
----------------------------------
function NPC:OnEvent(event, ...)
	self:ResetButtons()
	self:ResetElements()
	if self[event] then
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
	self:PlayIntro('GOSSIP_SHOW')
	self:ShowButtons()
	self:UpdateTalkingHead(GetUnitName('npc'), GetGossipText(), 'GossipGossip')
	NPCFriendshipStatusBar_Update(self.TalkBox)
	NPCFriendshipStatusBar:ClearAllPoints()
	NPCFriendshipStatusBar:SetStatusBarColor(0.5, 0.7, 1)
	NPCFriendshipStatusBar:SetPoint('TOPLEFT', self.TalkBox, 'TOPLEFT', 32, 0)
end

function NPC:GOSSIP_CLOSED(...)
	self:ResetButtons()
	self:PlayOutro()
end

function NPC:QUEST_GREETING(...)
	self:PlayIntro('QUEST_GREETING')
	self:UpdateTalkingHead(GetUnitName('questnpc') or GetUnitName('npc'), GetGreetingText(), 'AvailableQuest')
	self:ShowButtons()
end

function NPC:QUEST_PROGRESS(...) -- special case, doesn't use QuestInfo
	self:PlayIntro('QUEST_PROGRESS')
	local npcType
	if IsQuestCompletable() then
		npcType = 'ActiveQuest'
	else
		npcType = 'IncompleteQuest'
	end
	self:UpdateTalkingHead(GetTitleText(), GetProgressText(), npcType)
	local elements = self.TalkBox.Elements
	local textColor, titleTextColor = GetMaterialTextColors('Stone')
	elements.Progress.ReqText:SetTextColor(unpack(titleTextColor))
	elements.Progress.MoneyText:SetTextColor(unpack(textColor))
	elements:Show()
	elements:SetHeight(1)
	elements.Progress:Show()
	local top, offset = elements:GetTop()
	for _, child in pairs({elements.Progress:GetRegions(), elements.Progress:GetChildren()}) do
		if child:IsVisible() then
			local childOffset = child:GetBottom()
			if childOffset and ( not offset or childOffset < offset ) then
				offset = childOffset
			end
		end
	end
	if offset then
		local atop, aoff = abs(top), abs(offset)
		local newHeight = abs(offset) - abs(top) + 32
		elements:SetSize(364, newHeight)
		elements.Progress:SetHeight(newHeight)
		self.TalkBox:SetExtraOffset(newHeight - 16)
	else
		self:ResetElements()
	end
end

function NPC:QUEST_COMPLETE(...)
	self:PlayIntro('QUEST_COMPLETE')
	self:UpdateTalkingHead(GetTitleText(), GetRewardText(), 'ActiveQuest')
	self:AddQuestInfo(TEMPLATE.QUEST_REWARD)
end

function NPC:QUEST_FINISHED(...)
	self:PlayOutro()
end

function NPC:QUEST_DETAIL(...)
	self:PlayIntro('QUEST_DETAIL')
	self:UpdateTalkingHead(GetTitleText(), GetQuestText(), 'AvailableQuest')
	self:AddQuestInfo(TEMPLATE.QUEST_DETAIL, QuestFrameAcceptButton)
end

----------------------------------
-- Content handlers
----------------------------------
function NPC:AddQuestInfo(template, acceptButton)
	local elements = self.TalkBox.Elements
	local content = elements.Content
	QuestInfo_Display(template, content, QuestFrameAcceptButton, 'Stone')
	local elementsTable = template.elements
	local height, lastFrame = 0
	for i = 1, #elementsTable, 3 do -- a wonderfully confusing vanilla relic
		local shownFrame, bottomShownFrame = elementsTable[i]()
		if ( shownFrame ) then
			shownFrame:SetParent(content)
			height = height + shownFrame:GetHeight() + abs(elementsTable[i+2])
			if ( lastFrame ) then
				shownFrame:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', elementsTable[i+1], elementsTable[i+2])
			else
				shownFrame:SetPoint('TOPLEFT', content, 'TOPLEFT', elementsTable[i+1] + 32, elementsTable[i+2] - 16)	
			end
			shownFrame:Show()
			elements.Active[#elements.Active + 1] = shownFrame
			lastFrame = bottomShownFrame or shownFrame
		end
	end
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
	local zoom = ( unit and unit == 'player' ) and 0.82 or 0.85
	local talkBox = self.TalkBox
	talkBox:SetExtraOffset(0)
	talkBox.MainFrame.Indicator:SetTexture('Interface\\GossipFrame\\' .. npcType .. 'Icon')
	talkBox.MainFrame.Model.unit = unit
	talkBox.NameFrame.Name:SetText(title)
	talkBox.TextFrame.Text:SetText(text)
	talkBox.MainFrame.Model:SetUnit(unit)
	talkBox.MainFrame.Model:SetPortraitZoom(zoom)
end

----------------------------------
-- Animation players
----------------------------------
function NPC:PlayIntro(event)
	self:Show()
	if IsOptionFrameOpen() then
		CloseGossip()
		CloseQuest()
	else
		self:EnableKeyboard(true)
		local box = self.TalkBox
		-- Handles the case of gossip -> gossip
		if self.lastEvent ~= event then
			self:FadeIn()
			box:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, -150)
			box:SetOffset(box.offset or 150)
		end
	end
end

-- This will also hide the frames after the animation is done.
function NPC:PlayOutro()
	self:EnableKeyboard(false)
	self:FadeOut(0.5)
end

----------------------------------
-- Key input handler
----------------------------------
local inputs = {
	accept = function(self)
		local text = self.TalkBox.TextFrame.Text
		if IsShiftKeyDown() then
			text:RepeatTexts()
		elseif text:GetNumRemaining() > 1 and text:IsSequence() then
			text:ForceNext()
		elseif self.lastEvent == 'GOSSIP_SHOW' and GetNumGossipOptions() < 1 then
			CloseGossip()
		elseif self.lastEvent == 'GOSSIP_SHOW' and GetNumGossipOptions() == 1 then
			SelectGossipOption(1)
		else
			self.TalkBox:Click()
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
		local active, count = self.TitleButtons.Active, 0
		local button
		for i=1, NUMGOSSIPBUTTONS do
			local active = self.TitleButtons.Active[i]
			if active then
				count = count + 1
				if count == id then
					button = active
				end
			end
		end
		if button then
			button.Hilite:SetAlpha(1)
			button:Click()
			button:OnLeave()
			PlaySound("igQuestListSelect")
		end
	end,
}

function NPC:OnKeyDown(button)
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
-- Title buttons (gossip/quest x32)
----------------------------------
function Titles:AdjustHeight(newHeight)
	self:SetScript('OnUpdate', function(self)
		local height = self:GetHeight()
		local diff = newHeight - height
		if abs(newHeight - height) < 0.05 then
			self:SetHeight(newHeight)
			self:SetScript('OnUpdate', nil)
		else
			self:SetHeight(height + ( diff / 10 ) )
		end
	end)
end

function Titles:OnShow()
	self:SetHeight(0)
end

function Titles:OnHide()
	for i, button in pairs(self.Active) do
		button:UnlockHighlight()
	end
	wipe(self.Active)
	self.focus = nil
end

function Titles:GetNumActive()
	return self.numActive or 0
end

function Titles:UpdateActive(button)
	self.Active[button:GetID()] = button:IsVisible() and button or nil
	local newHeight, numActive = 0, 0
	for i, button in pairs(self.Active) do
		newHeight = newHeight + button:GetHeight()
		numActive = numActive + 1
	end
	self.numActive = numActive
	self:AdjustHeight(newHeight)
end

----------------------------------
-- TalkBox button
----------------------------------
function TalkBox:SetOffset(newOffset)
	newOffset = newOffset or ( L.cfg.boxoffset or 150)
	self.offset = newOffset
	newOffset = newOffset + ( self.extraOffset or 0 )
	self:SetScript('OnUpdate', function(self)
		local offset = self:GetBottom()
		local diff = newOffset - offset
		if abs(newOffset - offset) < 0.05 then
			self:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, newOffset)
			self:SetScript('OnUpdate', nil)
		else
			self:SetPoint('BOTTOM', UIParent, 'BOTTOM', 0, offset + ( diff / 10) )
		end
	end)
end

function TalkBox:OnClick()
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
end

function TalkBox:SetExtraOffset(newOffset)
	self.extraOffset = newOffset
	self:SetOffset(self.offset or (L.cfg.boxoffset or 150) )
end

----------------------------------
-- Mixin with scripts
----------------------------------
L.Mixin(frame, NPC)
L.Mixin(frame.TalkBox, TalkBox)
L.Mixin(frame.TitleButtons, Titles)

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