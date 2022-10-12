local _, L = ...
local Inspector = ImmersionFrame.Inspector

-- Synthetic OnLoad
do local self = Inspector
	-- add tables for column frames, used when drawing qItems as tooltips
	self.Choices.Columns = {}
	self.Extras.Columns = {}
	self.Active = {}

	self.parent = self:GetParent()
	self.ignoreRegions = true
	self:EnableMouse(true)

	-- set parent/strata on load main frame keeps table key, strata correctly draws over everything else.
	self:SetParent(UIParent)
	self:SetFrameStrata('FULLSCREEN_DIALOG')

	self.Items = {}
	self:SetScale(1.1)

	local r, g, b = GetClassColor(select(2, UnitClass('player')))
	local minColor = CreateColor(0, 0, 0, 0.75)
	local maxColor = CreateColor(r / 5, g / 5, b / 5, 0.75)

	self.Background:SetColorTexture(1, 1, 1)
	L.SetGradient(self.Background, 'VERTICAL', minColor, maxColor)

	self.tooltipFramePool = CreateFramePool('GameTooltip', self, 'ImmersionItemTooltipTemplate', function(self, obj) obj:Hide() end)
	self.tooltipFramePool.creationFunc = function(framePool)
		local index = #framePool.inactiveObjects + framePool.numActiveObjects + 1
		local tooltip = L.Create({
			type    = framePool.frameType,
			name    = 'GameTooltip',
			index   = index,
			parent  = framePool.parent,
			inherit = framePool.frameTemplate
		})
		L.SetBackdrop(tooltip.Hilite, L.Backdrops.TOOLTIP_HILITE)
		return tooltip
	end
end

function Inspector:OnShow()
	self.parent.TalkBox:Dim();
	self.tooltipFramePool:ReleaseAll();
	L.UIFrameFadeIn(self, 0.25, 0, 1)
end

function Inspector:OnHide()
	self.parent.TalkBox:Undim();
	self.tooltipFramePool:ReleaseAll();
	wipe(self.Active);

	-- Reset columns
	for _, column in ipairs(self.Choices.Columns) do
		column.lastItem = nil
		column:SetSize(1, 1)
		column:Hide()
	end
	for _, column in ipairs(self.Extras.Columns) do
		column.lastItem = nil
		column:SetSize(1, 1)
		column:Hide()
	end
end

function Inspector:OnUpdate(elapsed)
	self.timer = (self.timer or 0) + elapsed
	if self.timer > 0.1 then 
		self:AdjustToChildren()
		self.timer = 0
	end
end

Inspector:SetScript('OnShow', Inspector.OnShow)
Inspector:SetScript('OnHide', Inspector.OnHide)