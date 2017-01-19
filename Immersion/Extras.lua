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

function L.GetListString(...)
	local ret = ''
	local strings = {...}
	local num = #strings
	for i, str in pairs(strings) do
		ret = ret .. '• ' .. str .. (i == num and '' or '\n')
	end
	return ret
end

function L.ValidateKey(key)
	return ( key and ( not key:lower():match('button') ) ) and key
end

----------------------------------
-- Default config
----------------------------------

L.cfg = {
	titlescale = 1,
	titleoffset = -500,
	boxscale = 1.1,
	boxoffset = 150,
	accept = 'SPACE',
	reset = 'BACKSPACE',
}

L.options = {
	type = 'group',
	args = {
		keybindings = {
			type = 'group',
			name = KEY_BINDINGS,
			args = {
				accept = {
					type = 'keybinding',
					name = ACCEPT,
					desc = L.GetListString(ACCEPT, NEXT, CONTINUE, COMPLETE_QUEST, GOODBYE),
					get = function() return L.cfg and L.cfg.accept end,
					set = function(self, val) L.cfg.accept = L.ValidateKey(val) end,
				},
				reset = {
					type = 'keybinding',
					name = RESET,
					get = function() return L.cfg and L.cfg.reset end,
					set = function(self, val) L.cfg.reset = L.ValidateKey(val) end,
				},
				goodbye = {
					type = 'keybinding',
					name = GOODBYE .. '/' .. CLOSE .. ' (' .. KEY_ESCAPE .. ')',
					desc = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS),
					get = function() return L.cfg and L.cfg.goodbye end,
					set = function(self, val) L.cfg.goodbye = L.ValidateKey(val) end,
				},
				ignore = {
					type = 'keybinding',
					name = IGNORE .. '/' .. UNIGNORE_QUEST,
					desc = L.GetListString(QUESTS_LABEL, IGNORE_QUEST, UNIGNORE_QUEST),
					get = function() return L.cfg and L.cfg.ignore end,
					set = function(self, val) L.cfg.ignore = L.ValidateKey(val) end,
				},
				number = {
					type = 'toggle',
					name = '[1-9] ' .. PET_BATTLE_SELECT_AN_ACTION,
					desc = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS),
					get = function() return L.cfg and L.cfg.enablenumbers end,
					set = function(self, val) L.cfg.enablenumbers = val end,
				},
			},
		},
		scales = {
			type = 'group',
			name = UI_SCALE,
			args = {
				global = {
					type = 'range',
					name = 'Global scale',
					min = 0.5,
					max = 1.5,
					get = function() return L.cfg and L.cfg.scale or 1 end,
					set = function(self, val) 
						L.cfg.scale = val
						L.frame:SetScale(val)
					end,
				},
				titles = {
					type = 'group',
					name = QUESTS_LABEL .. ' / ' .. GOSSIP_OPTIONS,
					args = {
						titlescale = {
							type = 'range',
							name = 'Scale',
							min = 0.5,
							max = 1.5,
							get = function() return L.cfg and L.cfg.titlescale or 1 end,
							set = function(self, val) 
								L.cfg.titlescale = val
								L.frame.TitleButtons:SetScale(val)
							end,
						},
						titleoffset = {
							type = 'range',
							name = 'Offset from center',
							min = -10,
							max = 10,
							get = function() return ( L.cfg and L.cfg.titleoffset or -500 ) / 100 end,
							set = function(self, val)
								print(val * 100)
								L.cfg.titleoffset = val * 100
								L.frame.TitleButtons:SetPoint('CENTER', UIParent, 'CENTER', val * 100, 0)
							end,
						},
					},
				},
				box = {
					type = 'group',
					name = MODEL,
					args = {
						boxscale = {
							type = 'range',
							name = 'Scale',
							min = 0.5,
							max = 1.5,
							get = function() return L.cfg and L.cfg.boxscale or 1.1 end,
							set = function(self, val) 
								L.cfg.boxscale = val
								L.frame.TalkBox:SetScale(val)
							end,
						},
						boxoffset = {
							type = 'range',
							name = 'Offset from bottom',
							min = 0,
							max = 300,
							get = function() return ( L.cfg and L.cfg.boxoffset or 150 ) end,
							set = function(self, val)
								L.cfg.boxoffset = val
								local talkbox = L.frame.TalkBox
								if not (TalkingHeadFrame and TalkingHeadFrame:IsVisible()) then
									talkbox:SetOffset(val)
								end
							end,
						},
					},
				},
			},
		},
	},
}


----------------------------------
-- Shared media / mixins
----------------------------------
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
}
----------------------------------