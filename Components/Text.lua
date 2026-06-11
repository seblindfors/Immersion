local _, L = ...
local Timer, GetTime = CreateFrame('Frame'), GetTime

-- Borrowed fixes from Storyline :)
local LINE_FEED_REPLACE, LINE_BREAK_REPLACE
do  local LINE_FEED, CARRIAGE_RETURN = string.char(10), string.char(13)
	LINE_FEED_REPLACE = LINE_FEED .. '+'
	LINE_BREAK_REPLACE = LINE_FEED .. CARRIAGE_RETURN .. LINE_FEED
end

   local TEXT_TIME_DIVISOR       -- set later as baseline divisor for (text length / time).
   local MAX_UNTIL_SPLIT   = 200 -- start recursive string splitting if the text is too long.

Timer.Texts = {}
L.TextMixin = {}

local Text = L.TextMixin

----------------------------------
-- Text: manage text input
----------------------------------
function Text:SetText(text)
	TEXT_TIME_DIVISOR = L('delaydivisor')
	self:PreparePlayback()
	self.storedText = text
	if text then
		local timeToFinish, strings, timers = self:CreateLineData(text)
		self.numTexts = #strings
		self.timeToFinish = timeToFinish
		self.timeStarted = GetTime()
		self:QueueTexts(strings, timers)
	end
end

function Text:ReplaceLinefeed(text)
	return text:gsub(LINE_FEED_REPLACE, '\n'):gsub(LINE_BREAK_REPLACE, '\n')
end

function Text:ReplaceNatural(str)
	local new = str -- substitute natural breaks with newline.
	:gsub('%.%s%.%s%.', '...') 		-- ponder special case
	:gsub('%.%s+', '.\n') 			-- sentence
	:gsub('%.%.%.\n', '...\n...') 	-- ponder
	:gsub('%!%s+', '!\n')			-- exclamation
	:gsub('%?%s+', '?\n') 			-- question
	return new, (new == str) -- return new string, and whether something changed
end

function Text:CreateLineData(text)
	text = self:ReplaceLinefeed(text)
	local timeToFinish, strings, timers = 0, {}, {}
	for _, paragraph in ipairs({strsplit('\n', text)}) do
		timeToFinish = timeToFinish + self:AddString(paragraph, strings, timers)
	end
	return timeToFinish, strings, timers
end

function Text:CalculateLineTime(length, nEndPunct, nMidPunct)
	-- Calcuate time to allow for reading text (and for TTS if enabled).
	-- For matching TTS, the linear calculation (constant divisor) sometimes resulted in too little time for short phrases (TTS clipped)
	-- and too much time for long phrases (seconds of dead air).  This now scales by an inverse logarithm of the phrase length,
	-- so more time is given for short phrases and relatively less time for longer phrases.
	-- The Text speed option, TEXT_TIME_DIVISOR, is still applied by changing the base of the logarithm to the TEXT_TIME_DIVISORth root of 30.
	-- It is calibrated for a phrase that is 30 characters long with a TEXT_TIME_DIVISOR = 15 to yield a time of 2 seconds.

	-- It also gives extra time if the phrase has a lot of punctuation, because TTS will typically pause briefly for each:
	--     half a second for each sentence-ending punctuation: period, exclamation point, or question mark
	--     quarter of a second for each mid-sentence punctuation: comma, colon, semi-colon.

	-- Protect against a length of 0, which causes math.log to fail, or 1, which causes math.log to return 0 and the division to fail
	local safeLength = math.max(2, length)

	-- If arguments are missing or nil, default them to 0
	nEndPunct = nEndPunct or 0
	nMidPunct = nMidPunct or 0

	-- Changed formula to give more time for shorter strings, which were getting clipped, and less time for longer strings, which often had seconds of dead air after them.
	-- return (safeLength /                                        (TEXT_TIME_DIVISOR or 15)   )                                          +   TEXT_TIME_PADDING
	   return (safeLength / (math.log(safeLength) / math.log(30^(1/(TEXT_TIME_DIVISOR or 15))))) + (0.5 * nEndPunct) + (0.25 * nMidPunct) + L.TEXT_TIME_PADDING
end

function Text:AddString(str, strings, timers)
	local length, timer, new, forceShow = str:len(), 0
	if length > MAX_UNTIL_SPLIT then
		new, forceShow = self:ReplaceNatural(str)
		--[[ If the string is unchanged, this will recurse infinitely, therefore
			force the long string to be shown. This safeguard is probably meaningless,
			as it requires 200+ chars without any punctuation. ]]
		if not forceShow then -- recursively split the altered string
			for _, sentence in ipairs({strsplit('\n', new)}) do
				timer = timer + self:AddString(sentence, strings, timers)
			end
			return timer
		end
	end
	if ( length ~= 0 or forceShow ) then
		-- Clean up the verbatim phrase for a more accurate reading calculation of TTS time
		-- Count punctuation so extra time can be allowed for TTS if there are a lot of short sentences vs one long, flowing sentence.
 		local cleanStr = str or ""

 		-- For debugging, print the original text to chat before processing
		-- print("|cff00ff00[Immersion Before]:|r " .. tostring(cleanStr))

		-- 1. Clean the string.
			-- a. Normalize the 3-byte ellipsis character to a standard period
			cleanStr = string.gsub(cleanStr, "…", ".")

			-- b. Remove all spaces that sit directly between ending punctuation
			local changed
			repeat
				cleanStr, changed = string.gsub(cleanStr, "([.!?])%s+([.!?])", "%1%2")
			until changed == 0

			-- c. Collapse any remaining sequence of 2 or more ending punctuation into just one
			cleanStr = string.gsub(cleanStr, "([.!?])[.!?]+", "%1")

			-- d. Strip ALL leading punctuation, symbols, and spaces: many phrases begin with ...
			cleanStr = string.gsub(cleanStr, "^[%p%s]+", "")

		-- 2. Count major sentence-ending punctuation (. ? !)
		local _, nEndPunct = string.gsub(cleanStr, "[.?!]", "")

		-- 3. Count minor pauses (, ; :)
		local _, nMidPunct = string.gsub(cleanStr, "[,;:]", "")

		-- For debuggin, print the cleaned text to chat after processing
		-- print("|cffff0000[Immersion After]:|r " .. tostring(cleanStr))

		-- Recount the length of the (cleaned) string.
		local length2 = strlenutf8(cleanStr) or 0

		timer = self:CalculateLineTime(length, nEndPunct, nMidPunct)
		timers[ #strings + 1] = timer
		strings[ #strings + 1 ] = str
	end
	return timer
end


----------------------------------
-- Text: playback
----------------------------------
function Text:QueueTexts(strings, timers)
	assert(strings, 'No strings added to object '.. ( self:GetName() or '<unnamed fontString>' ) )
	assert(timers, 'No timers added to object '.. ( self:GetName() or '<unnamed fontString>' ) )
	self.strings = strings
	self.timers = timers
	Timer:AddText(self)
end

function Text:ForceNext()
	if self:HasLineData() then
		local _, remainingLineTime = self:RemoveLine()
		self.timeToFinish = self.timeToFinish - remainingLineTime
		if self:HasLine() then
			self:SetToCurrentLine()
		else
			self:PauseTimer()
			self:RepeatTexts()
			self:FlagForceFinished(true)
		end
		if not self:HasFollowup() then
			self:OnFinished()
			self:FlagForceFinished(true)
		end
	end
end

function Text:SetToCurrentLine()
	self:DisplayLine(self:GetLine())
end

function Text:SetCurrentLineTime(time)
	self.currentLineTime = time or 0
end

function Text:UpdateCurrentLineTime(delta)
	self.timers[1] = self.timers[1] + delta
end

function Text:RepeatTexts()
	if self.storedText then
		self:SetText(self.storedText)
	end
end

function Text:OnFinished()
	self.strings = nil
	self.timers = nil
end

function Text:FlagForceFinished(state)
	self.forceFinished = state
end

function Text:IsForceFinishedFlagged()
	return self.forceFinished
end

function Text:PreparePlayback()
	self.numTexts = nil
	self:FlagForceFinished(false)
	self:PauseTimer()
	self:OnFinished()
	self:DisplayLine()
end

function Text:ResumeTimer()
	if self:HasLineData() then
		Timer:AddText(self)
		return true
	end
end

function Text:PauseTimer()
	Timer:RemoveText(self)
end

----------------------------------
-- Text: display
----------------------------------
function Text:DisplayLine(text, time)
	if not self:GetFont() then
		self:CheckApplicableFonts()
		self:SetFontObject(self.fontObjectsToTry[1])
	end

	getmetatable(self).__index.SetText(self, text)
	self:SetCurrentLineTime(time)
	self:ApplyFontObjects()

	-- Since TTS has a 3-second delay on the first phrase of the interaction, the time to display the text must be increased
	-- If this is the first displayed phrase of the interaction with the unit and TTS is enabled,
	-- add an extra 3 seconds to the line's timer so TTS has time to finish.
	if L.___ttsDelayedStart and L('ttsenabled') then
		-- add to remaining timer for the current line
		if self.timers and self.timers[1] then
			self.timers[1] = self.timers[1] + 3
		end
		-- also add to the original/current line time so progress calculations remain correct
		self.currentLineTime = (self.currentLineTime or 0) + 3
	end

	if self.OnDisplayLineCallback then
		self:OnDisplayLineCallback(text, time)
	end
end

function Text:SetFontObjectsToTry(...)
	self.fontObjectsToTry = { ... }
	if self:GetText() then
		self:ApplyFontObjects()
	end
end

-- Cache global security/sandboxing functions locally
local issecretvalue  = issecretvalue
local canaccessvalue = canaccessvalue

function Text:ApplyFontObjects()
	self:CheckApplicableFonts()

	for i, fontObject in ipairs(self.fontObjectsToTry) do
		self:SetFontObject(fontObject)

		-- Get truncation state
		local truncated = self:IsTruncated()

		-- If Blizzard returned a secret boolean, we cannot safely test it
		if issecretvalue and issecretvalue(truncated) and (not canaccessvalue or not canaccessvalue(truncated)) then
			-- Stop here; don't boolean-test a secret value
			break
		end
		-- Safe to test normally
		if not truncated then
			break
		end
	end
end

function Text:CheckApplicableFonts()
	if not self.fontObjectsToTry or not self.fontObjectsToTry[1] then
		error('No fonts applied to TextMixin, call SetFontObjectsToTry first')
	end
end

----------------------------------
-- Text: state getters
----------------------------------
function Text:GetTimeRemaining()
	if self.timeStarted and self.timeToFinish then
		local difference = ( self.timeStarted + self.timeToFinish ) - GetTime()
		return difference < 0 and 0 or difference
	end
	return 0
end

function Text:GetProgress()
	local full = self:GetNumTexts()
	local remaining = self:GetNumRemaining()
	return ('%d/%d'):format(full - remaining + 1, full)
end

function Text:GetProgressPercent()
	if self.timeStarted and self.timeToFinish then
		local progress = ( GetTime() - self.timeStarted ) / self.timeToFinish
		return ( progress > 1 ) and 1 or progress
	end
	return 1
end

function Text:GetCurrentProgress()
	local modifiedTime = self:GetModifiedTime()
	local fullTime = self:GetOriginalTime()
	if modifiedTime and fullTime and fullTime > 0 then
		return (1 - modifiedTime / fullTime)
	end
end

function Text:IsFinished() 		return not self.strings end
function Text:IsSequence() 		return self.numTexts and self.numTexts > 1 end
function Text:IsLineFinished() 	return self.timers[1] <= 0 end
function Text:GetNumTexts() 	return self.numTexts or 0 end
function Text:GetNumRemaining() return self.strings and #self.strings or 0 end

function Text:HasLineData() 	return self.strings and self.timers end
function Text:HasLine() 		return self.strings and self.strings[1] and true end
function Text:HasFollowup() 	return self.strings and self.strings[2] and true end

function Text:GetModifiedTime() return self.timers and self.timers[1] end
function Text:GetOriginalTime()	return self.currentLineTime or 0 end
function Text:GetLineProgress() return (self.timers and self.currentLineTime) and (self.timers[1]/self.currentLineTime) or 1 end

function Text:GetLine() 		return self.strings[1], self.timers[1] end
function Text:RemoveLine() 		return tremove(self.strings, 1), tremove(self.timers, 1) end

----------------------------------
-- Timer handle
----------------------------------
function Timer:AddText(fontString)
	if fontString then
		self.Texts[fontString] = true
		self:SetScript('OnUpdate', self.OnUpdate)
	end
end

function Timer:GetTexts()
	return pairs(self.Texts)
end

function Timer:RemoveText(fontString)
	if fontString then
		self.Texts[fontString] = nil
	end
end

function Timer:OnTextFinished(fontString)
	if fontString then
		self:RemoveText(fontString)
		if fontString.OnFinishedCallback then
			fontString:OnFinishedCallback()
		end
	end
end

function Timer:OnUpdate(elapsed)
	for text in self:GetTexts() do
		if text:HasLine() then
			-- if there's no text displayed, display the current line.
			if not text:GetText() then
				text:SetToCurrentLine()
			end
			-- deduct elapsed time since update from current timer
			text:UpdateCurrentLineTime(-elapsed)
			-- timer is below/equal to zero, move on to next line
			if text:IsLineFinished() then
				text:RemoveLine()
				-- check if there's another line waiting
				if text:HasLine() then
					text:SetToCurrentLine()
				else
					text:OnFinished()
				end
			end
		else
			self:OnTextFinished(text)
		end
	end
	if not next(self.Texts) then
		self:SetScript('OnUpdate', nil)
	end
end