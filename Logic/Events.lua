local _, L = ...
local Events, API = L.frame, ImmersionAPI
----------------------------------
-- Events
----------------------------------
function Events:GOSSIP_SHOW(customGossipHandler)
	self:HandleGossipOpenEvent(customGossipHandler)
end

function Events:GOSSIP_CLOSED(...)
	API:CloseGossip(true, ...)
	self:PlayOutro()
	L.ClickedTitleCache = nil
end

function Events:QUEST_GREETING(...)
	self:PlayIntro('QUEST_GREETING')
	self:UpdateTalkingHead(API:GetUnitName('questnpc') or API:GetUnitName('npc'), API:GetGreetingText(), 'AvailableQuest')
end

function Events:QUEST_PROGRESS(...) -- special case, doesn't use QuestInfo
	self:PlayIntro('QUEST_PROGRESS')
	self:AddHint('CROSS', CONTINUE)
	self:ToggleHintState('CROSS', API:IsQuestCompletable())
	self:UpdateTalkingHead(API:GetTitleText(), API:GetProgressText(), API:IsQuestCompletable() and 'ActiveQuest' or 'IncompleteQuest')
	local elements = self.TalkBox.Elements
	local hasItems = elements:ShowProgress('Stone')
	elements:UpdateBoundaries()
	if hasItems then
		local width, height = elements.Progress:GetSize()
		-- Extra: 32 padding + 8 offset from talkbox + 8 px bottom offset
		self.TalkBox:SetExtraOffset((height + 48) * L('elementscale')) 
		return
	end
	self:ResetElements()
end

function Events:QUEST_COMPLETE(...)
	self:PlayIntro('QUEST_COMPLETE')
	self:UpdateTalkingHead(API:GetTitleText(), API:GetRewardText(), 'ActiveQuest')
	self:AddQuestInfo('QUEST_REWARD')
	self:AddHint('CROSS', COMPLETE_QUEST)
end

function Events:QUEST_FINISHED(...)
	API:CloseQuest(true)
	self:PlayOutro()
--	if self:IsGossipAvailable(true) then
--		self:OnEvent('GOSSIP_SHOW')
--		self.TitleButtons:OnEvent('GOSSIP_SHOW')
--	end
end

function Events:QUEST_DETAIL(...)
	if self:IsQuestAutoAccepted(...) then
		self:PlayOutro()
		return
	end
	self:PlayIntro('QUEST_DETAIL')
	self:UpdateTalkingHead(API:GetTitleText(), API:GetQuestText(), 'AvailableQuest')
	self:AddQuestInfo('QUEST_DETAIL')
	self:AddHint('CROSS', ACCEPT)
end


function Events:QUEST_ITEM_UPDATE()
	local questEvent = (self.lastEvent ~= 'QUEST_ITEM_UPDATE') and self.lastEvent or self.questEvent
	self.questEvent = questEvent

	if questEvent and self[questEvent] then
		self[questEvent](self)
		return questEvent
	end
end

function Events:ITEM_TEXT_BEGIN()
	local title = ItemTextGetItem()
	local creator = ItemTextGetCreator()
	if creator then
		title = title .. ' (' .. FROM .. ' ' .. creator .. ')'
	end
	DoEmote('read')
	self:RegisterEvent('PLAYER_STARTED_MOVING')
	self:PlayIntro('ITEM_TEXT_BEGIN')
	self:UpdateTalkingHead(title, '', 'TrainerGossip', 'player')
end

function Events:ITEM_TEXT_READY()
	-- special case: pages need to be concatened together before displaying them.
	-- each new page re-triggers this event, so keep changing page until we run out.
	self.itemText = (self.itemText or '') .. '\n' .. (ItemTextGetText() or '')
	if ItemTextHasNextPage() then
		ItemTextNextPage()
		return
	end
	-- set text directly instead of updating talking head
	self.TalkBox.TextFrame.Text:SetText(self.itemText)
end


function Events:ITEM_TEXT_CLOSED()
	local time = GetTime()
	if not self.readEmoteCancelled and ( self.lastTextClosed ~= time ) then
		DoEmote('read')
	end
	self.lastTextClosed = time
	self.readEmoteCancelled = nil
	self.itemText = nil
	self:UnregisterEvent('PLAYER_STARTED_MOVING')
	self:PlayOutro()
end

function Events:PLAYER_STARTED_MOVING()
	self.readEmoteCancelled = true
	return 'ITEM_TEXT_READY'
end


function Events:NAME_PLATE_UNIT_ADDED()
	self.TalkBox:UpdateNameplateAnchor()
	return self.lastEvent
end

function Events:NAME_PLATE_UNIT_REMOVED()
	self.TalkBox:UpdateNameplateAnchor()
	return self.lastEvent
end

function Events:SUPER_TRACKING_CHANGED()
	self:PlaySuperTrackedQuestToast(ImmersionAPI:GetSuperTrackedQuestID())
	return self.lastEvent
end

function Events:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(type)
	if API:ShouldCloseOnInteraction(type) then
		self:ForceClose(false)
	end
end