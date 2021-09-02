local API = {}; ImmersionAPI = API;
-- Version
local IS_VANILLA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or nil;
local IS_RETAIL  = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or nil;
local IS_CLASSIC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC or nil;

function API:IsVanilla() return IS_VANILLA end
function API:IsRetail()  return IS_RETAIL  end
function API:IsClassic() return IS_CLASSIC end
function API:IsClassicOrVanilla() return IS_CLASSIC or IS_VANILLA end 

API.ITERATORS = {
	GOSSIP    = (IS_VANILLA or IS_CLASSIC) and 2 or IS_RETAIL and 2;
	ACTIVE    = (IS_VANILLA or IS_CLASSIC) and 6 or IS_RETAIL and 7;
	AVAILABLE = (IS_VANILLA or IS_CLASSIC) and 7 or IS_RETAIL and 8;
}

-- Chunk iterators
function API:GetGossipOptionIterator(...)   return self.ITERATORS.GOSSIP    end
function API:GetActiveQuestIterator(...)    return self.ITERATORS.ACTIVE    end
function API:GetAvailableQuestIterator(...) return self.ITERATORS.AVAILABLE end

-- Map select to table values
local function map(lambda, step, ...)
	local data = {}
	for i = 1, select('#', ...), step do
		data[#data + 1] = lambda(nil, i, ...)
	end
	return data
end

function API:MapGossipAvailableQuests(i, ...)
	--local titleText, level, isTrivial, frequency, isRepeatable, isLegendary, isIgnored = select(i, ...);
	local title, level, trivial, frequency, repeatable, legendary, id = select(i, ...)
	return {
		title       = title,
		questLevel  = level,
		isTrivial   = trivial,
		frequency   = frequency,
		repeatable  = repeatable,
		isLegendary = legendary,
		questID     = id,
	}
end

function API:MapGossipActiveQuests(i, ...)
	local title, level, trivial, complete, legendary, id = select(i, ...)
	return {
		title       = title,
		questLevel  = level,
		isTrivial   = trivial,
		isComplete  = complete,
		isLegendary = legendary,
		questID     = id,
	}
end

function API:MapGossipOptions(i, ...)
	local name, icon = select(i, ...)
	return {
		name = name,
		type = icon,
	}
end

-- Quest pickup API
function API:CloseQuest(...)
	return CloseQuest and CloseQuest(...)
end

function API:GetGreetingText(...)
	return GetGreetingText and GetGreetingText(...)
end

function API:GetTitleText(...)
	return GetTitleText and GetTitleText(...)
end

function API:GetProgressText(...)
	return GetProgressText and GetProgressText(...)
end

function API:GetRewardText(...)
	return GetRewardText and GetRewardText(...)
end

function API:GetQuestText(...)
	return GetQuestText and GetQuestText(...)
end

function API:QuestGetAutoAccept(...)
	return QuestGetAutoAccept and QuestGetAutoAccept(...)
end

function API:QuestIsFromAdventureMap(...)
	return QuestIsFromAdventureMap and QuestIsFromAdventureMap(...)
end

function API:QuestIsFromAreaTrigger(...)
	return QuestIsFromAreaTrigger and QuestIsFromAreaTrigger(...)
end

function API:QuestFlagsPVP(...)
	return QuestFlagsPVP and QuestFlagsPVP(...)
end

function API:GetQuestIconOffer(quest)
	if QuestUtil and QuestUtil.GetQuestIconOffer then
		return QuestUtil.GetQuestIconOffer(
			quest.isLegendary,
			quest.frequency,
			quest.repeatable,
			QuestUtil.ShouldQuestIconsUseCampaignAppearance(quest.questID)
		)
	end
	local icon =
		( quest.isLegendary and 'AvailableLegendaryQuestIcon') or
		( quest.frequency and quest.frequency > 1 and 'DailyQuestIcon') or
		( quest.repeatable and 'DailyActiveQuestIcon') or
		( 'AvailableQuestIcon' )
	return ([[Interface\GossipFrame\%s]]):format(icon)
end

function API:GetQuestIconActive(quest)
	if QuestUtil and QuestUtil.GetQuestIconActive then
		return QuestUtil.GetQuestIconActive(
			quest.isComplete,
			quest.isLegendary,
			quest.frequency,
			quest.repeatable,
			QuestUtil.ShouldQuestIconsUseCampaignAppearance(quest.questID)
		)
	end
	local icon =
		( quest.isComplete ) and (
			( quest.isLegendary and  'ActiveLegendaryQuestIcon') or
			( quest.isComplete and 'ActiveQuestIcon')
		) or ( 'InCompleteQuestIcon' )
	return ([[Interface\GossipFrame\%s]]):format(icon)
end

-- Quest content API
function API:GetSuggestedGroupNum(...)
	return GetSuggestedGroupNum and GetSuggestedGroupNum(...) or 0
end

function API:GetNumQuestRewards(...)
	return GetNumQuestRewards and GetNumQuestRewards(...) or 0
end

function API:GetNumQuestChoices(...)
	return GetNumQuestChoices and GetNumQuestChoices(...) or 0
end

function API:GetNumRewardCurrencies(...)
	return GetNumRewardCurrencies and GetNumRewardCurrencies(...) or 0
end

function API:GetRewardMoney(...)
	return GetRewardMoney and GetRewardMoney(...) or 0
end

function API:GetRewardSkillPoints(...)
	return GetRewardSkillPoints and GetRewardSkillPoints(...) or 0
end

function API:GetRewardXP(...)
	return GetRewardXP and GetRewardXP(...) or 0
end

function API:GetRewardArtifactXP(...)
	return GetRewardArtifactXP and GetRewardArtifactXP(...) or 0
end

function API:GetRewardHonor(...)
	return GetRewardHonor and GetRewardHonor(...) or 0
end

function API:GetRewardTitle(...)
	return GetRewardTitle and GetRewardTitle(...)
end

function API:GetNumRewardSpells(...)
	return GetNumRewardSpells and GetNumRewardSpells(...) or 0
end

function API:GetMaxRewardCurrencies(...)
	return GetMaxRewardCurrencies and GetMaxRewardCurrencies(...) or 0
end

function API:GetNumQuestItems(...)
	return GetNumQuestItems and GetNumQuestItems(...) or 0
end

function API:GetQuestMoneyToGet(...)
	return GetQuestMoneyToGet and GetQuestMoneyToGet(...) or 0
end

function API:GetNumQuestCurrencies(...)
	return GetNumQuestCurrencies and GetNumQuestCurrencies(...) or 0
end

function API:GetSuperTrackedQuestID(...)
	return C_SuperTrack and C_SuperTrack.GetSuperTrackedQuestID(...)
end

function API:GetAvailableQuestInfo(...)
	if GetAvailableQuestInfo then
		return GetAvailableQuestInfo(...)
	end
	return IsAvailableQuestTrivial(...)
end

function API:IsActiveQuestLegendary(...)
	return IsActiveQuestLegendary and IsActiveQuestLegendary(...)
end

function API:IsQuestCompletable(...)
	return IsQuestCompletable and IsQuestCompletable(...)
end

-- Gossip API
function API:CloseGossip(...)
	if CloseGossip then return CloseGossip(...) end
	return C_GossipInfo.CloseGossip(...)
end

function API:ForceGossip(...)
	if ForceGossip then return ForceGossip(...) end
	return C_GossipInfo.ForceGossip(...)
end

function API:CanAutoSelectGossip(dontAutoSelect)
	local gossip = self:GetGossipOptions()
	if ( #gossip > 0  and gossip[1].type:lower() ~= 'gossip') then
		if not dontAutoSelect then
			self:SelectGossipOption(1)
		end
		return true
	end
end

function API:GetGossipText(...)
	if GetGossipText then return GetGossipText(...) end
	return C_GossipInfo.GetText()
end

function API:GetNumGossipAvailableQuests(...)
	if GetNumGossipAvailableQuests then return GetNumGossipAvailableQuests(...) end
	return C_GossipInfo.GetNumAvailableQuests(...)
end

function API:GetNumGossipActiveQuests(...)
	if GetNumGossipActiveQuests then return GetNumGossipActiveQuests(...) end
	return C_GossipInfo.GetNumActiveQuests(...)
end

function API:GetNumGossipOptions(...)
	if GetNumGossipOptions then return GetNumGossipOptions(...) end
	return C_GossipInfo.GetNumOptions(...)
end

function API:GetGossipAvailableQuests(...)
	if GetGossipAvailableQuests then
		return map(
			API.MapGossipAvailableQuests,
			API:GetAvailableQuestIterator(),
			GetGossipAvailableQuests(...)
		)
	end
	return C_GossipInfo.GetAvailableQuests(...)
end

function API:GetGossipActiveQuests(...)
	if GetGossipActiveQuests then
		return map(
			API.MapGossipActiveQuests,
			API:GetActiveQuestIterator(),
			GetGossipActiveQuests(...)
		)
	end
	return C_GossipInfo.GetActiveQuests(...)
end

function API:GetGossipOptions(...)
	if GetGossipOptions then
		return map(
			API.MapGossipOptions,
			API:GetGossipOptionIterator(),
			GetGossipOptions(...)
		)
	end
	return C_GossipInfo.GetOptions(...)
end

-- Gossip/quest selectors API
function API:SelectActiveQuest(...)
	if SelectActiveQuest then return SelectActiveQuest(...) end
end

function API:SelectAvailableQuest(...)
	if SelectAvailableQuest then return SelectAvailableQuest(...) end
end

function API:SelectGossipOption(...)
	if SelectGossipOption then return SelectGossipOption(...) end
	return C_GossipInfo.SelectOption(...)
end

function API:SelectGossipActiveQuest(...)
	if SelectGossipActiveQuest then return SelectGossipActiveQuest(...) end
	return C_GossipInfo.SelectActiveQuest(...)
end

function API:SelectGossipAvailableQuest(...)
	if SelectGossipAvailableQuest then return SelectGossipAvailableQuest(...) end
	return C_GossipInfo.SelectAvailableQuest(...)
end

-- Misc
function API:GetUnitName(...)
	return GetUnitName and GetUnitName(...)
end

function API:GetFriendshipReputation(...)
	if GetFriendshipReputation then
		return GetFriendshipReputation(...)
	end
	return 0
end

function API:GetPortraitAtlas()
	if GetAtlasInfo and GetAtlasInfo('TalkingHeads-PortraitFrame') then
		return 'TalkingHeads-PortraitFrame';
	end
	return 'TalkingHeads-Alliance-PortraitFrame';
end

function API:IsAzeriteItem(...)
	if C_AzeriteEmpoweredItem then
		return 	C_AzeriteEmpoweredItem.IsAzeriteEmpoweredItemByID(...) and
				C_AzeriteEmpoweredItem.IsAzeritePreviewSourceDisplayable(...)
	end
end

function API:IsCharacterNewlyBoosted(...)
	return IsCharacterNewlyBoosted and IsCharacterNewlyBoosted(...)
end

function API:IsFollowerCollected(...)
	return C_Garrison and C_Garrison.IsFollowerCollected(...)
end

function API:GetNamePlateForUnit(...)
	return C_NamePlate and C_NamePlate.GetNamePlateForUnit(...)
end

function API:GetCreatureID(unit)
	local guid = unit and UnitGUID(unit)
	return guid and select(6, strsplit('-', guid))
end

function API:CloseItemText(...)
	if CloseItemText then return CloseItemText(...) end
end

function API:GetQuestDetailsTheme(...)
	if C_QuestLog and C_QuestLog.GetQuestDetailsTheme then
		return C_QuestLog.GetQuestDetailsTheme(...)
	end
end

function API:GetQuestItemInfoLootType(...)
	if GetQuestItemInfoLootType then
		return GetQuestItemInfoLootType(...)
	end
end