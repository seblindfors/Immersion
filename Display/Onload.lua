local _, L = ...
local frame = _G[ _ .. 'Frame' ]
local talkbox = frame.TalkBox
local titles = frame.TitleButtons
local inspector = frame.Inspector
local elements = talkbox.Elements
local _Mixin = L.Mixin
L.frame = frame

----------------------------------
-- Prepare propagation, so that we
-- can catch certain key strokes
-- but propagate the event otherwise.
----------------------------------
frame:SetPropagateKeyboardInput(true)

----------------------------------
-- In the case of hide UI option,
-- frames needs to ignore the
-- alpha change of UIParent.
----------------------------------
frame:SetIgnoreParentAlpha(true)
inspector:SetIgnoreParentAlpha(true)

----------------------------------
-- Register events for main frame
----------------------------------
for _, event in pairs({
	'ADDON_LOADED',
--	'ITEM_TEXT_BEGIN', 	-- Starting to read a book
--	'ITEM_TEXT_READY', 	-- New book text is ready
--	'ITEM_TEXT_CLOSED', -- Stop reading a book
	'GOSSIP_CLOSED',	-- Close gossip frame
	'GOSSIP_SHOW',		-- Show gossip options, can be a mix of gossip/quests
	'QUEST_ACCEPTED', 	-- Use this event for on-the-fly quest text tracking.
	'QUEST_COMPLETE',	-- Quest completed
	'QUEST_DETAIL',		-- Quest details/objectives/accept frame
	'QUEST_FINISHED',	-- Fires when quest frame is closed
	'QUEST_GREETING',	-- Multiple quests to choose from, but no gossip options
--	'QUEST_IGNORED',	-- Ignore the currently shown quest
	'QUEST_PROGRESS',	-- Fires when you click on a quest you're currently on
	'QUEST_ITEM_UPDATE', -- Item update while in convo, refresh frames.
--	'MERCHANT_SHOW', 	-- Force close gossip on merchant interaction.
	'NAME_PLATE_UNIT_ADDED', 	-- For nameplate mode
	'NAME_PLATE_UNIT_REMOVED', 	-- For nameplate mode
	'SUPER_TRACKED_QUEST_CHANGED',
}) do frame:RegisterEvent(event) end


frame.IgnoreResetEvent = {
	QUEST_ACCEPTED = true,
	NAME_PLATE_UNIT_ADDED = true,
	NAME_PLATE_UNIT_REMOVED = true,
	SUPER_TRACKED_QUEST_CHANGED = true,
}

frame.IgnoreGossipEvent = {
	GOSSIP_SHOW = true,
	GOSSIP_CLOSED = true,
	QUEST_ACCEPTED = true,
	NAME_PLATE_UNIT_ADDED = true,
	NAME_PLATE_UNIT_REMOVED = true,
	SUPER_TRACKED_QUEST_CHANGED = true,
}

----------------------------------
-- Register events for titlebuttons
----------------------------------
for _, event in pairs({
	'GOSSIP_CLOSED',	-- Hide buttons
	'GOSSIP_SHOW',		-- Show gossip options, can be a mix of gossip/quests
	'QUEST_COMPLETE',	-- Hide when going from gossip -> complete
	'QUEST_DETAIL',		-- Hide when going from gossip -> detail
	'QUEST_FINISHED',	-- Hide when going from gossip -> finished 
	'QUEST_GREETING',	-- Show quest options, why is this a thing again?
--	'QUEST_IGNORED',	-- Hide when using ignore binding?
	'QUEST_PROGRESS',	-- Hide when going from gossip -> active quest
--	'QUEST_LOG_UPDATE',	-- If quest changes while interacting
}) do titles:RegisterEvent(event) end

titles:RegisterUnitEvent('UNIT_QUEST_LOG_CHANGED', 'player')



----------------------------------
-- Load SavedVaribles, config and compat
----------------------------------
function frame:ADDON_LOADED(name)
	if name == _ then
		local svref = _ .. 'Setup'
		L.cfg = _G[svref] or L.GetDefaultConfig()
		_G[svref] = L.cfg

		-- Set module scales
		talkbox:SetScale(L('boxscale'))
		titles:SetScale(L('titlescale'))
		elements:SetScale(L('elementscale'))
		self:SetScale(L('scale'))

		-- Set the module points
		talkbox:SetPoint(L('boxpoint'), UIParent, L('boxoffsetX'), L('boxoffsetY'))
		titles:SetPoint('CENTER', UIParent, 'CENTER', L('titleoffset'), L('titleoffsetY'))

		self:SetFrameStrata(L('strata'))
		talkbox:SetFrameStrata(L('strata'))

		-- If previous version and flyins were disabled, set anidivisor to instant
		if L.cfg.disableflyin then
			L.cfg.disableflyin = nil
			L.cfg.anidivisor = 1
		end

		-- Hide portrait 
		talkbox.PortraitFrame:SetShown(not L('disableportrait'))
		talkbox.MainFrame.Model.PortraitBG:SetShown(not L('disableportrait'))

		-- Show solid background
		talkbox.BackgroundFrame.SolidBackground:SetShown(L('solidbackground'))
		elements:SetBackdrop(L('solidbackground') and L.Backdrops.TALKBOX_SOLID or L.Backdrops.TALKBOX)

		-- Set frame ignore for hideUI features on load.
		L.ToggleIgnoreFrame(Minimap, not L('hideminimap'))
		L.ToggleIgnoreFrame(MinimapCluster, not L('hideminimap'))
		L.ToggleIgnoreFrame(ObjectiveTrackerFrame, not L('hidetracker'))

		-- Register options table
		LibStub('AceConfigRegistry-3.0'):RegisterOptionsTable(_, L.options)
		L.config = LibStub('AceConfigDialog-3.0'):AddToBlizOptions(_)

		-- Slash handler
		_G['SLASH_' .. _:upper() .. '1'] = '/' .. _:lower()
		SlashCmdList[_:upper()] = function() LibStub('AceConfigDialog-3.0'):Open(_) end

		-- Add some sexiness to the config frame.
		local logo = CreateFrame('Frame', nil, L.config)
		logo:SetFrameLevel(4)
		logo:SetSize(64, 64)
		logo:SetPoint('TOPRIGHT', 8, 24)
		logo:SetBackdrop({bgFile = ('Interface\\AddOns\\%s\\Textures\\Logo'):format(_)})
		L.config.logo = logo

		-- Run functions for compatibility with other addons on load.
		-- If the addon in question is already loaded, run the function and remove from list.
		for addOn, func in pairs(L.compat) do
			-- denotes if existing and loadable at any point
			if select(4, GetAddOnInfo(addOn)) then
				-- is it actually loaded at this point?
				if IsAddOnLoaded(addOn) then
					func(self)
					L.compat[addOn] = nil
				end
			else -- the addon is not going to load, remove it from table.
				L.compat[addOn] = nil
			end
		end
	-- If the compatibile addon loads after Immersion, run the function and remove from list.
	elseif L.compat and L.compat[name] then
		L.compat[name](self)
		L.compat[name] = nil
	end

	-- The L.compat table is empty -> all addons are loaded, disabled or missing.
	-- Garbage collect the table. 
	if not next(L.compat) then
		L.compat = nil
	end

	-- Immersion is loaded, no more addons to track. Garbage collect this function.
	if not L.compat and IsAddOnLoaded(_) then
		self:UnregisterEvent('ADDON_LOADED')
		self.ADDON_LOADED = nil
	end
end

----------------------------------
-- Hide regular frames
----------------------------------
L.HideFrame(GossipFrame)
L.HideFrame(QuestFrame)
--L.HideFrame(ItemTextFrame)
----------------------------------

----------------------------------
-- Set backdrops on elements
----------------------------------
talkbox.Hilite:SetBackdrop(L.Backdrops.GOSSIP_HILITE)

----------------------------------
-- Initiate titlebuttons
----------------------------------
_Mixin(titles, L.TitlesMixin)

----------------------------------
-- Initiate elements
----------------------------------
_Mixin(elements, L.ElementsMixin)

----------------------------------
-- Set up dynamically sized frames
----------------------------------
do
	local AdjustToChildren = L.AdjustToChildren
	_Mixin(elements, AdjustToChildren)
	_Mixin(elements.Content, AdjustToChildren)
	_Mixin(elements.Progress, AdjustToChildren)
	_Mixin(elements.Content.RewardsFrame, AdjustToChildren)
	_Mixin(inspector, AdjustToChildren)
	_Mixin(inspector.Extras, AdjustToChildren)
	_Mixin(inspector.Choices, AdjustToChildren)
end

----------------------------------
-- Set point since the relative
-- region didn't exist on load.
----------------------------------
local name = talkbox.NameFrame.Name
name:SetPoint('TOPLEFT', talkbox.PortraitFrame.Portrait, 'TOPRIGHT', 2, -19)

----------------------------------
-- Model script, light
----------------------------------
local model = talkbox.MainFrame.Model
model:SetLight(unpack(L.ModelMixin.LightValues))
_Mixin(model, L.ModelMixin)

----------------------------------
-- Main text things
----------------------------------
local text = talkbox.TextFrame.Text
Mixin(text, L.TextMixin) -- see Mixins\Text.lua
-- Set array of fonts so the fontstring can be as big as possible without truncating the text
text:SetFontObjectsToTry(SystemFont_Shadow_Large, SystemFont_Shadow_Med2, SystemFont_Shadow_Med1)

-- Run a 'talk' animation on the portrait model whenever a new text is set
function text:OnDisplayLineCallback(text)
	local counter = talkbox.TextFrame.SpeechProgress
	talkbox.TextFrame.FadeIn:Stop()
	talkbox.TextFrame.FadeIn:Play()
	if text then
		model:PrepareAnimation(model:GetUnit(), text)
		if model:IsNPC() then
			-- Suggests that this phrase is an emote description
			if text:match('%b<>') then
				self:SetVertexColor(1, 0.5, 0)
			else
				self:SetVertexColor(1, 1, 1)
				if not L('disableanisequence') then
					model:SetRemainingTime(GetTime(), self:GetModifiedTime())
					if model.asking and not self:IsSequence() then
						model:Ask()
					else
						local yell = model.yelling and random(2) == 2
						if yell then model:Yell() else model:Talk() end
					end
				end
			end
		elseif model:IsPlayer() then
			model:Read()
		end
	end
	
	counter:Hide()
	if self:IsSequence() then
		if not self:IsFinished() then
			counter:Show()
			counter:SetText(self:GetProgress())
		end

		if self:GetNumRemaining() <= 1 then
			frame:AddHint('SQUARE', RESET)
		else
			frame:AddHint('SQUARE', NEXT)
		end
	else
		frame:RemoveHint('SQUARE')
	end

	if self:IsVisible() then
		if L('disableprogression') then
			self:PauseTimer()
		end
	end
end

function text:OnFinishedCallback()
	-- remove the last playback line, because the text played until completion.
	if ( L('onthefly') or L('supertracked') ) and not self:IsForceFinishedFlagged() then
		frame:RemoveToastByText(self.storedText)
	end
end

----------------------------------
-- Misc fixes
----------------------------------
talkbox:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
talkbox:RegisterForDrag('LeftButton')
talkbox.TextFrame.SpeechProgress:SetFont('Fonts\\MORPHEUS.ttf', 16, '')

----------------------------------
-- Set movable frames
----------------------------------
talkbox:SetMovable(true)
talkbox:SetUserPlaced(false)
talkbox:SetClampedToScreen(true)

titles:SetMovable(true)
titles:SetUserPlaced(false)

--------------------------------
-- Anchor the real talking head to the fake talking head,
-- make it appear IN PLACE of the fake one if the fake one isn't shown.
--------------------------------
do 
	local function HookTalkingHead()
		-- use this as assertion. if something else beat Immersion to it and manipulated the frame,
		-- it shouldn't be moved, even if enabled by user. in essence, dummy protection.
		if UIPARENT_MANAGED_FRAME_POSITIONS.TalkingHeadFrame then
			local managedFramePos = UIPARENT_MANAGED_FRAME_POSITIONS.TalkingHeadFrame
			local alertFrameIndex, alertFrameSettings
			local isTalkingHeadMoved, isDragging

			local function Drag(self)
				if isTalkingHeadMoved and L('movetalkinghead') then
					isDragging = true
					talkbox:OnDragStart()
				end
			end

			local function Drop(self)
				if isDragging then
					isDragging = nil
					talkbox:OnDragStop()
				end
			end

			local function Move(self)
				-- if the move is allowed
				if L('movetalkinghead') then
					self:ClearAllPoints(self)
					self:RegisterForDrag('LeftButton')
					
					if not isTalkingHeadMoved then
						-- Need this to keep it from resetting position
						self.ignoreFramePositionManager = true
						UIPARENT_MANAGED_FRAME_POSITIONS.TalkingHeadFrame = nil

						-- Flag for reset
						isTalkingHeadMoved = true

						-- Remove from alert system, preventing other frames from anchoring to it.
						for index, alertFrameSubSystem in ipairs(AlertFrame.alertFrameSubSystems) do
							if alertFrameSubSystem.anchorFrame and alertFrameSubSystem.anchorFrame == TalkingHeadFrame then
								alertFrameIndex = index
								alertFrameSettings = table.remove(AlertFrame.alertFrameSubSystems, index)
							end
						end
					end

					-- Move the frame
					if not talkbox:IsVisible() then
						talkbox:SetOffset() -- force update; (1) reset the offset calculation
						talkbox:SetExtraOffset(0) -- (2) make sure it isn't offset by elements from prior quest
						self:SetPoint('BOTTOM', talkbox, 'BOTTOM', 0, 0)
					else
						self:SetPoint('BOTTOM', talkbox, 'TOP', 0, 0)
					end

				-- if the setting is toggled off and the frame was manipulated, reset.
				elseif isTalkingHeadMoved then
					UIPARENT_MANAGED_FRAME_POSITIONS.TalkingHeadFrame = managedFramePos
					self.ignoreFramePositionManager = nil
					self:RegisterForDrag(nil)
					isTalkingHeadMoved = nil
					-- Reinsert the table into the alert system, if it existed.
					if alertFrameIndex and alertFrameSettings then
						table.insert(AlertFrame.alertFrameSubSystems, alertFrameIndex, alertFrameSettings)
						alertFrameIndex = nil
						alertFrameSettings = nil
					end
				end
			end

			TalkingHeadFrame:HookScript('OnShow', Move)
			TalkingHeadFrame:HookScript('OnHide', Drop)
			TalkingHeadFrame:HookScript('OnDragStart', Drag)
			TalkingHeadFrame:HookScript('OnDragStop', Drop)
			talkbox:HookScript('OnShow', function() Move(TalkingHeadFrame) end)
			talkbox:HookScript('OnHide', function() Move(TalkingHeadFrame) end)
		end
	end

	-- Run the init if the frame already exists (force loaded)
	if TalkingHeadFrame then
		HookTalkingHead()
	elseif TalkingHead_LoadUI then -- Hook to the loading function.
		hooksecurefunc('TalkingHead_LoadUI', HookTalkingHead)
	end
end


-- Azerite Empowered Item UI
do
	local loaded = false
	local function ignoreAzeriteItemUI()
		if not loaded and IsAddOnLoaded('Blizzard_AzeriteUI') then
			loaded = true
			L.ToggleIgnoreFrame(AzeriteEmpoweredItemUI, true)
		end
	end
	if OpenAzeriteEmpoweredItemUIFromItemLocation and OpenAzeriteEmpoweredItemUIFromLink then
		hooksecurefunc('OpenAzeriteEmpoweredItemUIFromItemLocation', ignoreAzeriteItemUI)
		hooksecurefunc('OpenAzeriteEmpoweredItemUIFromLink', ignoreAzeriteItemUI)
	end
end