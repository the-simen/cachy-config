local vars = require("variables")

hl.config({
	general = {
		layout = "scrolling",

		allow_tearing = false, -- Allows `immediate` window rule to work

		gaps_workspaces = vars.workspaceGaps,
		gaps_in = vars.windowGapsIn,
		gaps_out = vars.windowGapsOut,
		border_size = vars.windowBorderSize,

		col = {
			active_border = vars.activeWindowBorderColour,
			inactive_border = vars.inactiveWindowBorderColour,
		},
	},

	dwindle = {
		preserve_split = true,
		smart_split = false,
		smart_resizing = true,
	},

	scrolling = {
		fullscreen_on_one_column = true,
		focus_fit_method = 1,
		column_width = 0.5,
		follow_focus = true,
		follow_min_visible = 0.0,
		explicit_column_widths = "0.5, 0.66667, 0.86667, 1.0",
	},
})
