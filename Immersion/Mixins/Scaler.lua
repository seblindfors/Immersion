local _, L = ...

L.ScalerMixin = {
	ScaleUpdate = function(self)
		local scale = self.targetScale
		local current = self:GetScale()
		local delta = scale > current and 0.025 or -0.025
		if abs(current - scale) < 0.05 then
			self:SetScale(scale)
			self:SetScript('OnUpdate', self.oldScript)
			if self.OnScaleFinished then
				self:OnScaleFinished()
			end
		else
			self:SetScale( current + delta )
		end
	end,
	ScaleTo = function(self, scale)
		local oldScript = self:GetScript('OnUpdate')
		self.targetScale = scale
		if oldScript and oldScript ~= self.ScaleUpdate then
			self.oldScript = oldScript
			self:HookScript('OnUpdate', self.ScaleUpdate)
		else
			self.oldScript = nil
			self:SetScript('OnUpdate', self.ScaleUpdate)
		end
	end,
	OnEnter = function(self)
		self:ScaleTo(self.enterScale or 1.1)
		if self.Hilite then
			L.UIFrameFadeIn(self.Hilite, 0.2, self.Hilite:GetAlpha(), 1)
		end
	end,
	OnLeave = function(self)
		self:ScaleTo(self.normalScale or 1)
		if self.Hilite then
			L.UIFrameFadeOut(self.Hilite, 0.2, self.Hilite:GetAlpha(), 0)
		end
	end,
	OnHide = function(self)
		self:SetScript('OnUpdate', nil)
		self:SetScale(self.normalScale or 1)
		if self.Hilite then
			self.Hilite:SetAlpha(0)
		end
	end,
}

L.AdjustToChildren = {		
	IterateChildren = function(self)
		local regions = {self:GetChildren()}
		if not self.ignoreRegions then
			for _, v in pairs({self:GetRegions()}) do
				regions[#regions + 1] = v
			end
		end
		return pairs(regions)
	end,
	GetAdjustableChildren = function(self)
		local adjustable = {}
		for _, child in self:IterateChildren() do
			if child.AdjustToChildren then
				adjustable[#adjustable + 1] = child
			end
		end
		return pairs(adjustable)
	end,
	AdjustToChildren = function(self)
		self:SetSize(1, 1)
		for _, child in self:GetAdjustableChildren() do
			child:AdjustToChildren()
		end
		local top, bottom, left, right
		for _, child in self:IterateChildren() do
			if child:IsShown() then
				local childTop, childBottom = child:GetTop(), child:GetBottom()
				local childLeft, childRight = child:GetLeft(), child:GetRight()
				if (childTop) and (not top or childTop > top) then
					top = childTop
				end
				if (childBottom) and (not bottom or childBottom < bottom) then
					bottom = childBottom
				end
				if (childLeft) and (not left or childLeft < left) then
					left = childLeft
				end
				if (childRight) and (not right or childRight > right) then
					right = childRight
				end
			end
		end
		if top and bottom then
			self:SetHeight(abs( top - bottom ))
		end
		if left and right then
			self:SetWidth(abs( right - left ))
		end
		return self:GetSize()
	end,
}