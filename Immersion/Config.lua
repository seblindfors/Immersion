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

function L.Get(key)
	return ( L.cfg and L.cfg[key] or L.defaults[key] )
end

function L.Set(key, val)
	L.cfg = L.cfg or {}
	L.cfg[key] = val
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
	__call = function(self, input, newValue)
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
	titleoffset = 500,
	titleoffsetY = 0,

	boxscale = 1,
	boxoffsetX = 0,
	boxoffsetY = 150,
	boxpoint = 'Bottom',

	disableprogression = false,
	flipshortcuts = false,
	delaydivisor = 15,

	inspect = 'SHIFT',
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

local modifiers = {
	SHIFT = SHIFT_KEY_TEXT,
	CTRL = CTRL_KEY_TEXT,
	ALT = ALT_KEY_TEXT,
	NOMOD = NONE,
}

L.options = {
	type = 'group',
	args = {		
		general = {
			type = 'group',
			name = GENERAL,
			order = 1,
			args = {
				text = {
					type = 'group',
					name = L['Behavior'],
					inline = true,
					args = {
						mouseheader = {
							type = 'header',
							name = TEXT_LABEL,
							order = 0,
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
						order = 1,
						get = L.GetFromDefaultOrSV,
						set = function(self, val) 
							L.cfg.delaydivisor = val
						end,
						},
						disableprogression = {
							type = 'toggle',
							name = L['Disable automatic text progress'],
							desc = L['Stop NPCs from automatically proceeding to the next line of dialogue.'],
							order = 2,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.disableprogression = val end,
						},
						onthefly = {
							type = 'toggle',
							name = L["On the fly"],
							desc = L["The quest/gossip text doesn't vanish when you stop interacting with the NPC or when accepting a new quest. Instead, it vanishes at the end of the text sequence. This allows you to maintain your immersive experience when speed leveling."],
							order = 3,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.onthefly = val end,
						},
						mouseheader = {
							type = 'header',
							name = MOUSE_LABEL,
							order = 4,
						},
						flipshortcuts = {
							type = 'toggle',
							name = L['Flip mouse functions'],
							desc = L.GetListString(
								L['Left click is used to handle text.'], 
								L['Right click is used to accept/hand in quests.']),
							order = 5,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.flipshortcuts = val end,
						},
						immersivemode = {
							type = 'toggle',
							name = L['Immersive mode'],
							desc = L['Use your primary mouse button to read through text, accept/turn in quests and select the best available gossip option.'],
							order = 6,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.immersivemode = val end,
						},
					},
				},
				hide = {
					type = 'group',
					name = L['Hide interface'],
					inline = true,
					args = {
						hideui = {
							type = 'toggle',
							name = L['Hide interface'],
							desc = L['Hide my user interface when interacting with an NPC.'],
							order = 0,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.hideui = val end,
						},
						hideminimap = {
							type = 'toggle',
							name = L['Hide minimap'],
							disabled = function() return not L('hideui') end,
							order = 1,
							get = L.GetFromSV,
							set = function(_, val) 
								L.cfg.hideminimap = val
								L.ToggleIgnoreFrame(Minimap, not val)
								L.ToggleIgnoreFrame(MinimapCluster, not val)
							end,
						},
						hidetracker = {
							type = 'toggle',
							name = L['Hide objective tracker'],
							disabled = function() return not L('hideui') end,
							order = 1,
							get = L.GetFromSV,
							set = function(_, val) 
								L.cfg.hidetracker = val 
								L.ToggleIgnoreFrame(ObjectiveTrackerFrame, not val)
							end,
						},
					},
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
					desc = L.GetListString(ACCEPT, NEXT, CONTINUE, COMPLETE_QUEST),
					get = L.GetFromSV,
					set = function(_, val) L.cfg.accept = L.ValidateKey(val) end,
					order = 1,
				},
				inspect = {
					type = 'select',
					name = INSPECT .. ' ('..ITEMS..')',
					order = 3,
					values = modifiers,
					get = L.GetFromDefaultOrSV,
					set = function(_, val)
						L.cfg.inspect = val
					end,
					style = 'dropdown',
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
					order = 3,
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
				description = {
					type = 'description',
					fontSize = 'medium',
					name = L['In this category, you can customize the placement and size of the individual parts of Immersion.'] ..'\n\n' .. 
							L.GetListString(
								MODEL ..' / '.. LOCALE_TEXT_LABEL ..': '..L['Customize the talking head frame.'],
								QUESTS_LABEL..' / '..GOSSIP_OPTIONS..': '..L['Change the placement and scale of your dialogue options.']) .. '\n',
				},
				titles = {
					type = 'group',
					name = QUESTS_LABEL .. ' / ' .. GOSSIP_OPTIONS,
					inline = true,
					args = {
						gossipatcursor = {
							type = 'toggle',
							name = L['Show at mouse location'],
							order = 2,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.gossipatcursor = val end,
							order = 0,
						},
						titlelock = {
							type = 'toggle',
							name = LOCK,
							order = 2,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.titlelock = val end,
							order = 1,
						},
						titlescale = {
							type = 'range',
							name = 'Scale',
							min = 0.5,
							max = 1.5,
							step = 0.1,
							order = 2,
							get = L.GetFromDefaultOrSV,
							set = function(self, val) 
								L.cfg.titlescale = val
								L.frame.TitleButtons:SetScale(val)
							end,
						},
					},
				},
				box = {
					type = 'group',
					name = MODEL .. ' / ' .. LOCALE_TEXT_LABEL,
					inline = true,
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
							step = 10,
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
							step = 10,
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
						disableflyin = {
							type = 'toggle',
							name = L['Disable fly-in animation'],
							order = 5,
							get = L.GetFromSV,
							set = function(_, val) L.cfg.disableflyin = val end,
						},
					},
				},
			},
		},
	},
}