local _, L = ...
local Button = {}
L.ButtonMixin = Button

function Button:OnClick(button, down)
	self.owner:Click()
end

function Button:Update(text)
	self:SetAlpha(0)
	C_Timer.After(0.05, function() 
		self:SetText(text)
		local textHeight = self.Label:GetStringHeight()
		self:SetHeight(textHeight + 32)
		self:SetIcon(self.ownerIcon:GetTexture())
		self:Animate()
		self.Container:UpdateActive(self)
	end)
end

function Button:Animate()
	local id = self:GetID() or 1
	C_Timer.After(id * 0.025, function()
		L.UIFrameFadeIn(self, 0.2, self:GetAlpha(), 1)
	end)
end

function Button:OnHide()
	self:SetAlpha(0)
end

function Button:SetOwner(owner)
	self.owner = owner
	hooksecurefunc(owner, 'SetText', function(_, text) self:Update(text) end)
	hooksecurefunc(owner, 'SetFormattedText', function(_, ...) self:Update(select(2, ...)) end)
	owner:HookScript('OnShow', function() self:Show() end)
	owner:HookScript('OnHide', function()
		self:SetText()
		self:SetScale(1)
		self:SetHeight(1)
		self:UnlockHighlight()
		self:OnLeave()
		self:Hide() 
		self.Container:UpdateActive(self)
	end)
end

function Button:SetIcon(texture)
	self.Icon:SetTexture(texture)
end

function Button:Init()
	local id = self:GetID()
	local parent = self:GetParent()
	local set = parent.Buttons[self.NPC]
	local owner = _G[self.NPC .. 'TitleButton' .. id]

	self.Container = parent
	self.ownerIcon = _G[ owner:GetName() .. self.NPC .. 'Icon']
	self:SetOwner(owner)
	set[id] = self

	if id == 1 then
		self.anchor = {'TOP', parent, 'TOP', 0, 0}
	else
		self.anchor = {'TOP', set[id - 1], 'BOTTOM', 0, 0}
	end

	self:SetPoint(unpack(self.anchor))
	self:Hide()

	self.Overlay = CreateFrame('Frame', '$parentOverlay', self)
	self.Hilite = CreateFrame('Frame', '$parentHilite', self)
	self.Label = self:CreateFontString('$parentLabel', 'ARTWORK', 'DialogButtonHighlightText')
	self.Icon = self:CreateTexture('$parentIcon', 'OVERLAY')
	self.HighlightTexture = self:CreateTexture('$parentHighlightTexture', 'BORDER', nil, 7)
	self.HighlightTexture:SetTexture('Interface\\PVPFrame\\PvPMegaQueue')
	self.HighlightTexture:SetPoint('TOPLEFT', 0, -4)
	self.HighlightTexture:SetPoint('BOTTOMRIGHT', 0, 4)
	self.HighlightTexture:SetTexCoord(0.00195313, 0.63867188, 0.70703125, 0.76757813)
	self:SetHighlightTexture(self.HighlightTexture)
	self.Icon:SetSize(20, 20)
	self.Icon:SetPoint('LEFT', 16, 0)
	self.Label:SetJustifyH('LEFT')
	self:SetFontString(self.Label)
	self.Overlay:SetAllPoints()
	self.Hilite:SetAllPoints()
	self.Hilite:SetAlpha(0)
	self.Label:SetPoint('TOPLEFT', 42, -16)
	self.Label:SetWidth(250)
	self:SetSize(310, 64)
	self.Overlay:SetBackdrop(L.Backdrops.GOSSIP_NORMAL)
	self.Hilite:SetBackdrop(L.Backdrops.GOSSIP_HILITE)
	self:SetBackdrop(L.Backdrops.GOSSIP_BG)
	self.Init = nil
end