# cachy-config

These configs primarily target the **CachyOS + Niri + Noctalia** setup.
Some files (fish, tmux, mpv, ghostty/kitty, etc.) are portable, but this
stack is the baseline: Niri as the compositor, Noctalia as the shell
(bar, dock, notifications, theming).

> **Strong recommendation: use the install script.**
> This repo is not "just copy `~/.config` and done" — several paths
> outside `~/.config` must be symlinked / installed (see below).
> The install script does all of it, in the right order:
>
> ```sh
> git clone https://github.com/the-simen/bash-scripts/ ~/bash-scripts/ \
>   && sudo chmod +x ~/bash-scripts/cachyos/install.sh \
>   && ~/bash-scripts/cachyos/install.sh
> ```
>
> Source: https://github.com/the-simen/bash-scripts (`cachyos/install.sh`).
> Update later with `cd ~/bash-scripts && git pull` + `cachyos/update.sh`
> (pulls `~/.config` and `~/.config/nvim`, stashing local changes first).
>
> What `install.sh` does for this repo:
>
> - `pacman -Syu`, installs `PACMAN_PACKAGES`, AUR (`paru`) and Flatpak apps,
>   sets fish as default shell, enables NetworkManager;
> - backs up existing `~/.config` to `~/.config_backup_<date>`;
> - clones this repo to `~/cachy-config` and rsyncs it over `~/.config`
>   (without wiping unrelated dirs);
> - creates the `applications` symlink (see below);
> - installs the Noctalia config via
>   `~/.config/scripts/install_noctalia_conf.sh`;
> - enables user services (`ssh-agent.service`, `cliphist.service`);
> - installs TPM (`~/.tmux/plugins/tpm`) and links
>   `~/.tmux.conf -> ~/.config/tmux/.tmux.conf`;
> - installs NvChad separately to `~/.config/nvim`;
> - installs `tide` prompt via fisher, fixes the Discord updater issue.
>
> If you install manually, replicate **at least** the symlinks in the
> "Symlinks" section — otherwise launchers / tmux will silently use
> stale copies.

## Config Manager (TUI)

Prefer clicks over the terminal? Launch **Config Manager** from the app
menu (`applications/config-manager.desktop`):

- on start it clones `~/bash-scripts` if missing, otherwise pulls updates;
- paints its own `dialog` UI in the live Noctalia palette
  (`scripts/generate-dialogrc.py` quantizes `noctalia/colors.json`
  into `dialog/noctalia` on every launch);
- shows repo status right in the main menu: last commits of
  `bash-scripts`, `cachy-config`, `nvim`, upstream behind/ahead,
  local changes;
- runs `cachyos/install.sh` (full install), `cachyos/update.sh`
  (repos + missing packages from `packages/`, live Noctalia settings
  are never touched), applies the repo Noctalia config explicitly
  (with a timestamped backup of the live file) or exports the live
  settings back into `noctalia/config.toml.full` — all with live output;
- commit list shows subject + body snippet; full bodies (last 5 per repo)
  open in a scrollable viewer via the Commits item.

UI is a native hover menu (`scripts/hover-menu.sh`: mouse hover
highlights, click confirms instantly, vim keys, rounded truecolor
box in the live Noctalia palette) with `dialog` (mouse-clickable),
`gum` and plain-prompt fallbacks. Backend scripts: `scripts/config-manager.sh`,
`scripts/open_config_manager.sh` (kitty window, own 800×600 floating
rule in `niri/cfg/rules.kdl` + `hypr/hyprland/rules.lua`).

## Contents

- `niri/` — Niri compositor config. `config.kdl` only `include`s
  `cfg/*.kdl` (`animations`, `autostart`, `autostart-apps`, `keybinds`,
  `input`, `display`, `layout`, `rules`, `misc`) plus `game-mode.kdl`,
  `noctalia.kdl`, `animations.kdl`. Per-app helpers live in
  `niri/applications/` (`terminal.sh`, `browser.sh`, `files.sh`,
  `music.sh`, `tmux.sh`). Machine-local overrides go to
  `niri/overrides/` — it is git-ignored on purpose.
- `noctalia/` — Noctalia config (`config.toml`, `config.toml.full`),
  custom theming templates (`templates/`, `templates.toml`,
  `user-templates.toml`), including a custom Telegram theme
  with fixed selection contrast (`telegram-contrast.tdesktop-theme`
  + `telegram-pack.py` post-hook).
- `applications/` — custom `.desktop` launchers, tracked in git here
  but consumed from `~/.local/share/applications` **via symlink**.
  See "Symlinks" — this is the most commonly missed step.
- `icons/` — custom launcher icons (Papirus-based SVGs):
  `config-manager.svg`, `web-app-creator.svg`, referenced by absolute
  path from the matching `.desktop` files.
- `scripts/` — helper scripts (Noctalia install / palette restore,
  `config-manager.sh` TUI, `generate-dialogrc.py`,
  `web_app_creator.sh`, `system_update.sh`, `gamemode.sh`,
  tmux resurrect save/pick, `systemd_autostart.sh`, etc.).
- `systemd/user/` — user units: `ssh-agent`, `cliphist`,
  `noctalia`, `quickshell`, `device-sounds`, `xremap-onlyoffice`.
- everything else — terminals, shell, multiplexer and app configs
  (fish, tmux, ghostty, kitty, mpv, btop, fastfetch, yazi, mc,
  superfile, umbriel, xremap, hypr fallback, git aliases, etc.).

## Symlinks (required)

This repo keeps canonical files in `~/.config` and exposes them where
Linux tools expect them via symlinks. **Do not copy — link.**
Copies drift out of sync on the next `git pull`.

| Expected path | Points to | Why |
|---|---|---|
| `~/.local/share/applications` | `~/.config/applications` | Custom launchers (browsers as apps, `btop++`, games, `web-app-creator`, fixed `discord`/`telegram`/`steam` entries) must be visible to the DE/launcher. |
| `~/.tmux.conf` | `~/.config/tmux/.tmux.conf` | tmux only reads `~/.tmux.conf`; the versioned config lives in the repo. Same pattern: keep one source of truth, link it in. |

The install script creates them with:

```sh
# applications (from cachyos/install.sh)
mkdir -p "$HOME/.local/share"
rm -rf "$HOME/.local/share/applications"
ln -s "$HOME/.config/applications" "$HOME/.local/share/applications"

# tmux (from cachyos/install.sh)
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
ln -sf ~/.config/tmux/.tmux.conf ~/.tmux.conf
```

After (re)linking launchers, refresh the desktop database so new
`.desktop` files show up immediately:

```sh
update-desktop-database ~/.local/share/applications
```

Notes:

- Only a curated subset of `applications/*.desktop` is tracked
  (see `.gitignore`: `AmneziaVPN`, `btop`, `discord`, `OpenRGB`,
  `telegram`, `steam`, `web-app-creator`, `config-manager`). Wine/Steam
  auto-generated entries, `mimeinfo.cache` and `userapp-*` files are
  intentionally untracked machine noise.
- Same symlink philosophy applies to `~/.gitconfig`:
  it is a tiny stub outside the repo that does
  `[include] path = ~/.config/git/aliases.gitconfig`.
- `tmux/plugins/` is git-ignored (TPM installs there at deploy time).

## Installing the Noctalia config

The active Noctalia config lives outside this repo at
`~/.local/state/noctalia/settings.toml`.
To install the config from this repository:

```sh
./scripts/install_noctalia_conf.sh noctalia/config.toml.full
```

The script backs up the current `settings.toml` next to itself
(`*.backup_*`) and copies the given file in its place.
Then restart the Noctalia shell.
(The install script runs this for you; `cachyos/update.sh`
deliberately never touches the live settings — apply explicitly
from Config Manager when you really want the repo snapshot.)

## Noctalia-generated palettes

Files rendered by Noctalia templates on theme switch are **not** tracked
in git (see `.gitignore`): `ghostty/themes/noctalia`,
`hypr/noctalia.lua`, `kitty/themes/noctalia.conf`,
`tmux/themes/noctalia-palette.conf`, `superfile/theme/noctalia.toml`,
`mpv/script-opts/modernz.conf`, `niri/noctalia.kdl`,
`btop/themes/noctalia.theme`, `umbriel/noctalia.toml`,
`dialog/noctalia` (quantized to dialog's 16 named colors by
`scripts/generate-dialogrc.py` on every Config Manager launch), etc.
(`templates.toml` maps each `templates/*` input to its rendered
output, including vesktop/Vencord CSS, the Telegram theme and
`nvim/lua/themes/noctalia.lua`.)

Each has a tracked `*-default` fallback snapshot next to it:

- tmux / kitty source the default first, the generated file overrides it;
- `hypr/hyprland.lua` falls back to `hypr/noctalia-default.lua`
  if the generated module is missing;
- everything else is restored from defaults on a fresh clone
  (before the first render) with:

```sh
./scripts/ensure-noctalia-palettes.sh
```

Run this once after a manual clone, before the first Noctalia
`templates-apply` / theme switch, so apps never start without a theme.

## Manual setup checklist (if you skip the installer)

1. Clone/copy this repo to `~/.config` (back up yours first).
2. Create both symlinks from the table above.
3. `./scripts/ensure-noctalia-palettes.sh`
4. `./scripts/install_noctalia_conf.sh noctalia/config.toml.full`
5. `systemctl --user daemon-reload` + enable needed units from
   `systemd/user/` (at minimum `ssh-agent.service`, `cliphist.service`).
6. Install TPM to `~/.tmux/plugins/tpm` and press `<prefix> + I`
   inside tmux (`C-f I` here — prefix is `C-f`, reload is `r`).
7. `update-desktop-database ~/.local/share/applications`, relogin.

## Git model

`.gitignore` is an allowlist: `*` ignores everything, then `!...`
re-includes only curated paths. Consequences worth knowing:

- New `~/.config/<app>/` dirs are **invisible to git** until you add
  an explicit `!` rule — intentional, avoids committing machine state.
- Never commit: Noctalia renders (`noctalia*`, `colors.json`),
  `fish/fish_variables*`, `tmux/plugins/`, `niri/overrides/`,
  `mimeinfo.cache` / `userapp-*` launchers.
- Local-only tweaks belong in ignored spots (`niri/overrides/`,
  fish universal variables) so `git pull` updates stay clean.

## Related repositories

- Neovim (kept separately): https://github.com/the-simen/nvchad-configs
- Install-everything script: https://github.com/the-simen/bash-scripts
