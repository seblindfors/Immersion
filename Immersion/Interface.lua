local API = {}; ImmersionAPI = API;

function API:GetFriendshipReputation(...)
	return GetFriendshipReputation and GetFriendshipReputation(...) or 0
end

function API:GetPortraitAtlas()
	if GetAtlasInfo and GetAtlasInfo('TalkingHeads-PortraitFrame') then
		return 'TalkingHeads-PortraitFrame';
	end
	return 'TalkingHeads-Alliance-PortraitFrame';
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

function API:GetAvailableQuestInfo(...)
	if GetAvailableQuestInfo then
		return GetAvailableQuestInfo(...)
	end
	return IsAvailableQuestTrivial(...)
end

function API:IsActiveQuestLegendary(...)
	return IsActiveQuestLegendary and IsActiveQuestLegendary(...)
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