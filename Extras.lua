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
	frame:UnregisterAllEvents()
	frame:SetSize(1, 1)
	frame:EnableMouse(false)
	frame:EnableKeyboard(false)
	frame:SetAlpha(0)
	frame:ClearAllPoints()
end

----------------------------------
-- Local backdrops
----------------------------------
L.Backdrops = {
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
	TALKBOX_SOLID = {
		bgFile = PT..'Backdrop_Talkbox_Solid.blp',
		edgeFile = PT..'Edge_Talkbox_BG_Solid.blp',
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