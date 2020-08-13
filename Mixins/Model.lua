local Model, GetTime, API, _, L, ani, m2 = {}, GetTime, ImmersionAPI, ...
L.ModelMixin = Model

----------------------------------
-- Animation wrappers
----------------------------------
function Model:Read()  self:SetAnimation(self.ani.reading) end
function Model:Ask()   self:SetAnimation(self.ani.asking) end
function Model:Yell()  self:SetAnimation(self.ani.yelling) end
function Model:Talk()  self:SetAnimation(self.ani.talking) end
function Model:Reset() self:SetAnimation(0) end

function Model:RunNextAnimation() if
	self.reading then self:Read() elseif
	self.asking  then self:Ask() elseif
	self.yelling then self:Yell() elseif
	self.talking then self:Talk() else
	self:Reset() end 
end

function Model:SetAnimation(...)
	self.animation = ...
	self.animstart = GetTime()
	getmetatable(self).__index.SetAnimation(self, ...)
end

----------------------------------
-- Unit stuff
----------------------------------
function Model:IsPlayer() return self.unit == 'player' end
function Model:IsNPC()    return self.unit == 'npc' or self.unit == 'questnpc' end
function Model:IsEther()  return self.unit == 'ether' end
function Model:GetUnit()  return self.unit end

function Model:GetCreature()
	return self.creatureID or API:GetCreatureID(self.unit)
end

function Model:SetUnit(unit)
	self.unitDirty = unit
	if self:IsVisible() then
		self:ClearModel()
		self:MarkDefectModel(false)
		self:ApplyModelFromUnit(unit)
	end
end

function Model:MarkDefectModel(enabled)
	self.defectmodel = enabled
end

function Model:IsDefectModel()
	return self.defectmodel
end

function Model:ApplyModelFromUnit(unit)
	if self.file[unit] then
		self:SetModel(self.file[unit])
		self:SetCamDistanceScale(.4)
		self:SetPortraitZoom(0)
		self:SetPosition(0, 0, .25)
		self.unit = 'ether'
	else
		local mt = getmetatable(self).__index
		local creatureID = tonumber(unit) -- or API:GetCreatureID(unit)
		local apply = creatureID and mt.SetCreature or unit and mt.SetUnit
		self:SetCamDistanceScale(1)
		self:SetPortraitZoom(.85)
		self:SetPosition(0, 0, 0)
		if apply then
			apply(self, creatureID or unit)
			self.creatureID = creatureID
			self.unit = creatureID and 'npc' or unit
		end
	end
end

----------------------------------
-- Calculate state and remaining time
----------------------------------
function Model:SetRemainingTime(start, remaining)
	self.timestamp = start or GetTime()
	self.delay = remaining or 0
end

function Model:GetRemainingTime(start, remaining)
	if start and remaining then
		local time = GetTime()
		local diff = time - start
		-- shave off a second to avoid awkwardly long animation sequences
		if diff < ( remaining  - 1 ) then
			return time, diff
		end
	end
end

function Model:IsPrematureFinish(start)
	if start then
		local difference = GetTime() - start
		return difference < self.premature, difference
	end
end

function Model:PrepareAnimation(text, isEmote, isSequence)
	-- if no unit/text or if the text is a description rather than spoken words
	if ( not self.unit or not text ) or ( isEmote ) then
		for state in pairs(self.ani) do
			self[state] = nil
		end
	else
		self.reading = self.unit:match('player') and true
		if not self.reading then
			self.asking  = text:match('?')
			self.yelling = text:match('!')
			self.talking = true
		end
	end
end

function Model:RunSequence(remainingTime, isSequence)
	if self:IsNPC() then
		if not L('disableanisequence') then
			self:SetRemainingTime(GetTime(), remainingTime)
			if self.asking and not isSequence then
				self:Ask()
			elseif self.yelling then
				self:Randomize(self.ani.yelling)
			else
				self:Talk()
			end
		end
	elseif self:IsPlayer() then
		self:Read()
	end
end

function Model:Randomize(animation)
	local rand = random(2) == 2
	self:SetAnimation(rand and animation or self.ani.talking)
end

----------------------------------
-- Handler
----------------------------------
function Model:OnAnimFinished()
	if self:IsDefectModel() then return end
	-----------------------------------
	local isPremature, difference = self:IsPrematureFinish(self.animstart)
	if isPremature then
		self:MarkDefectModel(true)
		self:Reset()
		return
	end
	-----------------------------------
	if self:IsPlayer() then
		self:Read()
	else
		local newTime, difference = self:GetRemainingTime(self.timestamp, self.delay)
		if newTime and difference then
			self:SetRemainingTime(newTime, ( self.delay - 1) - difference)
			self.talking = true
			if self.asking then
				self:Ask()
			elseif self.yelling then
				self:Randomize(self.ani.yelling)
			else
				self:Talk()
			end
		else
			self:SetRemainingTime(nil, nil)
			self:PrepareAnimation(nil, nil)
			self:Reset()
		end
	end
end

function Model:OnShow()
	self:ClearModel()
	if self.unitDirty then
		self:MarkDefectModel(false)
		self:ApplyModelFromUnit(self.unitDirty)
	end
end


----------------------------------
-- Consts
----------------------------------
Model.ani = {
	reading = 520,
	asking  = 65,
	yelling = 64,
	talking = 60,
}

Model.file = {
	AvailableQuest	= 'interface\\buttons\\talktome.m2',
	ActiveQuest		= 'interface\\buttons\\talktomequestionmark.m2',
	IncompleteQuest = 'interface\\buttons\\talktomequestion_grey.m2',
	GossipGossip	= 'interface\\buttons\\talktome_chat.m2',
}

Model.LightValues = {
	true, 	-- enabled
	false, 	-- omni
	-250,	-- dirX
	0,		-- dirY
	0,		-- dirZ
	0.25,	-- dirIntensity
	1,		-- ambR
	1,		-- ambG
	1,		-- ambB
	75,		-- ambIntensity
	1,		-- dirR
	1,		-- dirG
	1,		-- dirB
}

Model.premature = 0.5