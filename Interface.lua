local API = {}; ImmersionAPI = API;
-- Version
local IS_VANILLA = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC or nil;
local IS_RETAIL  = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE or nil;
local IS_CLASSIC = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC or nil;
local IS_WOW10   = (function() -- WoW10 == modern API
	local version = select(4, GetBuildInfo())
	if version >= 30401 or ( version >= 11404 and version <= 20000 ) then
		return true
	end
end)();

API.IsRetail = IS_RETAIL;
API.IsWoW10  = IS_WOW10;

-- Quest pickup API
function API:CloseQuest(onQuestClosed, ...)
	if onQuestClosed and IS_WOW10 then return end;
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

function API:GetQuestIconOffer(...)
	if QuestUtil and QuestUtil.GetQuestIconOfferForQuestID then
		return QuestUtil.GetQuestIconOfferForQuestID(...)
	end
	local isLegendary, frequency, isRepeatable = select(2, ...)
	local icon =
		( isLegendary and 'AvailableLegendaryQuestIcon') or
		( frequency and frequency > 0 and 'DailyQuestIcon') or
		( isRepeatable and 'DailyActiveQuestIcon') or
		( 'AvailableQuestIcon' )
	return ([[Interface\GossipFrame\%s]]):format(icon)
end

function API:GetQuestIconActive(...)
	if QuestUtil and QuestUtil.GetQuestIconActiveForQuestID then
		return QuestUtil.GetQuestIconActiveForQuestID(...)
	end
	local isComplete, isLegendary = select(2, ...)
	local icon =
		( isComplete ) and (
			( isLegendary and  'ActiveLegendaryQuestIcon') or
			( isComplete and 'ActiveQuestIcon')
		) or ( 'InCompleteQuestIcon' )
	return ([[Interface\GossipFrame\%s]]):format(icon)
end

-- Quest content API
function API:GetSuggestedGroupNum(...)
	return (C_QuestLog and C_QuestLog.GetSuggestedGroupSize or GetSuggestedGroupNum)(...) or 0
end

function API:GetAccountCompleted(...)
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompletedOnAccount then
		return C_QuestLog.IsQuestFlaggedCompletedOnAccount(...)
	end
end

function API:GetNumQuestRewards(...)
	return GetNumQuestRewards and GetNumQuestRewards(...) or 0
end

function API:GetNumQuestChoices(...)
	return GetNumQuestChoices and GetNumQuestChoices(...) or 0
end

function API:GetNumRewardCurrencies(...)
	if GetNumRewardCurrencies then
		return GetNumRewardCurrencies(...) or 0
	end
	return #(C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardCurrencies(...) or {})
end

function API:GetQuestCurrencyInfo(itemType, index)
	if C_QuestOffer and C_QuestOffer.GetQuestRequiredCurrencyInfo then
		local currencyInfo
		if itemType == 'required' then
			currencyInfo = C_QuestOffer.GetQuestRequiredCurrencyInfo(index)
		else
			currencyInfo = C_QuestOffer.GetQuestRewardCurrencyInfo(itemType, index)
		end
		if currencyInfo then
			currencyInfo.displayedAmount = (itemType == 'required') and currencyInfo.requiredAmount or currencyInfo.totalRewardAmount
			return currencyInfo
		end
	elseif GetQuestCurrencyInfo then
		local name, texture, amount, quality = GetQuestCurrencyInfo(itemType, index)
		local currencyID = GetQuestCurrencyID(itemType, index)
		if name and currencyID then
			return {
				texture = texture,
				name = name,
				currencyID = currencyID,
				quality = quality or 0,
				baseRewardAmount = amount,
				bonusRewardAmount = 0,
				totalRewardAmount = amount,
				questRewardContextFlags = nil,
				displayedAmount = amount
			}
		end
	end
end

function API:GetRewardMoney(...)
	return GetRewardMoney and GetRewardMoney(...) or 0
end

function API:GetRewardSkillPoints(...)
	if GetRewardSkillPoints then
		return GetRewardSkillPoints(...)
	end
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

function API:GetQuestRewardSpells(...)
	return C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpells(...) or {}
end

function API:GetQuestRewardSpellInfo(...)
	return C_QuestInfoSystem and C_QuestInfoSystem.GetQuestRewardSpellInfo(...) or {}
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
function API:CloseGossip(onGossipClosed, ...)
	if onGossipClosed and IS_WOW10 then return end;
	return C_GossipInfo and C_GossipInfo.CloseGossip(...)
end

function API:ForceGossip(...)
	return C_GossipInfo and C_GossipInfo.ForceGossip(...)
end

function API:CanAutoSelectGossip(dontAutoSelect)
	local gossip, option = self:GetGossipOptions()
	if ( #gossip > 0 ) then
		local firstOption = gossip[1];
		option = firstOption.selectOptionWhenOnlyOption and (firstOption.orderIndex or firstOption.gossipOptionID);
		option = option or (firstOption.type and firstOption.type:lower() ~= 'gossip' and 1)
	end
	if option then
		if not dontAutoSelect then
			self:SelectGossipOption(option)
		end
		return true
	end
end

function API:GetGossipText(...)
	return C_GossipInfo and C_GossipInfo.GetText(...)
end

function API:GetNumGossipAvailableQuests(...)
	return C_GossipInfo and C_GossipInfo.GetNumAvailableQuests(...)
end

function API:GetNumGossipActiveQuests(...)
	return C_GossipInfo and C_GossipInfo.GetNumActiveQuests(...)
end

function API:GetNumGossipOptions(...)
	return #(C_GossipInfo and C_GossipInfo.GetOptions(...) or {})
end

function API:GetGossipAvailableQuests(...)
	return C_GossipInfo and C_GossipInfo.GetAvailableQuests(...)
end

function API:GetGossipActiveQuests(...)
	return C_GossipInfo and C_GossipInfo.GetActiveQuests(...)
end

function API:GetGossipOptions(...)
	assert(C_GossipInfo.GetOptions, 'C_GossipInfo.GetOptions does not exist.')
	if GossipOptionSort then
		local gossipOptions = C_GossipInfo.GetOptions(...)
		table.sort(gossipOptions, GossipOptionSort)
		return gossipOptions
	end
	return C_GossipInfo.GetOptions(...)
end

function API:GetGossipOptionID(option)
	return option.orderIndex;
end

-- Quest greeting API
function API:GetNumActiveQuests(...)
	return GetNumActiveQuests and GetNumActiveQuests(...) or 0
end

function API:GetNumAvailableQuests(...)
	return GetNumAvailableQuests and GetNumAvailableQuests(...) or 0
end

function API:GetActiveQuestID(...)
	return GetActiveQuestID and GetActiveQuestID(...)
end

-- Gossip/quest selectors API
function API:SelectActiveQuest(...)
	if SelectActiveQuest then
		return SelectActiveQuest(...)
	end
end

function API:SelectAvailableQuest(...)
	if SelectAvailableQuest then
		return SelectAvailableQuest(...)
	end
end

function API:SelectGossipOption(...)
	return (C_GossipInfo and (C_GossipInfo.SelectOptionByIndex or C_GossipInfo.SelectOption) or SelectGossipOption)(...)
end

function API:SelectGossipActiveQuest(...)
	return C_GossipInfo and C_GossipInfo.SelectActiveQuest(...)
end

function API:SelectGossipAvailableQuest(...)
	return C_GossipInfo and C_GossipInfo.SelectAvailableQuest(...)
end

-- Misc
function API:GetUnitName(...)
	return GetUnitName and GetUnitName(...)
end

function API:GetPortraitAtlas()
	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo('TalkingHeads-PortraitFrame') then
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

-- Interaction manager, events from PlayerInteractionManagerConstantsDocumentation.lua
local StayOpenOnInteractionTypes = Enum and Enum.PlayerInteractionType and {
	[Enum.PlayerInteractionType.Gossip] = true;
	[Enum.PlayerInteractionType.Item] = true;
	[Enum.PlayerInteractionType.QuestGiver] = true;
} or {};

function API:ShouldCloseOnInteraction(type)
	return not StayOpenOnInteractionTypes[type];
end