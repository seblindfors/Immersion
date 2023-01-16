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

L.UIHider = CreateFrame('Frame', _ .. 'UIHider')
L.UIHider:Hide()
function L.HideFrame(frame)
	frame:UnregisterAllEvents()
	frame:SetParent(L.UIHider)
	if UIPanelWindows then
		UIPanelWindows[frame:GetName()] = nil;
	end
end

function L.SetGradient(texture, orientation, ...)
	local isOldFormat = (select('#', ...) == 8)
	if texture.SetGradientAlpha then
		if isOldFormat then 
			return texture:SetGradientAlpha(orientation, ...)
		end
		local min, max = ...;
		local minR, minG, minB, minA = ColorMixin.GetRGBA(min)
		local maxR, maxG, maxB, maxA = ColorMixin.GetRGBA(max)
		return texture:SetGradientAlpha(orientation, minR, minG, minB, minA, maxR, maxG, maxB, maxA)
	end
	if texture.SetGradient then
		if isOldFormat then
			local minColor = CreateColor(...)
			local maxColor = CreateColor(select(5, ...))
			return texture:SetGradient(orientation, minColor, maxColor)
		end
		local min, max = ...;
		return texture:SetGradient(orientation, min, max)
	end
end

function L.SetLight(model, enabled, lightValues)
	if ImmersionAPI.IsWoW10 then
		return model:SetLight(enabled, lightValues)
	end

	local dirX, dirY, dirZ = lightValues.point:GetXYZ()
	local ambR, ambG, ambB = lightValues.ambientColor:GetRGB()
	local difR, difG, difB = lightValues.diffuseColor:GetRGB()

	return model:SetLight(enabled,
		lightValues.omnidirectional,
		dirX, dirY, dirZ,
		lightValues.diffuseIntensity,
		difR, difG, difB,
		lightValues.ambientIntensity,
		ambR, ambG, ambB
	)
end

ImmersionAPI.SetGradient = L.SetGradient; -- for XML

----------------------------------
-- Local backdrops
----------------------------------
L.Backdrops = {
	GOSSIP_TITLE_BG = {
		bgFile   = PT..'Backdrop_Gossip.tga',
		edgeFile = PT..'Edge_Gossip_BG.blp',
		edgeSize = 4,
		insets   = { left = 1, right = 2, top = 2, bottom = 2 }
	},
	GOSSIP_HILITE = {
		edgeFile = PT..'Edge_Gossip_Hilite.blp',
		edgeSize = 4,
	},
	GOSSIP_NORMAL = {
		edgeFile = PT..'Edge_Gossip_Normal.blp',
		edgeSize = 4,
	},
	TALKBOX = {
		bgFile   = PT..'Backdrop_Talkbox.blp',
		edgeFile = PT..'Edge_Talkbox_BG.blp',
		edgeSize = 16,
		insets   = { left = 16, right = 16, top = 16, bottom = 16 }
	},
	TALKBOX_HILITE = {
		edgeFile = PT..'Edge_Gossip_Hilite.blp',
		edgeSize = 8,
	},
	TALKBOX_SOLID = {
		bgFile   = PT..'Backdrop_Talkbox_Solid.blp',
		edgeFile = PT..'Edge_Talkbox_BG_Solid.blp',
		edgeSize = 16,
		insets   = { left = 16, right = 16, top = 16, bottom = 16 }
	},
	TOOLTIP_HILITE = {
		edgeFile = PT..'Edge_Gossip_Hilite.blp',
		edgeSize = 8,
	},
}