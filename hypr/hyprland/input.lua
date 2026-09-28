local vars = require("variables")

hl.config({
	input = {
		kb_layout = "us,ru",
		numlock_by_default = false,
		kb_options = "ctrl:swapcaps,grp:lctrl_toggle",
		repeat_delay = 250,
		repeat_rate = 30,
		focus_on_close = 1,
		follow_mouse = 1,

		sensitivity = -0.2, -- -1.0 - 1.0, 0 means no modification.
		accel_profile = "flat",

		touchpad = {
			tap_to_click = true,
			natural_scroll = true,
			disable_while_typing = vars.touchpadDisableTyping,
			scroll_factor = vars.touchpadScrollFactor,
		},
	},

	binds = {
		scroll_event_delay = 0,
	},

	cursor = {
		hide_on_key_press = true,
		hotspot_padding = 1,
	},
})
