local _, L = ...

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

function L.GetDefaultConfig()
	local t = {}
	for k, v in pairs(L.defaults) do
		t[k] = v
	end
	return t
end

function L.Get(val)
	return ( L.cfg and L.cfg[val] or L.defaults[val] )
end

function L.GetFromSV(tbl)
	local id = tbl[#tbl]
	return ( L.cfg and L.cfg[id])
end

function L.GetFromDefaultOrSV(tbl)
	local id = tbl[#tbl]
	return ( L.cfg and L.cfg[id]) or L.defaults[id]
end


----------------------------------
-- Default config
----------------------------------

L.defaults = {
----------------------------------
	scale = 1,

	titlescale = 1,
	titleoffset = -500,

	boxscale = 1,
	boxoffsetX = 0,
	boxoffsetY = 150,
	boxpoint = 'Bottom',

	accept = 'SPACE',
	reset = 'BACKSPACE',
}---------------------------------

local anchors = {
	Top = 'Top',
	Bottom = 'Bottom',
	Right = 'Right',
	Left = 'Left',
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
					get = L.GetFromSV,
					set = function(_, val) L.cfg.accept = L.ValidateKey(val) end,
				},
				reset = {
					type = 'keybinding',
					name = RESET,
					get = L.GetFromSV,
					set = function(_, val) L.cfg.reset = L.ValidateKey(val) end,
				},
				goodbye = {
					type = 'keybinding',
					name = GOODBYE .. '/' .. CLOSE .. ' (' .. KEY_ESCAPE .. ')',
					desc = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.goodbye = L.ValidateKey(val) end,
				},
				ignore = {
					type = 'keybinding',
					name = IGNORE .. '/' .. UNIGNORE_QUEST,
					desc = L.GetListString(QUESTS_LABEL, IGNORE_QUEST, UNIGNORE_QUEST),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.ignore = L.ValidateKey(val) end,
				},
				number = {
					type = 'toggle',
					name = '[1-9] ' .. PET_BATTLE_SELECT_AN_ACTION, -- lol
					desc = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.enablenumbers = val end,
				},
			},
		},
		settings = {
			type = 'group',
			name = SETTINGS,
			args = {
				scale = {
					type = 'range',
					name = 'Global scale',
					min = 0.5,
					max = 1.5,
					step = 0.1,
					get = L.GetFromDefaultOrSV,
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
							step = 0.1,
							get = L.GetFromDefaultOrSV,
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
							step = 1,
							get = function() return ( L.Get('titleoffset') ) / 100 end,
							set = function(self, val)
								L.cfg.titleoffset = val * 100
								L.frame.TitleButtons:SetPoint('CENTER', UIParent, 'CENTER', val * 100, 0)
							end,
						},
					},
				},
				box = {
					type = 'group',
					name = MODEL .. ' / ' .. DESCRIPTION,
					args = {
						boxscale = {
							type = 'range',
							name = 'Scale',
							order = 0,
							min = 0.5,
							max = 1.5,
							step = 0.1,
							get = L.GetFromDefaultOrSV,
							set = function(self, val) 
								L.cfg.boxscale = val
								L.frame.TalkBox:SetScale(val)
							end,
						},
						boxoffsetY = {
							type = 'range',
							name = 'Offset Y',
							order = 4,
							min = -600,
							max = 600,
							step = 50,
							get = L.GetFromDefaultOrSV,
							set = function(_, val) local b = L.frame.TalkBox
								L.cfg.boxoffsetY = val
								b:ClearAllPoints()
								b:SetOffset()
							end,
						},
						boxoffsetX = {
							type = 'range',
							name = 'Offset X',
							order = 3,
							min = -600,
							max = 600,
							step = 50,
							get = L.GetFromDefaultOrSV,
							set = function(_, val) local b = L.frame.TalkBox
								L.cfg.boxoffsetX = val
								b:ClearAllPoints()
								b:SetOffset()
							end,
						},
						boxpoint = {
							type = 'select',
							name = 'Anchor point',
							order = 1,
							values = anchors,
							get = L.GetFromDefaultOrSV,
							set = function(_, val) local b = L.frame.TalkBox
								L.cfg.boxpoint = val
								b:ClearAllPoints()
								b:SetOffset()
							end,
							style = 'dropdown',
						},
					},
				},
			},
		},
	},
}