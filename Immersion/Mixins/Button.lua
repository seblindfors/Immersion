local Button, _, L = {}, ...
L.ButtonMixin = Button

function Button:OnClick(button, down)
	local _type = self.type
	----------------------------------
	local call = ( _type == 'Available' and SelectGossipAvailableQuest ) or
				( _type == 'Active' and SelectGossipActiveQuest ) or
				( _type == 'ActiveQuest' and SelectActiveQuest ) or
				( _type == 'AvailableQuest' and SelectAvailableQuest ) or
				( SelectGossipOption )
	----------------------------------
	call(self:GetID())
	PlaySound('igQuestListSelect')
end

function Button:OnShow()
	self.Counter:SetShown(L('enablenumbers'))
 	local id = self.idx or 1
	C_Timer.After(id * 0.025, function()
		L.UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end)
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
	self.HighlightTexture = self:CreateTexture(nil, 'BORDER', nil, 7)
	self.HighlightTexture:SetTexture('Interface\\PVPFrame\\PvPMegaQueue')
	self.HighlightTexture:SetPoint('TOPLEFT', 0, -4)
	self.HighlightTexture:SetPoint('BOTTOMRIGHT', 0, 4)
	self.HighlightTexture:SetTexCoord(0.00195313, 0.63867188, 0.70703125, 0.76757813)
	self:SetHighlightTexture(self.HighlightTexture)
	----------------------------------
	self.Icon = self:CreateTexture('$parentGossipIcon', 'OVERLAY')
	self.Icon:SetSize(20, 20)
	self.Icon:SetPoint('LEFT', 16, 0)
	----------------------------------
	self.Label = self:CreateFontString(nil, 'ARTWORK', 'DialogButtonHighlightText')
	----------------------------------
	self.Label:SetJustifyH('LEFT')
	self.Label:SetPoint('TOPLEFT', 42, -16)
	self.Label:SetWidth(250)
	self:SetFontString(self.Label)
	----------------------------------
	self.Overlay = CreateFrame('Frame', nil, self)
	self.Overlay:SetAllPoints()
	self.Overlay:SetBackdrop(L.Backdrops.GOSSIP_NORMAL)
	----------------------------------
	self.Hilite = CreateFrame('Frame', nil, self)
	self.Hilite:SetAllPoints()
	self.Hilite:SetAlpha(0)
	self.Hilite:SetBackdrop(L.Backdrops.GOSSIP_HILITE)
	----------------------------------
	self.Counter = self:CreateFontString(nil, 'ARTWORK', 'GameTooltipTextSmall')
	self.Counter:SetText(id < 10 and id or '')
	self.Counter:SetPoint('LEFT', 8, 0)
	----------------------------------
	self:SetSize(310, 64)
	self:SetBackdrop(L.Backdrops.GOSSIP_BG)
	self:OnShow()
	----------------------------------
	self.Init = nil
end