local scheme = require("scheme.current")

return {
	------------------
	---- HYPRLAND ----
	------------------

	-- Apps
	terminal = "kitty",
	browser = "zen-browser",
	editor = "nvim",
	fileExplorer = "nemo",
	audioSettings = "pwvucontrol",

	-- Touchpad
	touchpadDisableTyping = true,
	touchpadScrollFactor = 0.3,
	gestureFingers = 3,
	workspaceSwipeFingers = 4,
	gestureFingersMore = 4,

	-- Blur
	blurEnabled = true,
	blurSpecialWs = false,
	blurPopups = true,
	blurInputMethods = true,
	blurSize = 8,
	blurPasses = 2,
	blurXray = false,

	-- Shadow
	shadowEnabled = true,
	shadowRange = 15,
	shadowRenderPower = 4,
	shadowColour = "rgba(" .. scheme.inversePrimary .. "10)",

	-- Gaps
	workspaceGaps = 12,
	windowGapsIn = 6,
	windowGapsOut = 12,
	singleWindowGapsOut = 12,

	-- Window styling
	windowOpacity = 0.95,
	windowRounding = 15,
	windowBorderSize = 1,
	activeWindowBorderColour = "rgba(" .. scheme.primary .. "e6)",
	inactiveWindowBorderColour = "rgba(" .. scheme.onSurfaceVariant .. "11)",

	-- Misc
	volumeStep = 10,
	volumeMax = 100,
	cursorTheme = "Dracula-cursors",
	cursorSize = 24,
	sleepGestureCmd = "systemctl suspend-then-hibernate",

	------------------
	---- KEYBINDS ----
	------------------
	-- Niri-style binds (Mod == SUPER). Scrolling-column actions that have no
	-- plain variable live directly in hyprland/keybinds.lua.

	-- Modifier only, the actual binds will be mod + 0-9. These should be strings and not arrays.
	kbGoToWs = "SUPER",
	kbGoToWsGroup = "SUPER + CTRL + SHIFT",
	kbMoveWinToWs = "SUPER + CTRL",
	kbMoveWinToWsGroup = "SUPER + CTRL + ALT + SHIFT",

	-- All the following binds can be either an array of binds to bind multiple keys, or a single string.

	-- Workspaces
	kbMoveWinToWsSpecial = { "SUPER + ALT + S", "CTRL + SUPER + SHIFT + Up" },
	kbMoveWinFromWsSpecial = "CTRL + SUPER + SHIFT + Down",
	kbMoveWinToWsNext = {
		"SUPER + ALT + mouse_down",
		"SUPER + ALT + Page_Down",
		"CTRL + SUPER + SHIFT + Right",
		"SUPER + CTRL + mouse_down",
	},
	kbMoveWinToWsPrev = {
		"SUPER + ALT + mouse_up",
		"SUPER + ALT + Page_Up",
		"CTRL + SUPER + SHIFT + Left",
		"SUPER + CTRL + mouse_up",
	},
	kbNextWs = { "SUPER + mouse_down", "CTRL + SUPER + Right", "SUPER + Page_Down", "SUPER + Down", "SUPER + J" },
	kbPrevWs = { "SUPER + mouse_up", "CTRL + SUPER + Left", "SUPER + Page_Up", "SUPER + Up", "SUPER + K" },
	kbNextWsGroup = "CTRL + SUPER + mouse_down",
	kbPrevWsGroup = "CTRL + SUPER + mouse_up",

	-- Window Group
	kbWindowCycleNext = "ALT + TAB",
	kbWindowCyclePrev = "SHIFT + ALT + TAB",
	kbWindowGroupCycleNext = "CTRL + ALT + TAB",
	kbWindowGroupCyclePrev = "CTRL + SHIFT + ALT + TAB",
	kbUngroup = "SUPER + U",
	kbToggleGroup = "SUPER + W",
	kbGroupLockActive = "SUPER + SHIFT + Comma",

	-- Window Actions (width via scrolling colresize, see keybinds.lua)
	kbWindowDecreaseWidth = "SUPER + Minus",
	kbWindowIncreaseWidth = "SUPER + Equal",
	kbWindowDecreaseHeight = "SUPER + SHIFT + Minus",
	kbWindowIncreaseHeight = "SUPER + SHIFT + Equal",

	kbMoveWindow = "SUPER + Z",
	kbResizeWindow = "SUPER + X",
	kbCenterWindow = "CTRL + SUPER + Backslash",
	kbNormalizeWindow = "CTRL + SUPER + ALT + Backslash",
	kbWindowPip = "SUPER + ALT + Backslash",
	kbPinWindow = "SUPER + P",
	kbWindowFullscreen = "SUPER + F",
	kbWindowBorderedFullscreen = "SUPER + ALT + F",
	kbToggleWindowFloating = "SUPER + T",
	kbCloseWindow = "SUPER + Q",

	-- Special workspaces toggles
	kbSpecialWs = "SUPER + S",
	kbSystemMonitorWs = "CTRL + SHIFT + Escape",
	kbMusicWs = "SUPER + CTRL + M",
	kbCommunicationWs = "SUPER + D",
	kbTodoWs = "SUPER + CTRL + T",

	-- Apps (niri binds)
	kbTerminal = "SUPER + Return",
	kbBrowser = "SUPER + B",
	kbEditor = "SUPER + ALT + C",
	kbFileExplorer = "SUPER + E",
	kbAudioSettings = "CTRL + ALT + V",
	kbSpotify = "SUPER + M",
	kbTmux = "SUPER + ALT + Return",
	kbBrowserPrivate = "SUPER + SHIFT + B",

	-- Utilities
	kbScreenshot = "Print",
	kbScreenshotFreeze = "SUPER + SHIFT + S",
	kbScreenshotRegion = "SUPER + SHIFT + ALT + S",
	kbRecord = "CTRL + ALT + R",
	kbRecordSound = "SUPER + ALT + R",
	kbRecordRegion = "SUPER + SHIFT + ALT + R",
	kbColorPicker = "SUPER + SHIFT + C",

	-- Media
	kbMediaToggle = "CTRL + SUPER + Space",
	kbMediaNext = "CTRL + SUPER + Equal",
	kbMediaPrev = "CTRL + SUPER + Minus",
	kbMediaStop = "CTRL + SUPER + Backspace",
	kbVolumeMute = "SUPER + SHIFT + M",

	-- Misc (niri: launcher on Mod+Ctrl+Return, session on Mod+Shift+Q / Mod+Escape,
	-- lock on Mod+Ctrl+Alt+L — all mapped to the caelestia counterparts)
	kbLauncher = { "SUPER + SUPER_L", "SUPER + CTRL + Return" },
	kbSession = { "CTRL + ALT + Delete", "SUPER + SHIFT + Q", "SUPER + Escape" },
	kbShowSidebar = "SUPER + N",
	kbClearNotifs = "CTRL + ALT + C",
	kbShowPanels = "SUPER + K",
	kbLock = { "SUPER + L", "SUPER + CTRL + ALT + L" },
	kbRestoreLock = "SUPER + ALT + L",
	kbSleep = "SUPER + SHIFT + L",

	-- Niri ports without a caelestia counterpart
	kbChangeLayout = "SUPER + CTRL + SHIFT + L",
	kbPresetWidth = "SUPER + R",
	kbExpandColumn = "SUPER + CTRL + F",
	kbCenterColumn = "SUPER + C",
	kbCenterVisibleColumns = "SUPER + CTRL + C",
	kbPowerOffMonitors = "SUPER + SHIFT + P",
	kbScreenshotNiriFull = "CTRL + SHIFT + 1",
	kbScreenshotNiriScreen = "CTRL + SHIFT + 2",
	kbScreenshotNiriWindow = "CTRL + SHIFT + 3",

	-- Clipboard and emoji picker
	kbClipboard = "SUPER + V",
	kbClipboardDel = "SUPER + ALT + V",
	kbClipboardPasteLatest = "CTRL + SHIFT + ALT + V",
	kbEmoji = "SUPER + Period",
}
