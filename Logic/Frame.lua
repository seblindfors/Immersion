local _, L = ...
local Frame, TalkBox, API, GetTime = {}, {}, ImmersionAPI, GetTime

----------------------------------
-- Event handler
----------------------------------
function Frame:OnEvent(event, ...)
	self:ResetElements(event)
	self:HandleGossipQuestOverlap(event)
	if self[event] then
		event = self[event](self, ...) or event
	end
	self.TalkBox.lastEvent = event
	self.lastEvent = event
	self.timeStamp = GetTime()
	self:UpdateItems()
	self:UpdateBackground()
	return event
end

function Frame:OnHide()
	self:ClearImmersionFocus()
	self.TalkBox.BackgroundFrame.OverlayKit:Hide()
end

----------------------------------
-- Content handler (gossip & quest)
----------------------------------
function Frame:AddQuestInfo(template)
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

function Frame:IsGossipAvailable(ignoreAutoSelect)
	-- if there is only a non-gossip option, then go to it directly
	if 	(API:GetNumGossipAvailableQuests() == 0) and 
		(API:GetNumGossipActiveQuests() == 0) and 
		(API:GetNumGossipOptions() == 1) and
		not API:ForceGossip() then
		----------------------------
		if API:CanAutoSelectGossip(ignoreAutoSelect) then
			return false
		end
	end
	return true
end

function Frame:IsQuestAutoAccepted(questStartItemID)
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
		API:CloseQuest()
		return true
	end

	-- triggered from entering an area, but also from forced campaign quests.
	-- let's not intrude on the user; just add a tracker popup.
	if isFromAreaTrigger then
		-- add a new quest tracker popup and close the quest dialog
		if AddAutoQuestPopUp(questID, 'OFFER') then
			PlayAutoAcceptQuestSound()
		end
		API:CloseQuest()
		return true
	end
end

-- Iterate through gossip options and simulate a click on the best option.
function Frame:SelectBestOption()
	local button = self.TitleButtons:GetBestOption()
	if button then
		button.Hilite:SetAlpha(1)
		button:Click()
		button:OnLeave()
		PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
	end
end

function Frame:GetRemainingSpeechTime()
	return self.TalkBox.TextFrame.Text:GetTimeRemaining()
end

function Frame:IsSpeechFinished()
	return self.TalkBox.TextFrame.Text:IsFinished()
end

-- hack to figure out if event is related to quests
function Frame:IsObstructingQuestEvent(forceEvent)
	local event = forceEvent or self.lastEvent or ''
	return ( event:match('^QUEST') and event ~= 'QUEST_ACCEPTED' )
end

function Frame:HandleGossipQuestOverlap(event)
	-- Since Blizzard handles this transition by mutually exclusive gossip/quest frames,
	-- and their visibility to determine whether to close gossip or quest interaction,
	-- events need to be checked so that an NPC interaction is correctly transitioned.
	if (type(event) == 'string') then
		if ( event == 'GOSSIP_SHOW' ) then
		--	API:CloseQuest()
		elseif self:IsObstructingQuestEvent(event) then
			API:CloseGossip(true)
		end
	end
end

function Frame:HandleGossipOpenEvent(kit)
	if not self.gossipHandlers[kit] then
		self:SetBackground(kit)
		self:UpdateTalkingHead(API:GetUnitName('npc'), API:GetGossipText(), 'GossipGossip')
		if self:IsGossipAvailable() then
			self:PlayIntro('GOSSIP_SHOW')
		end
	end
end

function Frame:SetBackground(kit)
	local backgroundFrame = self.TalkBox.BackgroundFrame;
	local overlay = backgroundFrame.OverlayKit;

	if kit and not L('disablebgtextures') then
		local backgroundAtlas = GetFinalNameFromTextureKit('QuestBG-%s', kit)
		local atlasInfo = C_Texture.GetAtlasInfo(backgroundAtlas)
		if atlasInfo then
			local minColor = CreateColor(1, 1, 1, 0)
			local maxColor = CreateColor(1, 1, 1, 0.5)

			overlay:Show()
			L.SetGradient(overlay, 'HORIZONTAL', minColor, maxColor)

			overlay:SetSize(atlasInfo.width, atlasInfo.height)
			overlay:SetTexture(atlasInfo.file)
			overlay:SetTexCoord(
				atlasInfo.leftTexCoord, atlasInfo.rightTexCoord,-- + 0.035,
				atlasInfo.topTexCoord, atlasInfo.bottomTexCoord)-- + 0.035)
			return
		end
	end
end

function Frame:UpdateBackground()
	local theme = API:GetQuestDetailsTheme(GetQuestID())
	local kit = theme and theme.background and theme.background:gsub('QuestBG%-', '')
	if kit then
		self:SetBackground(kit)
	end
end

function Frame:ResetElements(event)
	if ( self.IgnoreResetEvent[event] ) then return end
	
	self.Inspector:Hide()
	self.TalkBox.Elements:Reset()
	self:SetBackground(nil)
end

function Frame:UpdateTalkingHead(title, text, npcType, explicitUnit, isToastPlayback)
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
	talkBox.ReputationBar:Update()
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
function Frame:SetItemTooltip(tooltip, item)
	local objType = item.objectType
	if objType == 'item' then
		tooltip:SetQuestItem(item.type, item:GetID())
	elseif objType == 'currency' then
		tooltip:SetQuestCurrency(item.type, item:GetID())
	end
	if item.rewardContextLine then
		GameTooltip_AddBlankLineToTooltip(tooltip)
		GameTooltip_AddColoredLine(tooltip, item.rewardContextLine, QUEST_REWARD_CONTEXT_FONT_COLOR)
	end
	tooltip.Icon.Texture:SetTexture(item.itemTexture or item.Icon:GetTexture())
	tooltip:Show()
end

function Frame:GetItemColumn(owner, id)
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

function Frame:ShowItems()
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

function Frame:UpdateItems()
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
function Frame:PlayIntro(event, freeFloating)
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
function Frame:PlayOutro(optionFrameOpen)
	self:EnableKeyboard(false)
	self:FadeOut(0.5)
	self:PlayToasts(optionFrameOpen)
end

function Frame:ForceClose(optionFrameOpen)
	API:CloseGossip()
	API:CloseQuest()
	API:CloseItemText()
	self:PlayOutro(optionFrameOpen)
end

----------------------------------
-- Key input handler
----------------------------------
local inputs, modifierStates = L.Inputs, L.ModifierStates;

function Frame:IsInspectModifier(button)
	return button and button:match(L('inspect')) and true
end

function Frame:IsModifierDown(modifier)
	return modifierStates[modifier or L('inspect')]()
end

function Frame:OnKeyDown(button)
	if (button == 'ESCAPE' or GetBindingAction(button) == 'TOGGLEGAMEMENU') then
		self:ForceClose()
		return
	elseif self:ParseControllerCommand(button) then
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false)
		end
		return
	elseif self:IsInspectModifier(button) and self.hasItems then
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false)
		end
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
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false)
		end
	elseif L.cfg.enablenumbers and tonumber(button) then
		inputs.number(self, tonumber(button))
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(false)
		end
	else
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(true)
		end
	end
end

function Frame:OnKeyUp(button)
	local inspector = self.Inspector
	if ( inspector.ShowFocusedTooltip and ( self:IsInspectModifier(button) or button:match('SHIFT') ) ) then
		inspector:ShowFocusedTooltip(false)
	elseif ( self:IsInspectModifier(button) and inspector:IsVisible() ) then
		inspector:Hide()
	end
end

Frame.OnGamePadButtonDown = Frame.OnKeyDown;
Frame.OnGamePadButtonUp   = Frame.OnKeyUp;

----------------------------------
-- Mixin with scripts
----------------------------------
L.Mixin(L.frame, Frame)