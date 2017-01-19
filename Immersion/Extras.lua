local _, L = ...
local PT = 'Interface\\AddOns\\' .. _ .. "\\Textures\\" 

function L.MixinNormal(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...)
		for k, v in pairs(mixin) do
			object[k] = v
		end
	end

	return object
end

function L.Mixin(t, ...)
	t = L.MixinNormal(t, ...)
	if t.HasScript then
		for k, v in pairs(t) do
			if t:HasScript(k) then
				if t:GetScript(k) then
					t:HookScript(k, v)
				else
					t:SetScript(k, v)
				end
			end
		end
	end
end

function L.HideFrame(frame)
	frame:SetSize(0, 0)
	frame:EnableMouse(false)
	frame:EnableKeyboard(false)
	frame:SetAlpha(0)
	frame:ClearAllPoints()
end

L.Backdrops = {
	GOSSIP_BG = {
		bgFile = PT..'Backdrop_Gossip.blp',
		edgeFile = PT..'Edge_Gossip_BG.blp',
		edgeSize = 8,
		insets = {left = 2, right = 2, top = 8, bottom = 8}
	},
	GOSSIP_NORMAL = {
		edgeFile = PT..'Edge_Gossip_Normal.blp',
		edgeSize = 8,
		insets = {left = 5, right = 5, top = -10, bottom = 7}
	},
	GOSSIP_HILITE = {
		edgeFile = PT..'Edge_Gossip_Hilite.blp',
		edgeSize = 8,
		insets = {left = 5, right = 5, top = 5, bottom = 6}
	},
	TALKBOX = {
		bgFile = PT..'Backdrop_Talkbox.blp',
		edgeFile = PT..'Edge_Talkbox_BG.blp',
		edgeSize = 32,
		insets = { left = 32, right = 32, top = 32, bottom = 32 }
	},
	TOOLTIP_BG = {
		bgFile = PT..'Backdrop_Talkbox.blp',
		edgeFile = PT..'Edge_Talkbox_BG.blp',
		edgeSize = 8,
		insets = { left = 8, right = 8, top = 8, bottom = 8 }
	},
}

L.Mixins = {
----------------------------------
	ScaleOnFocus = {
		ScaleUpdate = function(self)
			local scale = self.targetScale
			local current = self:GetScale()
			local delta = scale > current and 0.025 or -0.025
			if abs(current - scale) < 0.05 then
				self:SetScale(scale)
				self:SetScript('OnUpdate', self.oldScript)
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
				L.UIFrameFadeIn(self.Hilite, 0.35, self.Hilite:GetAlpha(), 1)
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
	},
	AdjustToChildren = {
		IterateChildren = function(self)
			return pairs({self:GetChildren()})
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
			for _, child in self:GetAdjustableChildren() do
				child:AdjustToChildren()
			end
			local top, bottom, left, right
			for _, child in self:IterateChildren() do
				if child:IsVisible() then
					local childTop, childBottom = child:GetTop(), child:GetBottom()
					local childLeft, childRight = child:GetLeft(), child:GetRight()
					if not top or childTop > top then
						top = childTop
					end
					if not bottom or childBottom < bottom then
						bottom = childBottom
					end
					if not left or childLeft < left then
						left = childLeft
					end
					if not right or childRight > right then
						right = childRight
					end
				end
			end
			if top and bottom then
				self:SetHeight(abs( top - bottom ))
			else
				self:SetHeight(1)
			end
			if left and right then
				self:SetWidth(abs( right - left ))
			else
				self:SetWidth(1)
			end
		end,
	},
}
----------------------------------