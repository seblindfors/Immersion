local _, L = ...
local NPC, TalkBox = {}, {}
local frame, GetTime = L.frame, GetTime

----------------------------------
-- Event handler
----------------------------------
function NPC:OnEvent(event, ...)
	self:ResetElements(event)
	if self[event] then
		if event:match('QUEST') then
			CloseGossip()
		end
		event = self[event](self, ...) or event
	end
	self.TalkBox.lastEvent = event
	self.lastEvent = event
	self.timeStamp = GetTime()
	self:UpdateItems()
	return event
end

----------------------------------
-- Events
----------------------------------
function NPC:GOSSIP_SHOW(...)
	self:UpdateTalkingHead(GetUnitName('npc'), GetGossipText(), 'GossipGossip')
	if self:IsGossipAvailable() then
		self:PlayIntro('GOSSIP_SHOW')
	end
end

function NPC:GOSSIP_CLOSED(...)
	CloseGossip()
	self:PlayOutro()
	if self:IsGossipOnTheFly() and self.lastEvent == 'GOSSIP_SHOW' then
		return self:OnEvent('GOSSIP_ONTHEFLY')
	end
end

function NPC:GOSSIP_ONTHEFLY(...)
	self.TalkBox:SetExtraOffset(0)
	self:PlayIntro('GOSSIP_ONTHEFLY', true)
	return 'GOSSIP_ONTHEFLY'
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

function NPC:QUEST_ACCEPTED(...)
	if self:IsGossipOnTheFly() then
		return self:OnEvent('GOSSIP_ONTHEFLY')
	end
end

function NPC:QUEST_FINISHED(...)
	CloseQuest()
	self:PlayOutro()
end

function NPC:QUEST_DETAIL(...)
--	if self:IsQuestAutoAccept(...) then
--		self:PlayOutro()
---		return
--	end
	self:PlayIntro('QUEST_DETAIL')
	self:UpdateTalkingHead(GetTitleText(), GetQuestText(), 'AvailableQuest')
	self:AddQuestInfo('QUEST_DETAIL')
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
-- Content handler (gossip & quest)
----------------------------------
function NPC:AddQuestInfo(template)
	local elements = self.TalkBox.Elements
	local content = elements.Content
	local height = elements:Display(template, 'Stone')

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

function NPC:IsQuestAutoAccept(...)
	local questStartItemID = ...
	return ( QuestIsFromAdventureMap() ) or
		( QuestGetAutoAccept() and QuestIsFromAreaTrigger() ) or
		( questStartItemID ~= nil and questStartItemID ~= 0 )
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

function NPC:GetRemainingSpeechTime()
	return self.TalkBox.TextFrame.Text:GetTimeRemaining()
end

function NPC:IsGossipOnTheFly()
	return -- no idea whether this works properly.
		L('onthefly') and 
		( self:GetRemainingSpeechTime() > 0 ) and
		self.lastEvent ~= 'QUEST_DETAIL' and
		not self:IsQuestAutoAccept()
end

function NPC:ResetElements(event)
	if event == 'QUEST_ACCEPTED' then
		return -- do not reset elements on this event,
		--------- because it fires on auto-accepted quests.
	end
	self.Inspector:Hide()
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
-- Content handler (items)
----------------------------------
function NPC:SetItemTooltip(tooltip, item)
	local objType = item.objectType
	if objType == 'item' then
		tooltip:SetQuestItem(item.type, item:GetID())
	elseif objType == 'currency' then
		tooltip:SetQuestCurrency(item.type, item:GetID())
	end
	tooltip.Icon.Texture:SetTexture(item.itemTexture or item.Icon:GetTexture())
end

function NPC:GetItemColumn(owner, id)
	local columns = owner and owner.Columns
	if columns and id then
		local column = columns[id]
		local anchor = columns[id - 1]
		if not column then
			column = CreateFrame('Frame', nil, owner)
			column:SetSize(1, 1) -- set size to make sure children are drawn
			column:SetFrameStrata("FULLSCREEN_DIALOG")
			L.Mixin(column, L.AdjustToChildren)
			columns[id] = column
		end
		if anchor then
			column:SetPoint('TOPLEFT', anchor, 'TOPRIGHT', 30, 0)
		else
			column:SetPoint('TOPLEFT', owner, 0, -30)
		end
		column:Show()
		return column
	end
end

function NPC:ShowItems()
	local inspector = self.Inspector
	local items, hasChoice, hasExtra = inspector.Items
	local extras, choices = inspector.Extras, inspector.Choices
	inspector:Show()
	for id, item in pairs(items) do
		local tooltip = inspector.tooltipFramePool:Acquire()
		local owner = item.type == 'choice' and choices or extras
		local columnID = ( id % 3 == 0 ) and 3 or ( id % 3 )
		local column = self:GetItemColumn(owner, columnID)

		hasChoice = hasChoice or item.type == 'choice'
		hasExtra = hasExtra or item.type ~= 'choice'

		tooltip:SetParent(column)
		tooltip:SetOwner(column, "ANCHOR_NONE")
		tooltip.owner = owner

		-- Mixin the tooltip button functions
		L.Mixin(tooltip.Button, L.TooltipMixin)
		tooltip.Button:SetReferences(item, inspector)

		self:SetItemTooltip(tooltip, item, inspector)

		-- Readjust tooltip size to fit the icon
		local width, height = tooltip:GetSize()
		tooltip:SetSize(width + 30, height + 4)

		-- Anchor the tooltip to the column
		tooltip:SetPoint('TOP', column.lastItem or column, column.lastItem and 'BOTTOM' or 'TOP', 0, 0)
		column.lastItem = tooltip
	end

	-- Text display:
	local elements = self.TalkBox.Elements
	local progress = elements.Progress
	local rewardsFrame = elements.Content.RewardsFrame
	-- Choice text:
	if rewardsFrame.ItemChooseText:IsVisible() then
		choices.Text:Show()
		choices.Text:SetText(rewardsFrame.ItemChooseText:GetText())
	else
		choices.Text:Hide()
	end
	-- Extra text:
	if progress.ReqText:IsVisible() then
		extras.Text:Show()
		extras.Text:SetText(progress.ReqText:GetText())
	elseif rewardsFrame.ItemReceiveText:IsVisible() and hasExtra then
		extras.Text:Show()
		extras.Text:SetText(rewardsFrame.ItemReceiveText:GetText())
	else
		extras.Text:Hide()
	end
	inspector:AdjustToChildren()
end

function NPC:UpdateItems()
	local items, numItems = self:GetItems()
	self.hasItems = numItems > 0
end

function NPC:GetItems()
	local items = self.Inspector.Items
	wipe(items)
	for _, item in pairs(self.TalkBox.Elements.Content.RewardsFrame.Buttons) do
		if item:IsVisible() then
			items[#items + 1] = item
		end
	end
	for _, item in pairs(self.TalkBox.Elements.Progress.Buttons) do
		if item:IsVisible() then
			items[#items + 1] = item
		end
	end
	return items, #items
end

----------------------------------
-- Animation players
----------------------------------
function NPC:PlayIntro(event, ignoreFrameFade)
	local isShown = self:IsVisible()
	self:Show()
	if IsOptionFrameOpen() then
		self:ForceClose()
	else
		self:EnableKeyboard(true)
		self:FadeIn(nil, isShown, ignoreFrameFade)
		local box = self.TalkBox
		local point = L('boxpoint')
		local x, y = L('boxoffsetX'), L('boxoffsetY')
		box:ClearAllPoints()
		if not isShown and not L('disableflyin') then
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
		elseif (self.lastEvent == 'GOSSIP_ONTHEFLY') then
			self:FadeOut(0.5, true)
		else
			self.TalkBox:OnLeftClick()
		end
	end,
	reset = function(self)
		self.TalkBox.TextFrame.Text:RepeatTexts()
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
	elseif button:match(L('inspect')) and self.hasItems then
		self:SetPropagateKeyboardInput(false)
		self:ShowItems()
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

function NPC:OnKeyUp(button)
	if button:match(L('inspect')) and self.Inspector:IsVisible() then
		self.Inspector:Hide()
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
	if 	L('immersivemode') or ( ( ( self.lastEvent == 'QUEST_COMPLETE' ) and
		not (self.Elements.itemChoice == 0 and GetNumQuestChoices() > 1) ) or
		( self.lastEvent == 'QUEST_ACCEPTED' ) or
		( self.lastEvent == 'QUEST_DETAIL' ) or
		( self.lastEvent ~= 'GOSSIP_SHOW' and IsQuestCompletable() ) ) then
		L.UIFrameFadeIn(self.Hilite, 0.15, self.Hilite:GetAlpha(), 1)
	end
end

function TalkBox:OnLeave()
	L.UIFrameFadeOut(self.Hilite, 0.15, self.Hilite:GetAlpha(), 0)
end

function TalkBox:OnLeftClick()
	-- Complete quest
	if self.lastEvent == 'QUEST_COMPLETE' then
		self.Elements:CompleteQuest()
	-- Accept quest
	elseif self.lastEvent == 'QUEST_DETAIL' or self.lastEvent == 'QUEST_ACCEPTED' then
		self.Elements:AcceptQuest()
	elseif self.lastEvent == 'GOSSIP_ONTHEFLY' then
		ImmersionFrame:FadeOut(0.5, true)
	-- Progress quest to completion
	elseif IsQuestCompletable() then
		CompleteQuest()
	end
end

function TalkBox:OnClick(button)
	if L('flipshortcuts') then
		button = button == 'LeftButton' and 'RightButton' or 'LeftButton'
	end
	if button == 'LeftButton' then
		if L('immersivemode') then
			inputs.accept(ImmersionFrame)
		else
			self:OnLeftClick()
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

function TalkBox:Dim()
	L.UIFrameFadeOut(self, 0.15, self:GetAlpha(), 0.05)
end

function TalkBox:Undim()
	L.UIFrameFadeIn(self, 0.15, self:GetAlpha(), 1)
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