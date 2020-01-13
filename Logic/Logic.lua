local _, L = ...
local NPC, TalkBox, API = {}, {}, ImmersionAPI
local frame, GetTime, GetOffset = L.frame, GetTime, UIParent.GetBottom

----------------------------------
-- Event handler
----------------------------------
function NPC:OnEvent(event, ...)
	self:ResetElements(event)
	self:HandleGossipQuestOverlap(event)
	if self[event] then
		event = self[event](self, ...) or event
	end
	self.TalkBox.lastEvent = event
	self.lastEvent = event
	self.timeStamp = GetTime()
	self:UpdateItems()
	return event
end

function NPC:OnHide()
	self:ClearImmersionFocus()
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
	self.TalkBox:SetExtraOffset((height + 32) * L('elementscale'))
	self.TalkBox.NameFrame.FadeIn:Play()
end

function NPC:IsGossipAvailable(ignoreAutoSelect)
	-- if there is only a non-gossip option, then go to it directly
	if 	(GetNumGossipAvailableQuests() == 0) and 
		(GetNumGossipActiveQuests() == 0) and 
		(GetNumGossipOptions() == 1) and
		not ForceGossip() then
		----------------------------
		local text, gossipType = GetGossipOptions()
		if ( gossipType ~= 'gossip' ) then
			if not ignoreAutoSelect then
				SelectGossipOption(1)
			end
			return false
		end
	end
	return true
end

function NPC:IsQuestAutoAccepted(questStartItemID)
	-- Auto-accepted quests need to be treated differently from other quests,
	-- and different from eachother depending on the source of the quest. 
	-- Handling here is prone to cause bugs/weird behaviour, update with caution.

	local questID = GetQuestID()
	local isFromAdventureMap = API:QuestIsFromAdventureMap()
	local isFromAreaTrigger = API:QuestGetAutoAccept() and API:QuestIsFromAreaTrigger()
	local isFromItem = (questStartItemID ~= nil and questStartItemID ~= 0)

	-- the quest came from an adventure map, so user has already seen and accepted it.
	if isFromAdventureMap then
		return true
	end

	-- an item pickup by loot caused this quest to show up, don't intrude on the user.
	if isFromItem then
		-- add a new quest tracker popup and close the quest dialog
		if AddAutoQuestPopUp(questID, 'OFFER') then
			PlayAutoAcceptQuestSound()
		end
		CloseQuest()
		return true
	end

	-- triggered from entering an area, but also from forced campaign quests.
	-- let's not intrude on the user; just add a tracker popup.
	if isFromAreaTrigger then
		-- add a new quest tracker popup and close the quest dialog
		if AddAutoQuestPopUp(questID, 'OFFER') then
			PlayAutoAcceptQuestSound()
		end
		CloseQuest()
		return true
	end
end

-- Iterate through gossip options and simulate a click on the best option.
function NPC:SelectBestOption()
	local button = self.TitleButtons:GetBestOption()
	if button then
		button.Hilite:SetAlpha(1)
		button:Click()
		button:OnLeave()
		PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
	end
end

function NPC:GetRemainingSpeechTime()
	return self.TalkBox.TextFrame.Text:GetTimeRemaining()
end

function NPC:IsSpeechFinished()
	return self.TalkBox.TextFrame.Text:IsFinished()
end

function NPC:IsObstructingQuestEvent(forceEvent)
	local event = forceEvent or self.lastEvent or ''
	return ( event:match('^QUEST') and event ~= 'QUEST_ACCEPTED' )
end

function NPC:HandleGossipQuestOverlap(event)
	-- Since Blizzard handles this transition by mutually exclusive gossip/quest frames,
	-- and their visibility to determine whether to close gossip or quest interaction,
	-- events need to be checked so that an NPC interaction is correctly transitioned.
	if (type(event) == 'string') then
		if ( event == 'GOSSIP_SHOW' ) then
		--	CloseQuest()
		elseif self:IsObstructingQuestEvent(event) then
			CloseGossip()
		end
	end
end

function NPC:ResetElements(event)
	if ( self.IgnoreResetEvent[event] ) then return end
	
	self.Inspector:Hide()
	self.TalkBox.Elements:Reset()
end

function NPC:UpdateTalkingHead(title, text, npcType, explicitUnit, isToastPlayback)
	local unit = explicitUnit
	if not unit then
		if ( UnitExists('questnpc') and not UnitIsUnit('questnpc', 'player') and not UnitIsDead('questnpc') ) then
			unit = 'questnpc'
		elseif ( UnitExists('npc') and not UnitIsUnit('npc', 'player') and not UnitIsDead('npc') ) then
			unit = 'npc'
		else
			unit = npcType
		end
	end
	local talkBox = self.TalkBox
	talkBox:SetExtraOffset(0)
	talkBox.ReputationBar:Show()
	talkBox.MainFrame.Indicator:SetTexture('Interface\\GossipFrame\\' .. npcType .. 'Icon')
	talkBox.MainFrame.Model:SetUnit(unit)
	talkBox.NameFrame.Name:SetText(title)
	local textFrame = talkBox.TextFrame
	textFrame.Text:SetText(text)
	-- Add contents to toast.
	if not isToastPlayback then
		if L('onthefly') then
			self:QueueToast(title, text, npcType, unit)
		elseif L('supertracked') then
			self:QueueQuestToast(title, text, npcType, unit)
		end
	end
	if L('showprogressbar') and not L('disableprogression') then
		talkBox.ProgressionBar:Show()
	end
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
			column:SetScript('OnHide', function(self) self.lastItem = nil end)
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
	local active, extras, choices = inspector.Active, inspector.Extras, inspector.Choices
	inspector:Show()
	for id, item in ipairs(items) do
		local tooltip = inspector.tooltipFramePool:Acquire()
		local owner = item.type == 'choice' and choices or extras
		local columnID = ( id % 3 == 0 ) and 3 or ( id % 3 )
		local column = self:GetItemColumn(owner, columnID)

		hasChoice = hasChoice or item.type == 'choice'
		hasExtra = hasExtra or item.type ~= 'choice'

		-- Set up tooltip
		tooltip:SetParent(column)
		tooltip:SetOwner(column, "ANCHOR_NONE")
		tooltip.owner = owner

		active[id] = tooltip.Button
		tooltip.Button:SetID(id)

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
	------------------------------
	inspector.Threshold = #active
	inspector:AdjustToChildren()
	if inspector.SetFocus then
		inspector:SetFocus(1)
	end
end

function NPC:UpdateItems()
	local items = self.Inspector.Items
	wipe(items)
	-- count item rewards
	for _, item in ipairs(self.TalkBox.Elements.Content.RewardsFrame.Buttons) do
		if item:IsVisible() then
			items[#items + 1] = item
		end
	end
	-- count necessary quest progress items
	for _, item in ipairs(self.TalkBox.Elements.Progress.Buttons) do
		if item:IsVisible() then
			items[#items + 1] = item
		end
	end
	self.hasItems = #items > 0

	if self.hasItems then
		self:AddHint('CIRCLE', INSPECT)
	else
		self:RemoveHint('CIRCLE')
	end

	return items, #items
end

----------------------------------
-- Animation players
----------------------------------
function NPC:PlayIntro(event, freeFloating)
	local isShown = self:IsVisible()
	local shouldAnimate = not isShown and not L('disableglowani')
	self.playbackEvent = event

	if freeFloating then
		self:ClearImmersionFocus()
	else
		self:SetImmersionFocus()
		self:AddHint('TRIANGLE', GOODBYE)
	end

	self:Show()

	if IsOptionFrameOpen() then
		self:ForceClose(true)
	else
		self:EnableKeyboard(not freeFloating)
		self:FadeIn(nil, shouldAnimate, freeFloating)

		local box = self.TalkBox
		local x, y = L('boxoffsetX'), L('boxoffsetY')
		box:ClearAllPoints()
		box:SetOffset(box.offsetX or x, box.offsetY or y)

		if not shouldAnimate and not L('disableglowani') then
			self.TalkBox.MainFrame.SheenOnly:Play()
		end

	end
end

-- This will also hide the frames after the animation is done.
function NPC:PlayOutro(optionFrameOpen)
	self:EnableKeyboard(false)
	self:FadeOut(0.5)
	self:PlayToasts(optionFrameOpen)
end

function NPC:ForceClose(optionFrameOpen)
	CloseGossip()
	CloseQuest()
	CloseItemText()
	self:PlayOutro(optionFrameOpen)
end

----------------------------------
-- Key input handler
----------------------------------
local inputs = {
	accept = function(self)
		local text = self.TalkBox.TextFrame.Text
		local numActive = self.TitleButtons:GetNumActive()
		if ( not self:IsModifierDown() and text:GetNumRemaining() > 1 and text:IsSequence() ) then
			text:ForceNext()
		elseif ( self.lastEvent == 'GOSSIP_SHOW' and numActive < 1 ) then
			CloseGossip()
		elseif ( self.lastEvent == 'GOSSIP_SHOW' and numActive == 1 ) then
			SelectGossipOption(1)
		elseif ( numActive > 1 ) then
			self:SelectBestOption()
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
		if self.hasItems then
			local choiceIterator = 0
			for _, item in ipairs(self.TalkBox.Elements.Content.RewardsFrame.Buttons) do
				if item:IsVisible() and item.type == 'choice' then
					choiceIterator = choiceIterator + 1
					if choiceIterator == id then
						item:Click()
						return
					end
				end
			end
		else
			local button = self.TitleButtons.Buttons[id]
			if button then
				button.Hilite:SetAlpha(1)
				button:Click()
				button:OnLeave()
				PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
			end
		end
	end,
}

local modifierStates = {
	SHIFT 	= IsShiftKeyDown;
	CTRL 	= IsControlKeyDown;
	ALT 	= IsAltKeyDown;
	NOMOD 	= function() return false end;
}

function NPC:IsInspectModifier(button)
	return button and button:match(L('inspect')) and true
end

function NPC:IsModifierDown(modifier)
	return modifierStates[modifier or L('inspect')]()
end

function NPC:OnKeyDown(button)
	if button == 'ESCAPE' then
		self:ForceClose()
		return
	elseif self:ParseControllerCommand(button) then
		self:SetPropagateKeyboardInput(false)
		return
	elseif self:IsInspectModifier(button) and self.hasItems then
		self:SetPropagateKeyboardInput(false)
		self:ShowItems()
		return
	end
	local input
	for action, func in pairs(inputs) do
		-- run through input handlers and check if button matches a configured key.
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
	local inspector = self.Inspector
	if ( inspector.ShowFocusedTooltip and ( self:IsInspectModifier(button) or button:match('SHIFT') ) ) then
		inspector:ShowFocusedTooltip(false)
	elseif ( self:IsInspectModifier(button) and inspector:IsVisible() ) then
		inspector:Hide()
	end
end

----------------------------------
-- TalkBox "button"
----------------------------------
function TalkBox:SetOffset(x, y)
--[[if self:UpdateNameplateAnchor() then
		return
	end]]

	local point = L('boxpoint')
	local anidivisor = L('anidivisor')
	x = x or L('boxoffsetX')
	y = y or L('boxoffsetY')

	self.offsetX = x
	self.offsetY = y

	local isBottom = ( point:match('Bottom') )

	y = y + ( isBottom and self.extraY or 0 )

	local comp = y

	if ( not isBottom ) or ( anidivisor <= 1 ) or ( not self:IsVisible() ) then
		self:SetPoint(point, UIParent, x, y)
		return
	end
	self:SetScript('OnUpdate', function(self)
		self.isOffsetting = true
		local offset = (GetOffset(self) or 0) - (GetOffset(UIParent) or 0)
		local diff = ( comp - offset )
		if (offset == 0) or abs( comp - offset ) < 0.3 then
			self:SetPoint(point, UIParent, x, y)
			self.isOffsetting = false
			self:SetScript('OnUpdate', nil)
		else
			self:SetPoint(point, UIParent, x, offset + ( diff / anidivisor ))
		end
	end)
end

-- Temporarily increase the frame offset, in case we want to show extra stuff,
-- like quest descriptions, quest rewards, items needed for quest progress, etc.
function TalkBox:SetExtraOffset(newOffset)
	local currX = ( self.offsetX or L('boxoffsetX') )
	local currY = ( self.offsetY or L('boxoffsetY') )
	local allowExtra = L('anidivisor') > 0
	self.extraY = allowExtra and newOffset or 0
	self:SetOffset(currX, currY)
end

function TalkBox:UpdateNameplateAnchor()
	if self.plateInHiding then
		self.plateInHiding:SetAlpha(1)
		self.plateInHiding = nil
	end
	if L('nameplatemode') then
		local plate = API:GetNamePlateForUnit('npc')
		if plate then
			if self.isOffsetting then
				self:SetScript('OnUpdate', nil)
				self.isOffsetting = false
			end
			self:ClearAllPoints()
			self:SetPoint('CENTER', plate, 'TOP', 0, self.extraY or 0)
			if plate.UnitFrame then
				self.plateInHiding = plate.UnitFrame
				self.plateInHiding:SetAlpha(0)
			end
			return true
		end
	end
end

function TalkBox:OnEnter()
	-- Highlight the button when it can be clicked
	if not L('disableboxhighlight') then
		local lastEvent = self.lastEvent
		if 	L('immersivemode') or ( ( ( lastEvent == 'QUEST_COMPLETE' ) and
			not (self.Elements.itemChoice == 0 and GetNumQuestChoices() > 1) ) or
			( lastEvent == 'QUEST_ACCEPTED' ) or
			( lastEvent == 'QUEST_DETAIL' ) or
			( lastEvent == 'ITEM_TEXT_READY' ) or
			( lastEvent ~= 'GOSSIP_SHOW' and IsQuestCompletable() ) ) then
			L.UIFrameFadeIn(self.Hilite, 0.15, self.Hilite:GetAlpha(), 1)
		end
	end
end

function TalkBox:OnLeave()
	L.UIFrameFadeOut(self.Hilite, 0.15, self.Hilite:GetAlpha(), 0)
end

function TalkBox:OnDragStart()
	if ( L('boxlock') or self.isOffsetting ) then return end
	self:StartMoving()
end

function TalkBox:OnDragStop()
	if ( L('boxlock') or self.isOffsetting ) then return end
	self:StopMovingOrSizing()
	local point, _, _, x, y = self:GetPoint()

	point = point:sub(1,1) .. point:sub(2):lower()

	if ( point == 'Center' ) then
		point = 'Bottom'

		local cX = self:GetCenter()

		x = ( cX * self:GetScale() ) - ( GetScreenWidth() / 2 ) 
		y = self:GetBottom()

	end
	local isBottom = point == 'Bottom'

	if isBottom then
		y = y - (self.extraY or 0)
	end

	self:ClearAllPoints()
	self.offsetX = x
	self.offsetY = y

	L.Set('boxpoint', point)
	L.Set('boxoffsetX', x)
	L.Set('boxoffsetY', y)
	self:SetPoint(point, UIParent, point, x, isBottom and y + (self.extraY or 0) or y)
end

function TalkBox:OnLeftClick()
	-- Complete quest
	if self.lastEvent == 'QUEST_COMPLETE' then
		self.Elements:CompleteQuest()
	-- Accept quest
	elseif self.lastEvent == 'QUEST_DETAIL' or self.lastEvent == 'QUEST_ACCEPTED' then
		self.Elements:AcceptQuest()
	elseif self.lastEvent == 'ITEM_TEXT_READY' then
		local text = self.TextFrame.Text
		if text:GetNumRemaining() > 1 and text:IsSequence() then
			text:ForceNext()
		else
			CloseItemText()
		end
	-- Progress quest to completion
	elseif self.lastEvent == 'QUEST_PROGRESS' then
		if IsQuestCompletable() then
			CompleteQuest()
		else
			ImmersionFrame:ForceClose()
		end
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
			if ( ImmersionFrame.playbackEvent == 'IMMERSION_TOAST' ) then
				ImmersionFrame:RemoveToastByText(text.storedText)
			else
				text:RepeatTexts()
			end
		end
	end
end

function TalkBox:Dim()
	L.UIFrameFadeOut(self, 0.15, self:GetAlpha(), 0.05)
end

function TalkBox:Undim()
	L.UIFrameFadeIn(self, 0.15, self:GetAlpha(), 1)
end

----------------------------------
-- Mixin with scripts
----------------------------------
L.Mixin(frame, NPC)
L.Mixin(frame.TalkBox, TalkBox)