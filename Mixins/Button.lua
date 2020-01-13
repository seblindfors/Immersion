local Button, _, L = {}, ...
L.ButtonMixin = Button

function Button:OnClick()
	local func = self[self.type]
	if func then
		L.ClickedTitleCache = {text = self:GetText(); icon = self.Icon:GetTexture()}
		func(self)
		PlaySound(SOUNDKIT.IG_QUEST_LIST_SELECT)
	end
end

----------------------------------
function Button:ActiveQuest() SelectActiveQuest(self:GetID()) end
function Button:AvailableQuest() SelectAvailableQuest(self:GetID()) end
----------------------------------
function Button:Gossip() SelectGossipOption(self:GetID()) end
function Button:Active() SelectGossipActiveQuest(self:GetID()) end
function Button:Available() SelectGossipAvailableQuest(self:GetID()) end
----------------------------------

function Button:OnShow()
	self.Counter:SetShown(L('enablenumbers'))
 	local id = self.idx or 1
	C_Timer.After(id * 0.025, function()
		L.UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end)
end

function Button:OnDragStart(button)
	if not L('titlelock') then
		self.Container:SetClampedToScreen(true)
		self.Container:StartMoving()
	end
end

function Button:OnMouseWheel(delta)
	self.Container:SetClampedToScreen(false)
	self.Container:OnScroll(delta)
end

function Button:OnDragStop()
	if not L('titlelock') then
		self.Container:StopMoving()
	end
end

function Button:OnHide()
	self:SetAlpha(0)
end

function Button:OnScaleFinished()
	-- Force a text/height update after scaling
	self:SetText(self:GetText())
end

function Button:SetFormattedText(...)
	local __index = getmetatable(self).__index
	__index.SetFormattedText(self, ...)
	__index.SetHeight(self, self.Label:GetStringHeight() + 32)
end

function Button:SetText(...)
	local __index = getmetatable(self).__index
	__index.SetText(self, ...)
	__index.SetHeight(self, self.Label:GetStringHeight() + 32)
end

function Button:SetHeight(height, force)
	if force then
		getmetatable(self).__index.SetHeight(self, height)
	end
end

function Button:SetIcon(texture)
	self.Icon:SetVertexColor(1, 1, 1)
	self.Icon:SetTexture(texture)
end

function Button:SetGossipQuestIcon(texture, vertex)
	vertex = vertex or 1
	self.Icon:SetTexture(([[Interface\GossipFrame\%s]]):format(texture or ''))
	self.Icon:SetVertexColor(vertex, vertex, vertex)
end

function Button:SetGossipIcon(texture, vertex)
	vertex = vertex or 1
	self.Icon:SetTexture(([[Interface\GossipFrame\%sGossipIcon]]):format(texture or ''))
	self.Icon:SetVertexColor(vertex, vertex, vertex)
end

function Button:SetPriority(val)
	self.priority = val
end

function Button:ComparePriority(otherButton)
	if otherButton and (otherButton.priority or 5) < (self.priority or 5) then
		return otherButton
	end
	return self
end

function Button:Init(id)
	local parent = self:GetParent()
	local set = parent.Buttons
	self.Container = parent
	self.idx = id

	if id == 1 then
		self.anchor = {'TOP', parent, 'TOP', 0, 0}
	else
		self.anchor = {'TOP', set[id - 1], 'BOTTOM', 0, 0}
	end

	self:SetPoint(unpack(self.anchor))
	----------------------------------
	self.Counter:SetText(id < 10 and id or '')
	----------------------------------
	self:RegisterForDrag('LeftButton', 'RightButton')
	self:OnShow()
	----------------------------------
	self.Init = nil
end