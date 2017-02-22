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


setmetatable(L, {
	__call = function(self, input)
		return L.Get(input) or self[input]
	end,
})


----------------------------------
-- Default config
----------------------------------

L.defaults = {
----------------------------------
	scale = 1,
	strata = 'MEDIUM',
	hideui = false,

	titlescale = 1,
	titleoffset = -500,

	boxscale = 1,
	boxoffsetX = 0,
	boxoffsetY = 150,
	boxpoint = 'Bottom',

	disableprogression = false,
	flipshortcuts = false,
	delaydivisor = 15,

	accept = 'SPACE',
	reset = 'BACKSPACE',
}---------------------------------

local anchors = {
	Top 	= L['Top'],
	Bottom 	= L['Bottom'],
	Right 	= L['Right'],
	Left 	= L['Left'],
}

local stratas = {
	LOW 		= L['Low'],
	MEDIUM 		= L['Medium'],
	HIGH 		= L['High'],
	DIALOG		= L['Dialog'],
	FULLSCREEN 	= L['Fullscreen'],
	FULLSCREEN_DIALOG = L['Fullscreen dialog'],
	TOOLTIP 	= L['Tooltip'],
}

L.options = {
	type = 'group',
	args = {		
		general = {
			type = 'group',
			name = GENERAL,
			order = 1,
			args = {
				disableprogression = {
					type = 'toggle',
					name = L['Disable automatic text progress'],
					desc = L['Stop NPCs from automatically proceeding to the next line of dialogue.'],
					order = 1,
					get = L.GetFromSV,
					set = function(_, val) L.cfg.disableprogression = val end,
				},
				delaydivisor = {
					type = 'range',
					name = 'Text speed',
					desc = L['Change the speed of text delivery.'] .. '\n\n' ..
						MINIMUM .. '\n"' ..  L['How are you doing today?'] .. '"\n  -> ' .. 
						format(D_SECONDS, (strlen(L['How are you doing today?']) / 5) + 2)  .. '\n\n' .. 
						MAXIMUM .. '\n"' .. L['How are you doing today?'] .. '"\n  -> ' .. 
						format(D_SECONDS, (strlen(L['How are you doing today?']) / 40) + 2),
					min = 5,
					max = 40,
					step = 5,
					order = 3,
					get = L.GetFromDefaultOrSV,
					set = function(self, val) 
						L.cfg.delaydivisor = val
					end,
				},
				hideui = {
					type = 'toggle',
					name = L['Hide interface'],
					desc = L['Hide my user interface when interacting with an NPC.'],
					order = 2,
					get = L.GetFromSV,
					set = function(_, val) L.cfg.hideui = val end,
				},
			},
		},
		keybindings = {
			type = 'group',
			name = KEY_BINDINGS,
			order = 2,
			args = {
				header = {
					type = 'header',
					name = KEY_BINDINGS,
					order = 0,
				},
				accept = {
					type = 'keybinding',
					name = ACCEPT,
					desc = L.GetListString(ACCEPT, NEXT, CONTINUE, COMPLETE_QUEST, GOODBYE),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.accept = L.ValidateKey(val) end,
					order = 1,
				},
				ignore = {
					type = 'keybinding',
					name = IGNORE .. '/' .. UNIGNORE_QUEST,
					desc = L.GetListString(QUESTS_LABEL, IGNORE_QUEST, UNIGNORE_QUEST),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.ignore = L.ValidateKey(val) end,
					order = 3,
				},
				reset = {
					type = 'keybinding',
					name = RESET,
					get = L.GetFromSV,
					set = function(_, val) L.cfg.reset = L.ValidateKey(val) end,
					order = 4,
				},
				goodbye = {
					type = 'keybinding',
					name = GOODBYE .. '/' .. CLOSE .. ' (' .. KEY_ESCAPE .. ')',
					desc = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.goodbye = L.ValidateKey(val) end,
					order = 2,
				},
				enablenumbers = {
					type = 'toggle',
					name = '[1-9] ' .. PET_BATTLE_SELECT_AN_ACTION, -- lol
					desc = L.GetListString(QUESTS_LABEL, GOSSIP_OPTIONS),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.enablenumbers = val end,
					order = 5,
				},
				flipshortcuts = {
					type = 'toggle',
					name = L['Flip mouse functions'],
					desc = L.GetListString(
						L['Left click is used to handle text.'], 
						L['Right click is used to accept/hand in quests.']),
					order = 2,
					get = L.GetFromSV,
					set = function(_, val) L.cfg.flipshortcuts = val end,
					order = 6,
				},
			},
		},
		display = {
			type = 'group',
			name = DISPLAY,
			order = 3,
			args = {
				header = {
					type = 'header',
					name = DISPLAY,
				},
				strata = {
					type = 'select',
					name = L['Frame strata'],
					order = 2,
					values = stratas,
					get = L.GetFromDefaultOrSV,
					set = function(_, val) local f = L.frame
						L.cfg.strata = val
						f:SetFrameStrata(val)
						f.TalkBox:SetFrameStrata(val)
					end,
					style = 'dropdown',
				},
				scale = {
					type = 'range',
					name = 'Global scale',
					min = 0.5,
					max = 1.5,
					step = 0.1,
					order = 1,
					get = L.GetFromDefaultOrSV,
					set = function(self, val) 
						L.cfg.scale = val
						L.frame:SetScale(val)
					end,
				},
				description = {
					type = 'description',
					fontSize = 'medium',
					name = L['In this category, you can customize the placement and size of the individual parts of Immersion.'] ..'\n\n' .. 
							L.GetListString(
								MODEL ..' / '..DESCRIPTION ..': '..L['Customize the talking head frame.'],
								QUESTS_LABEL..' / '..GOSSIP_OPTIONS..': '..L['Change the placement and scale of your dialogue options.']),
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
							name = L['Offset from center'],
							min = -10,
							max = 10,
							step = 1,
							get = function() return ( L('titleoffset') ) / 100 end,
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
							name = L['Scale'],
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
							name = L['Offset Y'],
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
							name = L['Offset X'],
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
							name = L['Anchor point'],
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