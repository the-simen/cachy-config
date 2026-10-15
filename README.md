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
- `scripts/` — helper scripts (Noctalia install / palette restore,
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
  `telegram`, `steam`, `web-app-creator`). Wine/Steam
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

The script removes the current `settings.toml` and copies the given file
in its place. Then restart the Noctalia shell.
(The install script runs this for you.)

## Noctalia-generated palettes

Files rendered by Noctalia templates on theme switch are **not** tracked
in git (see `.gitignore`): `ghostty/themes/noctalia`,
`hypr/noctalia.lua`, `kitty/themes/noctalia.conf`,
`tmux/themes/noctalia-palette.conf`, `superfile/theme/noctalia.toml`,
`mpv/script-opts/modernz.conf`, `niri/noctalia.kdl`,
`btop/themes/noctalia.theme`, `umbriel/noctalia.toml`, etc.
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
