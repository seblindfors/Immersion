local API, TEMPLATE, Elements, _, L = ImmersionAPI, {}, {}, ...
L.ElementsMixin = Elements

local TEXT_COLOR, TITLE_COLOR = GetMaterialTextColors('Stone') -- default text colors
local REWARDS_OFFSET = 10 -- vertical distance between sections
local ITEMS_PER_ROW = 2 -- modulus value for item rows
local ACTIVE_TEMPLATE

local SEAL_QUESTS = { -- Seal quests
	[40519] = {text = '|cff04aaff'..QUEST_KING_VARIAN_WRYNN..'|r', sealAtlas = 'Quest-Alliance-WaxSeal'},
	[43926] = {text = '|cff480404'..QUEST_WARCHIEF_VOLJIN..'|r', sealAtlas = 'Quest-Horde-WaxSeal'},
	[46730] = {text = '|cff2f0a48'..QUEST_KHADGAR..'|r', sealAtlas = 'Quest-Legionfall-WaxSeal'},
}

local LOOT_ITEM_TYPES = {
	[0] = 'item'; -- LOOT_LIST_ITEM
	[1] = 'currency'; -- LOOT_LIST_CURRENCY
}

----------------------------------
-- Helper functions
----------------------------------
local Enum_QuestCompleteSpellType = {
	LegacyBehavior = 0,
	Follower = 1,
	Tradeskill = 2,
	Ability = 3,
	Aura = 4,
	Spell = 5,
	Unlock = 6,
	Companion = 7,
	QuestlineUnlock = 8,
	QuestlineReward = 9,
	QuestlineUnlockPart = 10
}

local QUEST_INFO_SPELL_REWARD_ORDERING = {
	Enum_QuestCompleteSpellType.Follower,
	Enum_QuestCompleteSpellType.Companion,
	Enum_QuestCompleteSpellType.Tradeskill,
	Enum_QuestCompleteSpellType.Ability,
	Enum_QuestCompleteSpellType.Aura,
	Enum_QuestCompleteSpellType.Spell,
	Enum_QuestCompleteSpellType.Unlock,
	Enum_QuestCompleteSpellType.QuestlineUnlock,
	Enum_QuestCompleteSpellType.QuestlineReward,
	Enum_QuestCompleteSpellType.QuestlineUnlockPart,
}

local QUEST_INFO_SPELL_REWARD_TO_HEADER = {
	[Enum_QuestCompleteSpellType.Follower] = REWARD_FOLLOWER,
	[Enum_QuestCompleteSpellType.Companion] = REWARD_COMPANION,
	[Enum_QuestCompleteSpellType.Tradeskill] = REWARD_TRADESKILL_SPELL,
	[Enum_QuestCompleteSpellType.Ability] = REWARD_ABILITY,
	[Enum_QuestCompleteSpellType.Aura] = REWARD_AURA,
	[Enum_QuestCompleteSpellType.Spell] = REWARD_SPELL,
	[Enum_QuestCompleteSpellType.Unlock] = REWARD_UNLOCK,
	[Enum_QuestCompleteSpellType.QuestlineUnlock] = REWARD_QUESTLINE_UNLOCK,
	[Enum_QuestCompleteSpellType.QuestlineReward] = REWARD_QUESTLINE_REWARD,
	[Enum_QuestCompleteSpellType.QuestlineUnlockPart] = REWARD_QUESTLINE_UNLOCK_PART,
}

local function GetRewardSpellBucketType(spellInfo)
	if spellInfo.type and spellInfo.type ~= Enum_QuestCompleteSpellType.LegacyBehavior then
		return spellInfo.type
	elseif spellInfo.isTradeskillSpell then
		return Enum_QuestCompleteSpellType.Tradeskill
	elseif spellInfo.isBoostSpell then
		return Enum_QuestCompleteSpellType.Ability
	elseif spellInfo.garrFollowerID then
		local followerInfo = C_Garrison.GetFollowerInfo(spellInfo.garrFollowerID)
		if followerInfo and followerInfo.followerTypeID == Enum.GarrisonFollowerType.FollowerType_9_0_GarrisonFollower then
			return Enum_QuestCompleteSpellType.Companion
		else
			return Enum_QuestCompleteSpellType.Follower
		end
	elseif spellInfo.isSpellLearned then
		return Enum_QuestCompleteSpellType.Spell
	elseif spellInfo.genericUnlock then
		return Enum_QuestCompleteSpellType.Unlock
	end

	return Enum_QuestCompleteSpellType.Aura
end

local function AddSpellToBucket(buckets, spellInfo)
	local subType = GetRewardSpellBucketType(spellInfo)

	if not buckets[subType] then
		buckets[subType] = {}
	end

	table.insert(buckets[subType], spellInfo)
end

local function IsValidSpellReward(texture, knownSpell, isBoostSpell, garrFollowerID)
	-- check if already known, check if is boost spell, check if follower is collected
	return  texture and not knownSpell and
			(not isBoostSpell or API:IsCharacterNewlyBoosted()) and
			(not garrFollowerID or not API:IsFollowerCollected(garrFollowerID))
end

local Enum_QuestRewardContextFlags = {
	None = 0,
	FirstCompletionBonus = 1,
	RepeatCompletionBonus = 2
}

local function GetBestItemRewardContextDescription(questRewardContextFlags)
	if (FlagsUtil.IsSet(questRewardContextFlags, Enum_QuestRewardContextFlags.FirstCompletionBonus)) then
		return ACCOUNT_FIRST_TIME_QUEST_BONUS_TOOLTIP
	elseif (FlagsUtil.IsSet(questRewardContextFlags, Enum_QuestRewardContextFlags.RepeatCompletionBonus)) then
		return ACCOUNT_PREVIOUSLY_COMPLETED_QUEST_BONUS_TOOLTIP
	end
end

local function GetBestCurrencyRewardContextDescription(currencyInfo, questRewardContextFlags)
	local entireAmountIsBonus = currencyInfo.bonusRewardAmount == currencyInfo.totalRewardAmount
	local isReputationReward = C_CurrencyInfo.GetFactionGrantedByCurrency(currencyInfo.currencyID) ~= nil
	if (FlagsUtil.IsSet(questRewardContextFlags, Enum_QuestRewardContextFlags.FirstCompletionBonus)) then
		if entireAmountIsBonus then
			return ACCOUNT_FIRST_TIME_QUEST_BONUS_TOOLTIP
		end

		local bonusString = isReputationReward and ACCOUNT_FIRST_TIME_QUEST_BONUS_REP_TOOLTIP or ACCOUNT_FIRST_TIME_QUEST_BONUS_CURRENCY_TOOLTIP
		return bonusString:format(currencyInfo.baseRewardAmount, currencyInfo.bonusRewardAmount)
	end

	if (FlagsUtil.IsSet(questRewardContextFlags, Enum_QuestRewardContextFlags.RepeatCompletionBonus)) then
		if entireAmountIsBonus then
			return ACCOUNT_PREVIOUSLY_COMPLETED_QUEST_BONUS_TOOLTIP
		end

		local bonusString = isReputationReward and ACCOUNT_PREVIOUSLY_COMPLETED_QUEST_REP_BONUS_TOOLTIP or ACCOUNT_PREVIOUSLY_COMPLETED_QUEST_CURRENCY_BONUS_TOOLTIP
		return bonusString:format(currencyInfo.baseRewardAmount, currencyInfo.bonusRewardAmount)
	end
end

local function GetBestQuestRewardContextDescription(self)
	if not self.questRewardContextFlags then
		return nil
	end

	if self.objectType == "item" then
		return GetBestItemRewardContextDescription(self.questRewardContextFlags)
	elseif self.objectType == "currency" and self.currencyInfo then
		return GetBestCurrencyRewardContextDescription(self.currencyInfo, self.questRewardContextFlags)
	end
end

local QUEST_REWARD_CONTEXT_ICONS = {
	[Enum_QuestRewardContextFlags.FirstCompletionBonus] = "warbands-icon",
	[Enum_QuestRewardContextFlags.RepeatCompletionBonus] = "warbands-icon",
}

local function GetBestQuestRewardContextIcon(self)
	if not self.questRewardContextFlags then
		return nil
	end

	if (FlagsUtil.IsSet(self.questRewardContextFlags, Enum_QuestRewardContextFlags.FirstCompletionBonus)) then
		return QUEST_REWARD_CONTEXT_ICONS[Enum_QuestRewardContextFlags.FirstCompletionBonus]
	elseif (FlagsUtil.IsSet(self.questRewardContextFlags, Enum_QuestRewardContextFlags.RepeatCompletionBonus)) then
		return QUEST_REWARD_CONTEXT_ICONS[Enum_QuestRewardContextFlags.RepeatCompletionBonus]
	end

	return nil
end

local function UpdateQuestRewardContextFlags(self, questRewardContextFlags)
	self.questRewardContextFlags = questRewardContextFlags
	local contextIcon = GetBestQuestRewardContextIcon(self)
	self.QuestRewardContextIcon:SetAtlas(contextIcon)
	self.QuestRewardContextIcon:SetShown(contextIcon ~= nil)
	self.rewardContextLine = GetBestQuestRewardContextDescription(self)
end

local function GetItemButton(parentFrame, index, buttonType)
	local rewardButtons = parentFrame.Buttons
	if ( not rewardButtons[index] ) then
		local button = CreateFrame('BUTTON', _..(buttonType or 'QuestInfoItem')..index, parentFrame, parentFrame.buttonTemplate)
		rewardButtons[index] = button
		button.container = parentFrame:GetParent():GetParent()
		button.highlight = parentFrame.ItemHighlight
	end
	return rewardButtons[index]
end

local function UpdateItemInfo(self, showMissing)
	assert(self.type)
	assert(self:GetID())

	if self.objectType == 'item' then
		local name, texture, amount, quality, isUsable, itemID, questRewardContextFlags = GetQuestItemInfo(self.type, self:GetID())
		local displayText;
		if showMissing and not API.IsRetail then
			local missingAmount = amount > 1 and amount - (GetItemCount or C_Item.GetItemCount)(name)
			local hasMissingAmount = missingAmount and missingAmount > 0
			displayText = hasMissingAmount and ('%s\n|cff757575%s|r'):format(name, ITEM_MISSING:format(missingAmount))
		end
		displayText = displayText or name;
		-- For the tooltip
		self.Name:SetText(displayText)
		self.itemTexture = texture
		SetItemButtonCount(self, amount)
	--	SetItemButtonQuality(self, quality, GetQuestItemLink(self.type, self:GetID()))
		SetItemButtonTexture(self, texture)
		if ( isUsable ) then
			SetItemButtonTextureVertexColor(self, 1.0, 1.0, 1.0)
			SetItemButtonNameFrameVertexColor(self, 1.0, 1.0, 1.0)
		else
			SetItemButtonTextureVertexColor(self, 0.9, 0, 0)
			SetItemButtonNameFrameVertexColor(self, 0.9, 0, 0)
		end
		UpdateQuestRewardContextFlags(self, questRewardContextFlags)
		self:Show()
		return true
	elseif self.objectType == 'currency' then
		local currencyInfo = API:GetQuestCurrencyInfo(self.type, self:GetID())
		if currencyInfo then
			local name, texture, amount, quality = CurrencyContainerUtil.GetCurrencyContainerInfo(currencyInfo.currencyID, currencyInfo.displayedAmount, currencyInfo.name, currencyInfo.texture, currencyInfo.quality)
			-- For the tooltip
			self.Name:SetText(name)
			self.itemTexture = texture
			self.currencyInfo = currencyInfo
			SetItemButtonCount(self, amount, true)
			SetItemButtonTexture(self, texture)
			SetItemButtonTextureVertexColor(self, 1.0, 1.0, 1.0)
			SetItemButtonNameFrameVertexColor(self, 1.0, 1.0, 1.0)
			UpdateQuestRewardContextFlags(self, currencyInfo.questRewardContextFlags)
			self:Show()
			return true
		end
	end
end

local function ToggleRewardElement(frame, value, anchor)
	if ( value and tonumber(value) ~= 0 ) then
		frame:SetPoint('TOPLEFT', anchor, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
		frame.ValueText:SetText(value)
		frame:Show()
		return true
	else
		frame:Hide()
	end
end

function Elements:UpdateBoundaries()
	self:AdjustToChildren()
	return self:AdjustToChildren(8, 8)
end

function Elements:Reset()
	for _, frame in pairs(self.Active) do
		frame:Hide()
	end
	wipe(self.Active)
	self:Hide()
	self.Content:Hide()
	self.Progress:Hide()
end

----------------------------------
-- Quest elements display
----------------------------------
function Elements:Display(template, material)
	local template = TEMPLATE[template]
	if not template then
		return 0
	end

	ACTIVE_TEMPLATE = template

	self.chooseItems = template.chooseItems

	self:SetMaterial(material)
	self.Progress:Hide()

	local content = self.Content
	local elementsTable = template.elements
	local height, lastFrame = 0
	for i = 1, #elementsTable, 3 do
		local shownFrame, bottomShownFrame = elementsTable[i](self)
		if ( shownFrame ) then
			shownFrame:SetParent(content)
			height = height + shownFrame:GetHeight() + abs(elementsTable[i+2])
			if ( lastFrame ) then
				shownFrame:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', elementsTable[i+1], elementsTable[i+2])
			else
				shownFrame:SetPoint('TOPLEFT', content, 'TOPLEFT', elementsTable[i+1] , elementsTable[i+2] + 10)
			end
			shownFrame:Show()
			self.Active[#self.Active + 1] = shownFrame
			lastFrame = bottomShownFrame or shownFrame
		end
	end
	return height
end

function Elements:SetMaterial(material)
	local progress = self.Progress
	local content = self.Content
	local rewards = content.RewardsFrame
	-- nil check this
	if ( self.material ~= material ) then
		self.material = material
		local textColor, titleTextColor = GetMaterialTextColors(material)
		local r, g, b 
		if not textColor or not titleTextColor then
			textColor, titleTextColor = TEXT_COLOR, TITLE_COLOR
		end
		-- Headers
		r, g, b = unpack(titleTextColor)
		content.ObjectivesHeader:SetTextColor(r, g, b)
		progress.ReqText:SetTextColor(r, g, b)
		rewards.Header:SetTextColor(r, g, b)
		-- Other text
		r, g, b = unpack(textColor)
		content.ObjectivesText:SetTextColor(r, g, b)
		content.GroupSize:SetTextColor(r, g, b)
		content.RewardText:SetTextColor(r, g, b)
		content.QuestInfoAccountCompletedNotice:SetTextColor(r, g, b)
		-- Progress text
		progress.MoneyText:SetTextColor(r, g, b)
		-- Reward frame text
		rewards.ItemChooseText:SetTextColor(r, g, b)
		rewards.ItemReceiveText:SetTextColor(r, g, b)
		rewards.PlayerTitleText:SetTextColor(r, g, b)
		rewards.XPFrame.ReceiveText:SetTextColor(r, g, b)

		local spellHeaderPool = rewards.spellHeaderPool
		spellHeaderPool.textR, spellHeaderPool.textG, spellHeaderPool.textB = r, g, b
	end
end

function Elements:ShowSpecialObjectives()
	-- Show objective spell
	local spellID, spellName, spellTexture = GetCriteriaSpell()
	local specialFrame = self.Content.SpecialObjectivesFrame
	local spellObjectiveLabel = specialFrame.SpellObjectiveLearnLabel
	local spellObjective = specialFrame.SpellObjectiveFrame


	local lastFrame = nil
	local totalHeight = 0

	if (spellID) then
		spellObjective.Icon:SetTexture(spellTexture)
		spellObjective.Name:SetText(spellName)
		spellObjective.spellID = spellID

		spellObjective:ClearAllPoints()
		if (lastFrame) then
			spellObjectiveLabel:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -4)
			totalHeight = totalHeight + 4
		else
			spellObjectiveLabel:SetPoint('TOPLEFT', 0, 0)
		end

		spellObjective:SetPoint('TOPLEFT', spellObjectiveLabel, 'BOTTOMLEFT', 0, -4)

		spellObjectiveLabel:SetText(LEARN_SPELL_OBJECTIVE)
		spellObjectiveLabel:SetTextColor(0, 0, 0)

		spellObjectiveLabel:Show()
		spellObjective:Show()
		totalHeight = totalHeight + spellObjective:GetHeight() + spellObjectiveLabel:GetHeight()
		lastFrame = spellObjective
	else
		spellObjective:Hide()
		spellObjectiveLabel:Hide()
	end

	if (lastFrame) then
		specialFrame:SetHeight(totalHeight)
		specialFrame:Show()
		return specialFrame
	else
		return specialFrame:Hide()
	end
end

function Elements:ShowObjectivesHeader() return self.Content.ObjectivesHeader end

function Elements:ShowObjectivesText()
	local questObjectives = GetObjectiveText()
	local objectivesText = self.Content.ObjectivesText
	objectivesText:SetText(questObjectives)
	objectivesText:SetWidth(ACTIVE_TEMPLATE.contentWidth)
	return objectivesText
end

function Elements:ShowAccountCompleted()
	local startingAccountCompletedQuest  = API:GetAccountCompleted(GetQuestID())
	local completeNotice = self.Content.QuestInfoAccountCompletedNotice
	if startingAccountCompletedQuest then
		completeNotice:Show()
		return completeNotice
	end
	return completeNotice:Hide()
end

function Elements:ShowGroupSize()
	local groupNum = API:GetSuggestedGroupNum(GetQuestID())
	local groupSize = self.Content.GroupSize
	if ( groupNum > 0 ) then
		groupSize:SetText(QUEST_SUGGESTED_GROUP_NUM:format(groupNum))
		groupSize:Show()
		return groupSize
	else
		return groupSize:Hide()
	end
end

function Elements:ShowSeal()
	local frame = self.Content.SealFrame
	if ACTIVE_TEMPLATE and ACTIVE_TEMPLATE.canHaveSealMaterial then
		local sealInfo = SEAL_QUESTS[GetQuestID()]
		if sealInfo then
			frame.Text:SetText(sealInfo.text)
			frame.Texture:SetAtlas(sealInfo.sealAtlas, true) 
			frame.Texture:SetPoint('TOPLEFT', ACTIVE_TEMPLATE.sealXOffset, ACTIVE_TEMPLATE.sealYOffset)
			frame:Show()
			return frame
		end
	end
	return frame:Hide()
end

----------------------------------
-- Quest reward handling
----------------------------------
function Elements:ShowRewards()
	local elements = self
	local self = self.Content.RewardsFrame -- more convenient this way
	local rewardButtons = self.Buttons
	local 	numQuestRewards, numQuestChoices, numQuestCurrencies,
			questID, money,
			skillName, skillPoints, skillIcon,
			xp, artifactXP, artifactCategory, honor,
			playerTitle,
			spellRewards
			
	local numQuestSpellRewards = 0
	local totalHeight = 0
	local spellBuckets = {}

	do  -- Get data
		questID = GetQuestID()
		numQuestRewards = API:GetNumQuestRewards()
		numQuestChoices = API:GetNumQuestChoices()
		numQuestCurrencies = API:GetNumRewardCurrencies(questID)
		money = API:GetRewardMoney()
		skillName, skillIcon, skillPoints = API:GetRewardSkillPoints()
		xp = API:GetRewardXP()
		artifactXP, artifactCategory = API:GetRewardArtifactXP()
		honor = API:GetRewardHonor()
		playerTitle = API:GetRewardTitle()
		spellRewards = API:GetQuestRewardSpells(questID)
	end

	do -- Spell rewards
		for _, spellID in ipairs(spellRewards) do
			if spellID > 0 then
				local spellInfo = API:GetQuestRewardSpellInfo(questID, spellID)
				local knownSpell = IsSpellKnownOrOverridesKnown(spellID)

				-- only allow the spell reward if user can learn it
				if spellInfo and IsValidSpellReward(spellInfo.texture, knownSpell, spellInfo.isBoostSpell, spellInfo.garrFollowerID) then
					numQuestSpellRewards = numQuestSpellRewards + 1
					spellInfo.spellID = spellID
					AddSpellToBucket(spellBuckets, spellInfo)
				end
			end
		end
	end

	local totalRewards = numQuestRewards + numQuestChoices + numQuestCurrencies

	do -- Check if any rewards are present, break out if none
		if ( totalRewards == 0 and 
			money == 0 and 
			xp == 0 and 
			not playerTitle and 
			numQuestSpellRewards == 0 and 
			artifactXP == 0 ) then

			return self:Hide()
		end
	end

	do -- Hide unused rewards
		for i = totalRewards + 1, #rewardButtons do
			local rewardButton = rewardButtons[i]
			rewardButton:ClearAllPoints()
			rewardButton:Hide()
		end
	end

	-- Setup locals 
	local questItem, name, texture, quality, isUsable, numItems
	local rewardsCount = 0
	local lastFrame = self.Header

	local totalHeight = self.Header:GetHeight()
	local buttonHeight = self.Buttons[1]:GetHeight()

	do -- Artifact experience
		self.ArtifactXPFrame:ClearAllPoints()
		if ( artifactXP > 0 ) then
			local name, icon = C_ArtifactUI.GetArtifactXPRewardTargetInfo(artifactCategory)
			self.ArtifactXPFrame:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
			self.ArtifactXPFrame.Name:SetText(BreakUpLargeNumbers(artifactXP))
			self.ArtifactXPFrame.Icon:SetTexture(icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
			self.ArtifactXPFrame:Show()

			lastFrame = self.ArtifactXPFrame
			totalHeight = totalHeight + self.ArtifactXPFrame:GetHeight() + REWARDS_OFFSET
		else
			self.ArtifactXPFrame:Hide()
		end
	end

	do -- Setup choosable rewards
		self.ItemChooseText:ClearAllPoints()
		self.MoneyIcon:Hide()
		if ( numQuestChoices > 0 ) then
			self.ItemChooseText:Show()
			self.ItemChooseText:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -5)

			local highestValue, moneyItem
			local index
			local baseIndex = rewardsCount
			for i = 1, numQuestChoices do
				index = i + baseIndex
				questItem = GetItemButton(self, index)
				questItem.type = 'choice'
				questItem.objectType = 'item'
				questItem.questID = questID
				numItems = 1
				questItem:SetID(i)
				questItem:Show()

				-- Handle Blizzard's new Shadowlands shenanigans
				local newType = LOOT_ITEM_TYPES[API:GetQuestItemInfoLootType(questItem.type, i)]
				if newType then
					questItem.objectType = newType;
				end

				UpdateItemInfo(questItem)

				local vendorValue
				if (questItem.objectType == 'item') then
					local link = GetQuestItemLink(questItem.type, i)
					vendorValue = link and select(11, (GetItemInfo or C_Item.GetItemInfo)(link))
				end
				
				if vendorValue and ( not highestValue or vendorValue > highestValue ) then
					highestValue = vendorValue
					if vendorValue > 0 and numQuestChoices > 1 then
						moneyItem = questItem
					end
				end

				if ( i > 1 ) then
					if ( mod(i, ITEMS_PER_ROW) == 1 ) then
						questItem:SetPoint('TOPLEFT', rewardButtons[index - 2], 'BOTTOMLEFT', 0, -2)
						lastFrame = questItem
						totalHeight = totalHeight + buttonHeight + 2
					else
						questItem:SetPoint('TOPLEFT', rewardButtons[index - 1], 'TOPRIGHT', 1, 0)
					end
				else
					questItem:SetPoint('TOPLEFT', self.ItemChooseText, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
					lastFrame = questItem
					totalHeight = totalHeight + buttonHeight + REWARDS_OFFSET
				end
				rewardsCount = rewardsCount + 1
			end

			if moneyItem then
				self.MoneyIcon:SetPoint('BOTTOMRIGHT', moneyItem, -13, 6)
				self.MoneyIcon:Show()
			end

			if ( numQuestChoices == 1 ) then
				elements.chooseItems = nil
				self.ItemChooseText:SetText(REWARD_ITEMS_ONLY)
			elseif ( elements.chooseItems ) then
				self.ItemChooseText:SetText(REWARD_CHOOSE)
			else
				self.ItemChooseText:SetText(REWARD_CHOICES)
			end
			totalHeight = totalHeight + self.ItemChooseText:GetHeight() + REWARDS_OFFSET
		else
			elements.chooseItems = nil
			self.ItemChooseText:Hide()
		end
	end

	do -- Wipe reward pools
		self.spellRewardPool:ReleaseAll()
		self.followerRewardPool:ReleaseAll()
		self.spellHeaderPool:ReleaseAll()
	end

	do -- Setup spell rewards
		if ( numQuestSpellRewards > 0 ) then

			-- Sort buckets in the correct order
			for orderIndex, spellBucketType in ipairs(QUEST_INFO_SPELL_REWARD_ORDERING) do
				local spellBucket = spellBuckets[spellBucketType]
				if spellBucket then
					for i, spellInfo in ipairs(spellBucket) do
						local texture, name, spellID, garrFollowerID = spellInfo.texture, spellInfo.name, spellInfo.spellID, spellInfo.garrFollowerID
						if i == 1 then
							local header = self.spellHeaderPool:Acquire()
							header:SetText(QUEST_INFO_SPELL_REWARD_TO_HEADER[spellBucketType])
							header:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
							if self.spellHeaderPool.textR and self.spellHeaderPool.textG and self.spellHeaderPool.textB then
								header:SetVertexColor(self.spellHeaderPool.textR, self.spellHeaderPool.textG, self.spellHeaderPool.textB)
							end
							header:Show()

							totalHeight = totalHeight + header:GetHeight() + REWARDS_OFFSET
							lastFrame = header
						end

						local anchorFrame
						if garrFollowerID then
							local followerFrame = self.followerRewardPool:Acquire()
							local followerInfo = C_Garrison.GetFollowerInfo(garrFollowerID)
							followerFrame.Name:SetText(followerInfo.name)
							followerFrame.Class:SetAtlas(followerInfo.classAtlas)
							followerFrame.PortraitFrame:SetupPortrait(followerInfo)
							followerFrame.ID = garrFollowerID
							followerFrame:Show()

							anchorFrame = followerFrame
						else
							local spellRewardFrame = self.spellRewardPool:Acquire()
							spellRewardFrame.Icon:SetTexture(texture)
							spellRewardFrame.Name:SetText(name)
							spellRewardFrame.rewardSpellID = spellID
							spellRewardFrame:Show()

							anchorFrame = spellRewardFrame
						end
						if i % 2 ==  1 then
							anchorFrame:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
							totalHeight = totalHeight + anchorFrame:GetHeight() + REWARDS_OFFSET

							lastFrame = anchorFrame
						else
							anchorFrame:SetPoint('LEFT', lastFrame, 'RIGHT', 1, 0)
						end
					end
				end
			end
		end
	end

	do -- Title reward
		if ( playerTitle ) then
			self.PlayerTitleText:Show()
			self.PlayerTitleText:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
			totalHeight = totalHeight +  self.PlayerTitleText:GetHeight() + REWARDS_OFFSET
			self.TitleFrame:SetPoint('TOPLEFT', self.PlayerTitleText, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
			self.TitleFrame.Name:SetText(playerTitle)
			self.TitleFrame:Show()
			lastFrame = self.TitleFrame
			totalHeight = totalHeight +  self.TitleFrame:GetHeight() + REWARDS_OFFSET
		else
			self.PlayerTitleText:Hide()
			self.TitleFrame:Hide()
		end
	end

	do -- Setup mandatory rewards
		if ( numQuestRewards > 0 or numQuestCurrencies > 0 or money > 0 or xp > 0 ) then
			-- receive text, will either say 'You will receive' or 'You will also receive'
			local questItemReceiveText = self.ItemReceiveText
			if ( numQuestChoices > 0 or numQuestSpellRewards > 0 or playerTitle ) then
				questItemReceiveText:SetText(REWARD_ITEMS)
			else
				questItemReceiveText:SetText(REWARD_ITEMS_ONLY)
			end
			questItemReceiveText:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
			questItemReceiveText:Show()
			totalHeight = totalHeight + questItemReceiveText:GetHeight() + REWARDS_OFFSET
			lastFrame = questItemReceiveText

			do -- Money rewards
				if ( money > 0 ) then
					MoneyFrame_Update(self.MoneyFrame, money)
					self.MoneyFrame:Show()
				else
					self.MoneyFrame:Hide()
				end
			end

			do -- XP rewards
				if ( ToggleRewardElement(self.XPFrame, BreakUpLargeNumbers(xp), lastFrame) ) then
					lastFrame = self.XPFrame
					totalHeight = totalHeight + self.XPFrame:GetHeight() + REWARDS_OFFSET
				end
			end

			do -- Skill Point rewards
				if ( ToggleRewardElement(self.SkillPointFrame, skillPoints, lastFrame) ) then
					lastFrame = self.SkillPointFrame
					self.SkillPointFrame.Icon:SetTexture(skillIcon)
					if (skillName) then
						self.SkillPointFrame.Name:SetFormattedText(BONUS_SKILLPOINTS, skillName)
						self.SkillPointFrame.tooltip = format(BONUS_SKILLPOINTS_TOOLTIP, skillPoints, skillName)
					else
						self.SkillPointFrame.tooltip = nil
						self.SkillPointFrame.Name:SetText('')
					end
					totalHeight = totalHeight + buttonHeight + REWARDS_OFFSET
				end
			end

			local index
			local baseIndex = rewardsCount
			local buttonIndex = 0

			do -- Item rewards
				for i = 1, numQuestRewards, 1 do
					buttonIndex = buttonIndex + 1
					index = i + baseIndex
					questItem = GetItemButton(self, index)
					questItem.type = 'reward'
					questItem.objectType = 'item'
					questItem.questID = questID
					questItem:SetID(i)
					questItem:Show()

					UpdateItemInfo(questItem)

					if ( buttonIndex > 1 ) then
						if ( mod(buttonIndex, ITEMS_PER_ROW) == 1 ) then
							questItem:SetPoint('TOPLEFT', rewardButtons[index - 2], 'BOTTOMLEFT', 0, -2)
							lastFrame = questItem
							totalHeight = totalHeight + buttonHeight + 2
						else
							questItem:SetPoint('TOPLEFT', rewardButtons[index - 1], 'TOPRIGHT', 1, 0)
						end
					else
						questItem:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
						lastFrame = questItem
						totalHeight = totalHeight + buttonHeight + REWARDS_OFFSET
					end
					rewardsCount = rewardsCount + 1
				end
			end
			
			do -- Currency
				baseIndex = rewardsCount
				local foundCurrencies = 0
				buttonIndex = buttonIndex + 1
				for i = 1, numQuestCurrencies, 1 do
					index = i + baseIndex
					questItem = GetItemButton(self, index)
					questItem.type = 'reward'
					questItem.objectType = 'currency'
					questItem.questID = questID
					questItem:SetID(i)
					questItem:Show()

					if (UpdateItemInfo(questItem)) then

						if ( buttonIndex > 1 ) then
							if ( mod(buttonIndex, ITEMS_PER_ROW) == 1 ) then
								questItem:SetPoint('TOPLEFT', rewardButtons[index - 2], 'BOTTOMLEFT', 0, -2)
								lastFrame = questItem
								totalHeight = totalHeight + buttonHeight + 2
							else
								questItem:SetPoint('TOPLEFT', rewardButtons[index - 1], 'TOPRIGHT', 1, 0)
							end
						else
							questItem:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
							lastFrame = questItem
							totalHeight = totalHeight + buttonHeight + REWARDS_OFFSET
						end
						rewardsCount = rewardsCount + 1
						foundCurrencies = foundCurrencies + 1
						buttonIndex = buttonIndex + 1
						if (foundCurrencies == numQuestCurrencies) then
							break
						end
					end
				end
			end

			do -- Honor reward 
				self.HonorFrame:ClearAllPoints()
				if ( honor > 0 ) then
					local faction = UnitFactionGroup('player')
					local icon = faction and ('Interface\\Icons\\PVPCurrency-Honor-%s'):format(faction)

					self.HonorFrame:SetPoint('TOPLEFT', lastFrame, 'BOTTOMLEFT', 0, -REWARDS_OFFSET)
					self.HonorFrame.Count:SetText(BreakUpLargeNumbers(honor))
					self.HonorFrame.Name:SetText(HONOR)
					self.HonorFrame.Icon:SetTexture(icon)
					self.HonorFrame:Show()

					lastFrame = self.HonorFrame
					totalHeight = totalHeight + self.HonorFrame:GetHeight() + REWARDS_OFFSET
				else
					self.HonorFrame:Hide()
				end
			end

		else -- Hide all sub-frames
			self.ItemReceiveText:Hide()
			self.MoneyFrame:Hide()
			self.XPFrame:Hide()
			self.SkillPointFrame:Hide()
			self.HonorFrame:Hide()
		end
	end

	-- deselect item
	elements.itemChoice = 0
	if ( self.ItemHighlight ) then
		self.ItemHighlight:Hide()
	end

	self:Show()
	self:SetHeight(totalHeight)
	return self, lastFrame
end

function Elements:CompleteQuest()
	local numQuestChoices = GetNumQuestChoices()
	self.itemChoice = (numQuestChoices == 1 and 1) or self.itemChoice

	if ( self.itemChoice == 0 and numQuestChoices > 0 ) then
		QuestChooseRewardError()
	else
		GetQuestReward(self.itemChoice)
	end
end


function Elements:AcceptQuest()
	if ( API:QuestFlagsPVP() ) then
		StaticPopup_Show('CONFIRM_ACCEPT_PVP_QUEST')
	else
		if ( API:QuestGetAutoAccept() ) then
			AcknowledgeAutoAcceptQuest()
		else
			AcceptQuest()
		end
	end
	PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
end

function Elements:ShowProgress(material)
	self:Show()
	self.Content:Hide()
	self:SetMaterial(material)
	local self = self.Progress
	local numRequiredItems = API:GetNumQuestItems()
	local numRequiredMoney = API:GetQuestMoneyToGet()
	local numRequiredCurrencies = API:GetNumQuestCurrencies()
	local buttonIndex, buttons = 1, self.Buttons
	if ( numRequiredItems > 0 or numRequiredMoney > 0 or numRequiredCurrencies > 0) then
		self:Show()
		self.ReqText:Show()

		-- If there's money required then anchor and display it
		if ( numRequiredMoney > 0 ) then
			MoneyFrame_Update(self.MoneyFrame, numRequiredMoney)
			
			local moneyColor, moneyVertex
			if ( numRequiredMoney > GetMoney() ) then
				moneyColor, moneyVertex = 'red', 0.2
			else
				moneyColor, moneyVertex = 'white', 0.75
			end

			self.MoneyText:SetTextColor(moneyVertex, moneyVertex, moneyVertex)
			SetMoneyFrameColor(self.MoneyFrame, moneyColor)

			self.MoneyText:Show()
			self.MoneyFrame:Show()

			-- Reanchor required item
			buttons[1]:SetPoint('TOPLEFT', self.MoneyText, 'BOTTOMLEFT', 0, -10)
		else
			self.MoneyText:Hide()
			self.MoneyFrame:Hide()
			-- Reanchor required item
			buttons[1]:SetPoint('TOPLEFT', self.ReqText, 'BOTTOMLEFT', -3, -5)
		end

		for i=1, numRequiredItems do	
			local hidden = IsQuestItemHidden(i)
			if ( hidden == 0 ) then
				local requiredItem = GetItemButton(self, buttonIndex, 'ProgressItem')
				requiredItem.type = 'required'
				requiredItem.objectType = 'item'
				requiredItem.questID = questID
				requiredItem:SetID(i)
				requiredItem:Show()

				UpdateItemInfo(requiredItem, true)

				if ( buttonIndex > 1 ) then
					if ( mod(buttonIndex, ITEMS_PER_ROW) == 1 ) then
						requiredItem:SetPoint('TOPLEFT', buttons[buttonIndex - 2], 'BOTTOMLEFT', 0, -2)
					else
						requiredItem:SetPoint('TOPLEFT', buttons[buttonIndex - 1], 'TOPRIGHT', 1, 0)
					end
				end

				buttonIndex = buttonIndex + 1
			end
		end
		
		for i=1, numRequiredCurrencies do	
			local requiredItem = GetItemButton(self, buttonIndex, 'ProgressItem')
			requiredItem.type = 'required'
			requiredItem.objectType = 'currency'
			requiredItem.questID = questID
			requiredItem:SetID(i)
			requiredItem:Show()

			UpdateItemInfo(requiredItem)

			if ( buttonIndex > 1 ) then
				if ( mod(buttonIndex, ITEMS_PER_ROW) == 1 ) then
					requiredItem:SetPoint('TOPLEFT', buttons[buttonIndex - 2], 'BOTTOMLEFT', 0, -2)
				else
					requiredItem:SetPoint('TOPLEFT', buttons[buttonIndex - 1], 'TOPRIGHT', 1, 0)
				end
			end

			buttonIndex = buttonIndex + 1
		end
	else
		self:Hide()
		self.MoneyText:Hide()
		self.MoneyFrame:Hide()
		self.ReqText:Hide()
	end

	for i=buttonIndex, #buttons do
		buttons[i]:Hide()
	end
	return self:IsShown()
end
----------------------------------
-- Quest templates
----------------------------------
TEMPLATE.QUEST_DETAIL = { chooseItems = nil, contentWidth = 507,
	canHaveSealMaterial = true, sealXOffset = 400, sealYOffset = -6,
	elements = {
		Elements.ShowObjectivesHeader, 0, -15,
		Elements.ShowObjectivesText, 0, -5,
		Elements.ShowSpecialObjectives, 0, -10,
		Elements.ShowGroupSize, 0, -10,
		Elements.ShowRewards, 0, -15,
		Elements.ShowSeal, 0, 0,
		Elements.ShowAccountCompleted, 0, -15,
	}
}

TEMPLATE.QUEST_REWARD = { chooseItems = true, contentWidth = 507,
	canHaveSealMaterial = nil, sealXOffset = 300, sealYOffset = -6,
	elements = {
		Elements.ShowRewards, 0, -10,
	}
}