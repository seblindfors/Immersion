local _, L = ...
local PT = 'Interface\\AddOns\\' .. _ .. "\\Textures\\"

--[[ @type: type of frame   ]]
--[[ @name: name of frame   ]]
--[[ @index: (optional) id  ]]
--[[ @parent: parent frame  ]]
--[[ @inherit: add template ]]
--[[ @mixins: mixins to add ]]
--[[ @backdrop: bg info tbl ]]
function L.Create(cfg)
	local frame = CreateFrame(cfg.type, _ .. cfg.name .. (cfg.index or ''), cfg.parent, cfg.inherit)
	if cfg.backdrop then
		L.SetBackdrop(frame, cfg.backdrop)
	end
	if cfg.mixins then
		L.Mixin(frame, unpack(cfg.mixins))
	end
	return frame
end

function L.SetBackdrop(frame, backdrop)
	if BackdropTemplateMixin and not frame.OnBackdropLoaded then
		Mixin(frame, BackdropTemplateMixin)
		frame:HookScript('OnSizeChanged', frame.OnBackdropSizeChanged)
	end
	frame:SetBackdrop(backdrop)
	return frame
end

function L.MixinNormal(object, ...)
	for i = 1, select("#", ...) do
		local mixin = select(i, ...)
		for k, v in pairs(mixin) do
			object[k] = v
		end
	end

	return object
end

function L.Mixin(object, ...)
	object = L.MixinNormal(object, ...)
	if object.HasScript then
		for k, v in pairs(object) do
			if object:HasScript(k) then
				if object:GetScript(k) then
					object:HookScript(k, v)
				else
					object:SetScript(k, v)
				end
			end
		end
	end
	return object
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
	GOSSIP_TITLE_BG = {
		bgFile   = PT..'Backdrop_Gossip.tga',
		edgeFile = PT..'Edge_Gossip_BG.blp',
		edgeSize = 8,
		insets   = { left = 2, right = 2, top = 8, bottom = 8 }
	},
	GOSSIP_HILITE = {
		edgeFile = PT..'Edge_Gossip_Hilite.blp',
		edgeSize = 8,
		insets   = { left = 5, right = 5, top = 5, bottom = 6 }
	},
	GOSSIP_NORMAL = {
		edgeFile = PT..'Edge_Gossip_Normal.blp',
		edgeSize = 8,
		insets   = { left= 5, right = 5, top = -10, bottom = 7 }
	},
	TALKBOX = {
		bgFile   = PT..'Backdrop_Talkbox.blp',
		edgeFile = PT..'Edge_Talkbox_BG.blp',
		edgeSize = 16,
		insets   = { left = 16, right = 16, top = 16, bottom = 16 }
	},
	TALKBOX_SOLID = {
		bgFile   = PT..'Backdrop_Talkbox_Solid.blp',
		edgeFile = PT..'Edge_Talkbox_BG_Solid.blp',
		edgeSize = 16,
		insets   = { left = 16, right = 16, top = 16, bottom = 16 }
	},
	TOOLTIP_BG = {
		bgFile   = PT..'Backdrop_Talkbox.blp',
		edgeFile = PT..'Edge_Talkbox_BG.blp',
		edgeSize = 8,
		insets   = { left = 8, right = 8, top = 8, bottom = 8 }
	},
}