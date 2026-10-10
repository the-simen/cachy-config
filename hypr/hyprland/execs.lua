local vars = require("variables")
local fn = require("utils.functions")

hl.on("hyprland.start", function()
	-- Keyring and auth
	hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
	hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")

	-- Clipboard history
	hl.exec_cmd("wl-paste --type text --watch cliphist store")
	hl.exec_cmd("wl-paste --type image --watch cliphist store")

	-- Auto delete trash 30 days old
	hl.exec_cmd("trash-empty 30")

	-- Cursors
	hl.exec_cmd("hyprctl setcursor " .. vars.cursorTheme .. " " .. vars.cursorSize)
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. vars.cursorTheme)
	hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. vars.cursorSize)

	-- Location provider and night light
	hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")
	hl.exec_cmd("sleep 1 && gammastep")

	-- Forward bluetooth media commands to MPRIS
	hl.exec_cmd("mpris-proxy")

	-- Start shell
	hl.exec_cmd("caelestia shell -d")

	-- ── Niri autostart ports (niri/cfg/autostart.kdl) ──
	-- NOTE: the fish `wait-noctalia` wrapper is dropped: it waits on
	-- noctalia.service, which is not started in this Hypr session.
	-- noctalia.service itself is intentionally NOT started here
	-- (caelestia is the shell); same for the noctalia clipboard notifier
	-- (caelestia/cliphist already cover clipboard).

	-- Login sound (was: after noctalia + 2s)
	hl.exec_cmd("sleep 2 && /usr/bin/pw-play /usr/share/sounds/freedesktop/stereo/service-login.oga")

	-- Systemd (starts all enabled user units, same as niri's script)
	hl.exec_cmd("systemctl --user start device-sounds.service")
	hl.exec_cmd("$HOME/.config/scripts/systemd_autostart.sh")

	-- Applications (delays mirror the original wait-noctalia offsets)
	hl.exec_cmd("sleep 10 && tg-ws-proxy")
	hl.exec_cmd("sleep 10 && steam -silent")
	hl.exec_cmd("sleep 10 && openrgb -p kanagawa-paper")
	hl.exec_cmd("sleep 10 && karing")
	hl.exec_cmd("sleep 10 && Telegram")
	hl.exec_cmd("sleep 10 && discord")
end)

-- Resizer listeners
local function apply_resizer_rules(win)
	local float_center = {
		hl.dsp.window.float({ action = "on", window = win }),
		hl.dsp.window.center({ window = win }),
	}
	local pip_actions = fn.move_actions(win) or {}

	-- Bitwarden
	fn.resizer(win, "Bitwarden", 20, 54, float_center, true, "class") -- Native app
	fn.resizer(win, "^Extension: %(Bitwarden Password Manager%) %- Bitwarden", 20, 54, float_center, false) -- Firefox
	fn.resizer(win, "nngceckbapebfimnlniiiahkandclblb", 20, 54, float_center, true, "class") -- Chromium

	-- Picture in picture
	fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, pip_actions, false)
end

hl.on("window.title", apply_resizer_rules)
hl.on("window.open", apply_resizer_rules)
