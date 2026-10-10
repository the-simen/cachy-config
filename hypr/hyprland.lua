local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr"
package.path = package.path .. ";" .. home .. "/.config/caelestia/?.lua"

hl.monitor({
	output = "DP-2",
	mode = "1920x1080@239.760",
	position = "auto",
	scale = "auto",
})

hl.monitor({
	output = "DP-3",
	mode = "1920x1080@144.002",
	position = "auto",
	scale = "auto",
})

-- Copy src to dst, but only if dst doesn't already exist
local function maybe_copy(src, dst)
	local out = io.open(dst)
	if out then
		out:close()
		return
	end

	local input = io.open(src, "r")
	if not input then
		return
	end

	out = io.open(dst, "w")
	if out then
		out:write(input:read("*a"))
		out:close()
	end
	input:close()
end

-- Maybe set current colours to defaults
maybe_copy(hypr .. "/scheme/default.lua", hypr .. "/scheme/current.lua")

-- Default monitor conf
hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})

-- Configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")

-- For Noctalia Color templates (hypr/noctalia.lua is generated and git-ignored)
local ok, noctalia = pcall(require, "noctalia")
if not (ok and noctalia and noctalia.apply_theme) then
	-- Fallback to tracked default palette (fresh clone / before first render)
	noctalia = require("noctalia-default")
end
noctalia.apply_theme()
