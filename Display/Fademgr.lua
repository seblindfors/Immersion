local _, L = ...
local frame = _G[ _ .. 'Frame' ]
----------------------------------
-- Animations to play on show
----------------------------------
local __inAnims = {
	frame.TalkBox.MainFrame.InAnim,
	frame.TalkBox.NameFrame.FadeIn,
--	frame.TalkBox.TextFrame.FadeIn,
	frame.TalkBox.PortraitFrame.FadeIn,
}

local function PlayInAnimations(self, playAnimations)
	if playAnimations and ( self.timeStamp ~= GetTime() ) then
		for _, animation in ipairs(__inAnims) do
			animation:Play()
		end
	end
end

----------------------------------
-- Fade manager
----------------------------------
local __cacheAlphaIgnored = {}
local __staticAlphaIgnored = {
	[AlertFrame]		= true,
	[DressUpFrame]		= true,
--	[LevelUpDisplay] 	= true,
	[StaticPopup1] 		= true,
	[StaticPopup2] 		= true,
	[StaticPopup3] 		= true,
	[StaticPopup4] 		= true,
	[SubZoneTextFrame] 	= true,
	[ShoppingTooltip1] 	= true,
	[ShoppingTooltip2] 	= true,
}
local __staticHideFrames = {
	[MinimapCluster] = true,
}

if LevelUpDisplay then
	__staticAlphaIgnored[LevelUpDisplay] = true
end

----------------------------------
local FadeIn, FadeOut = L.UIFrameFadeIn, L.UIFrameFadeOut
----------------------------------

-- For config to cache certain frames for fade ignore/force.
function L.ToggleIgnoreFrame(frame, ignore)
	if frame then
		__cacheAlphaIgnored[frame] = ignore
		frame:SetIgnoreParentAlpha(ignore)
	end
end

-- Return a list of all frames to ignore and their current
-- setting towards ignoring UIParent's alpha value.
local function GetFramesToIgnore()
	local frames = {}
	-- Store ignore state so it can be reset on release.
	for frame in pairs(__staticAlphaIgnored) do
		frames[frame] = frame:IsIgnoringParentAlpha()
	end
	-- Union with cache.
	for frame, shouldIgnore in pairs(__cacheAlphaIgnored) do
		if shouldIgnore then
			frames[frame] = frame:IsIgnoringParentAlpha()
		end
	end
	return frames
end

-- Restore the temporary changes on release.
local function RestoreFadedFrames(self)
	FadeIn(UIParent, 0.5, UIParent:GetAlpha(), 1)

	local framesToIgnore = self.ignoredFadeFrames
	if framesToIgnore then
		for frame, ignoreParentAlpha in pairs(framesToIgnore) do
			frame:SetIgnoreParentAlpha(ignoreParentAlpha)
		end
		for frame in pairs(__staticHideFrames) do
			if not __cacheAlphaIgnored[frame] then
				FadeIn(frame, 0.5, frame:GetAlpha(), 1)
				frame:Show()
			end
		end
		self.ignoredFadeFrames = nil
	end
end

----------------------------------
-- Exposed to logic layer
----------------------------------
function frame:FadeIn(fadeTime, playAnimations, ignoreFrameFade)
	fadeTime = fadeTime or 0.2

	self.fadeState = 'in'
	FadeIn(self, fadeTime, self:GetAlpha(), 1)
	PlayInAnimations(self, playAnimations)

	if not ignoreFrameFade and L('hideui') and not self.ignoredFadeFrames then
		local framesToIgnore = GetFramesToIgnore()

		-- Fade out UIParent
		FadeOut(UIParent, fadeTime, UIParent:GetAlpha(), 0)

		-- Hide frames explicitly 
		for frame in pairs(__staticHideFrames) do
			if not __cacheAlphaIgnored[frame] then
				FadeOut(frame, fadeTime, frame:GetAlpha(), 0, {
					finishedFunc = frame.Hide;
					finishedArg1 = frame;
				})
			end
		end

		-- Set ignored frames to override the alpha change
		for frame in pairs(framesToIgnore) do
			frame:SetIgnoreParentAlpha(true)
		end

		self.ignoredFadeFrames = framesToIgnore
	end
end

function frame:FadeOut(fadeTime, ignoreOnTheFly)
	if ( self.fadeState ~= 'out' ) then
		FadeOut(self, fadeTime or 1, self:GetAlpha(), 0, {
			finishedFunc = self.Hide;
			finishedArg1 = self;
		})
		self.fadeState = 'out'
	end
	RestoreFadedFrames(self)
end

----------------------------------
-- Handle GameTooltip special case
----------------------------------
-- If the option to hide UI and to hide tooltip are ticked,
-- user still needs to see the tooltip on an item or reward.
do 	local function GameTooltipAlphaHandler(self)
		if L('hideui') then
			if L('hidetooltip') then
				self:SetIgnoreParentAlpha(not self:IsOwned(UIParent))
			else
				self:SetIgnoreParentAlpha(true)
			end
		end
	end

	GameTooltip:HookScript('OnTooltipSetDefaultAnchor', GameTooltipAlphaHandler)
	GameTooltip:HookScript('OnTooltipSetItem', GameTooltipAlphaHandler)
	GameTooltip:HookScript('OnShow', GameTooltipAlphaHandler)
end