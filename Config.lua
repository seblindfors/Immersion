local _, L = ...

L.TEXT_TIME_PADDING = 0.5 -- static padding, feels more natural with a pause to breathe.  Moved from Text.lua so that it can be used in the calculations for the mouseover description of Text speed option

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

function L.ValidatePadKey(key)
	return ( key and key:match('^PAD') ) and key
end

function L.GetDefaultConfig()
	local t = {}
	for k, v in pairs(L.defaults) do
		t[k] = v
	end
	return t
end

function L.Get(key)
	if L.cfg and L.cfg[key] ~= nil then
		return L.cfg[key]
	else
		return L.defaults[key]
	end
end

function L.Set(key, val)
	L.cfg = L.cfg or {}
	L.cfg[key] = val
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
--	theme = 'DEFAULT',

	titlescale = 1,
	titleoffset = 500,
	titleoffsetY = 0,

	elementscale = 1,

	boxscale = 1,
	boxoffsetX = 0,
	boxoffsetY = 150,
	boxlock = true,
	boxpoint = 'Bottom',

	disableprogression = false,
	flipshortcuts = false,
	delaydivisor = 15,
	anidivisor = 5,

	ttsenabled = false,
	ttsrate = 0,
	ttsvolume = 100,
	ttsvoice = 1,
	ttsmalevoice = 1,
	ttsfemalevoice = 1,

	inspect = 'SHIFT',
	accept = 'SPACE',
	reset = 'BACKSPACE',

	padaccept  = 'PAD1',
	padinspect = 'PAD4',
	padnext    = 'PAD3',
	padgoodbye = 'PAD2',
	padup      = 'PADDUP',
	paddown    = 'PADDDOWN',
	padleft    = 'PADDLEFT',
	padright   = 'PADDRIGHT',
}
