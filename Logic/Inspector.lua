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

	self.tooltipFramePool = { count = 0, active = {}, inactive = {} };

	function self.tooltipFramePool:Acquire()
		local tooltip = next(self.inactive)
		if tooltip then
			self.inactive[tooltip] = nil
			self.active[tooltip] = true
			return tooltip
		end
		self.count = self.count + 1
		tooltip = L.Create({
			type    = 'GameTooltip',
			name    = 'GameTooltip',
			index   = self.count,
			parent  = Inspector,
			inherit = 'ImmersionItemTooltipTemplate'
		})
		L.SetBackdrop(tooltip.Hilite, L.Backdrops.TOOLTIP_HILITE)
		self.active[tooltip] = true
		return tooltip
	end

	function self.tooltipFramePool:ReleaseAll()
		for tooltip in pairs(self.active) do
			self.inactive[tooltip] = true
			tooltip:Hide()
		end
		wipe(self.active)
	end

	function self.tooltipFramePool:EnumerateActive()
		return pairs(self.active)
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