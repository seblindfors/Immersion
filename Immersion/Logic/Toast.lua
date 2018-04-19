local _, L = ...
local Toast, Text = ImmersionToast, ImmersionToast.Text
----------------------------------
local FadeIn, FadeOut = L.UIFrameFadeIn, L.UIFrameFadeOut
----------------------------------
local playbackQueue, textCache = {}, {}
----------------------------------

Mixin(Toast.Text, L.TextMixin)
Toast.Text:SetFontObjectsToTry(SystemFont_Shadow_Large_Outline, SystemFont_Shadow_Med1_Outline, SystemFont_Outline_Small)

function Toast:Queue(title, text, npcType, unit)
	if not self:IsTextCached(text) then

		-- Add new entry for playback.
		tinsert(playbackQueue, {
			title;		-- title to display on the header.
			text;		-- text to animate.
			npcType; 	-- type of NPC for the indicator icon.
			GetQuestID(); -- questID if it exists.
			L.ClickedTitleCache or {}; -- which gossip option was clicked?
			self:PrepareNameAndIcon(unit); -- unit name and portrait icon object.
		})

		-- Cache the text to prevent repeated playback.
		self:CacheText(text)

		if not self:IsObstructed() then
			self:DisplayNextData()
		end
	end
end

function Toast:PopOrClose()
	local poppedToast = tremove(playbackQueue, 1)
	if not next(playbackQueue) then
		self.releaseToastOnHide = poppedToast
		self:AttemptFadeOut()
	else
		self:ReleaseIconForToast(poppedToast)
		self:DisplayNextData()
	end
end

function Toast:PopToastForText(text)
	if self:IsObstructed() then
		for i, playbackItem in ipairs(playbackQueue) do
			if playbackItem[2] == text then
				self:ReleaseIconForToast(tremove(playbackQueue, i))
				break
			end
		end
		local cacheIndex = self:IsTextCached(text)
		if cacheIndex then
			tremove(textCache, cacheIndex)
		end
	end
end

function Toast:PrepareNameAndIcon(unit)
	self:ReleaseIconForToast(self.releaseToastOnHide)
	local icon = self.IconPool:Acquire()
	local name = unit and UnitName(unit) or ''

	icon:SetPoint('CENTER', self.IconBorder)
	icon:SetSize(42, 42)
	SetPortraitTexture(icon, unit)

	if unit and UnitExists(unit) then
		SetPortraitTexture(icon, unit)
	else
		icon:SetTexture([[Interface\QuestFrame\UI-QuestLog-BookIcon]])
	end

	return name, icon
end

-- Repeated playback prevention through caching.
-- Wipe when toast resets.
function Toast:CacheText(text)
	textCache[#textCache + 1] = text
end

function Toast:IsTextCached(text)
	for i, cachedText in ipairs(textCache) do
		if text == cachedText then
			return i
		end
	end
end

-- Toast display handling:
function Toast:DisplayNextData()
	local title, text, npcType, questID, cache, name, icon = unpack(playbackQueue[1])
	icon:Show()
	self.Header.Title:SetText(name or title)

	self.Text:SetText(text)
	self.ToastType:SetTexture('Interface\\GossipFrame\\' .. npcType .. 'Icon')

	self.Subtitle:SetText(cache.text or ( title ~= name and title) )
	self.CacheType:SetTexture(cache.icon)
	self:PlayAnimations()
end

function Toast:DisplayClickableQuest(questID)
	local hasQuestID 	= ( questID and questID ~= 0)
	local logIndex 		= ( hasQuestID and GetQuestLogIndexByID(questID) )
	local isQuestActive = ( logIndex and logIndex ~= 0 )
	local isQuestTurnIn = ( hasQuestID and IsQuestComplete(questID) )
	local isQuestCompleted = ( hasQuestID and IsQuestFlaggedCompleted(questID) )

	if hasQuestID then
		self.Subtitle:SetVertexColor(1, .82, 0)
		self.ToastType:SetTexture(nil)
	else
		self.Subtitle:SetVertexColor(.75, .75, .75)
	end

	self.logIndex = nil
	self.questID = nil
	self.QuestButton:Hide()

	if isQuestTurnIn or isQuestActive then
		self.logIndex = logIndex
		self.questID = questID
		self.CacheType:SetTexture(nil)
		self.QuestButton:Show()
	elseif isQuestCompleted then
		self.CacheType:SetTexture('Interface\\GossipFrame\\BankerGossipIcon')
	elseif hasQuestID then
		self.CacheType:SetTexture('Interface\\GossipFrame\\AvailableQuestIcon')
	end
end

function Toast:ReleaseIconForToast(toast)
	if toast then
		self.IconPool:Release(toast[#toast])
	end
end

function Toast:ReleaseAndHide()
	wipe(playbackQueue)
	wipe(textCache)
	self.IconPool:ReleaseAll()
	self.releaseToastOnHide = nil
	self:Hide()
end

function Toast:PauseAndHide(fadeTime)
	if ( self.fadeState ~= 'out' ) then
		Text:PauseTimer()
		FadeOut(self, fadeTime or 1, self:GetAlpha(), 0, {
			finishedFunc = self.Hide;
			finishedArg1 = self;
		})
		self.fadeState = 'out'
	end
end

function Toast:Play()
	if playbackQueue[1] then
		if Text:ResumeTimer() then
			self:AttemptFadeIn()
			self:PlayAnimations()
		else
			self:DisplayNextData()
		end
	end
end

-- NOTE: AttemptFadeOut and AttemptFadeIn cancel the other's effect.
function Toast:AttemptFadeOut(fadeTime)
	if ( self.fadeState ~= 'out' ) then
		FadeOut(self, fadeTime or 1, self:GetAlpha(), 0, {
			finishedFunc = self.ReleaseAndHide;
			finishedArg1 = self;
		})
		self.fadeState = 'out'
	end
end

function Toast:AttemptFadeIn(fadeTime)
	if ( self.fadeState ~= 'in' ) then
		FadeIn(self, fadeTime or 0.2, self:GetAlpha(), 1)
		self:Show()
		self.fadeState = 'in'
	end
end

function Toast:OnCloseButtonClicked()
	Text.numTexts = nil
	Text:PauseTimer()
	Text:OnFinished()
	self:PopOrClose()
end

-- Show quest details if available.
function Toast:OnQuestButtonClicked()
	if self.logIndex and self.questID then
		SetSuperTrackedQuestID(self.questID)
	end
end

local QUEST_ICONS
do 	local QUEST_ICONS_FILE = 'Interface\\QuestFrame\\QuestTypeIcons'
	local QUEST_ICONS_FILE_WIDTH = 128
	local QUEST_ICONS_FILE_HEIGHT = 64
	local QUEST_ICON_SIZE = 18

	local function CreateQuestIconTextureMarkup(left, right, top, bottom)
		return CreateTextureMarkup(
			QUEST_ICONS_FILE, 
			QUEST_ICONS_FILE_WIDTH, 
			QUEST_ICONS_FILE_HEIGHT, 
			QUEST_ICON_SIZE, QUEST_ICON_SIZE, 
			left / QUEST_ICONS_FILE_WIDTH,
			right / QUEST_ICONS_FILE_WIDTH,
			top / QUEST_ICONS_FILE_HEIGHT,
			bottom / QUEST_ICONS_FILE_HEIGHT) .. ' '
	end

	QUEST_ICONS = {
		item 	= CreateQuestIconTextureMarkup(18, 36, 36, 54);
		object 	= CreateQuestIconTextureMarkup(72, 90,  0, 18);
		event 	= CreateQuestIconTextureMarkup(36, 54, 18, 36);
		monster = CreateQuestIconTextureMarkup(0,  18, 36, 54);
	--	reputation = CreateQuestIconTextureMarkup();
	--	log = CreateQuestIconTextureMarkup();
	-- 	player = CreateQuestIconTextureMarkup();
	}
end

function Toast:OnQuestButtonMouseover()
	if self.questID then
		local logIndex = GetQuestLogIndexByID(self.questID)
		if logIndex then
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(logIndex)

			GameTooltip:SetOwner(self.QuestButton, 'ANCHOR_TOPLEFT')
			GameTooltip:AddLine(title)

			if isComplete and isComplete > 0 then
				local completionText = GetQuestLogCompletionText(logIndex) or QUEST_WATCH_QUEST_READY
				GameTooltip:AddLine(completionText, 1, 1, 1, true)
			else
				local _, objectiveText = GetQuestLogQuestText(logIndex)
				GameTooltip:AddLine(objectiveText, 1, 1, 1, true)

				local requiredMoney = GetQuestLogRequiredMoney(logIndex)
				local numObjectives = GetNumQuestLeaderBoards(logIndex)

				if numObjectives > 0 then
					GameTooltip:AddLine(' ')
				end

				for i = 1, numObjectives do
					local text, objectiveType, finished = GetQuestLogLeaderBoard(i, logIndex)
					if text then
						local color = HIGHLIGHT_FONT_COLOR
						local marker = QUEST_ICONS[objectiveType] or QUEST_DASH
						if finished then
							color = GRAY_FONT_COLOR
						end
						GameTooltip:AddLine(marker..text, color.r, color.g, color.b, true)
					end
				end
				if 	requiredMoney > 0 then
					local playerMoney = GetMoney()
					local color = HIGHLIGHT_FONT_COLOR
					if 	requiredMoney <= playerMoney then
						playerMoney = requiredMoney
						color = GRAY_FONT_COLOR
					end
					GameTooltip:AddLine(QUEST_DASH..GetMoneyString(playerMoney)..' / '..GetMoneyString(requiredMoney), color.r, color.g, color.b)
				end
				GameTooltip:Show()
			end
		end
	end
end

-- Text callbacks:
--	OnFinishedCallback: lets toast know playback is done, show new content or hide.
--	OnDisplayLineCallback: show toast on playback, refit the frames for current content.
function Text:OnFinishedCallback()
	Toast:PopOrClose()
end

function Text:OnDisplayLineCallback()
	FadeIn(self, 0.3, 0, 1)
	local currentFontObject = self:GetFontObject()

	Toast.Subtitle:SetFontObject(currentFontObject)
	Toast:AttemptFadeIn()
	Toast:DisplayClickableQuest(playbackQueue[1] and playbackQueue[1][4])

	local numTotalLines = self:GetNumLines() + Toast.Subtitle:GetNumLines()
	local _, fontSize = currentFontObject:GetFont()
	local newheight = ( numTotalLines * fontSize ) + 24
	Toast.Header.TextBackground:SetHeight(newheight)
end



do	-- OBSTRUCTION:
	-- The toast should not play text while *obstructing* frames are showing.
	-- The user should be limited to one focal point at a time, so the case where
	-- multiple frames are playing text at the same time must be handled.
	local obstructorsShowing = 0
	local function ObstructorOnShow()
		obstructorsShowing = obstructorsShowing + 1
		if obstructorsShowing > 0 then
			Toast:PauseAndHide(.1)
		end
	end

	local function ObstructorOnHide()
		obstructorsShowing = obstructorsShowing - 1
		if obstructorsShowing < 1 then
			Toast:Play()
		end
	end

	-- Allow external access.
	function Toast:AddObstructor(frame)
		assert(C_Widget.IsFrameWidget(frame), 'ImmersionToast:AddObstructor(frame): invalid frame widget')
		frame:HookScript('OnShow', ObstructorOnShow)
		frame:HookScript('OnHide', ObstructorOnHide)

		obstructorsShowing = obstructorsShowing + (frame:IsVisible() and 1 or 0)
	end

	function Toast:IsObstructed()
		return obstructorsShowing > 0
	end

	-- Force base frame and TalkingHeadFrame.
	Toast:AddObstructor(ImmersionFrame)
	Toast:AddObstructor(LevelUpDisplay)
	if TalkingHeadFrame then
		Toast:AddObstructor(TalkingHeadFrame)
	else
		hooksecurefunc('TalkingHead_LoadUI', function() Toast:AddObstructor(TalkingHeadFrame) end)
	end
end