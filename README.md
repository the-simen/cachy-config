# cachy-config

These configs primarily target the **CachyOS + Niri + Noctalia** setup.
Some files (fish, tmux, mpv, ghostty/kitty, etc.) are portable, but this
stack is the baseline: Niri as the compositor, Noctalia as the shell
(bar, dock, notifications, theming).

## Contents

- `niri/` — Niri compositor config
- `noctalia/` — Noctalia config (`config.toml`), custom theming templates
  (`templates/`, `templates.toml`), including a custom Telegram theme
  with fixed selection contrast (`telegram-contrast.tdesktop-theme`)
- `scripts/` — helper scripts
- everything else — terminals, shell, multiplexer and app configs
  (fish, tmux, ghostty, kitty, mpv, btop, fastfetch, yazi, mc, systemd, etc.)

## Installing the Noctalia config

The active Noctalia config lives outside this repo at
`~/.local/state/noctalia/settings.toml`.
To install the config from this repository:

```sh
./scripts/install_noctalia_conf.sh noctalia/config.toml.full
```

The script removes the current `settings.toml` and copies the given file
in its place. Then restart the Noctalia shell.

## Related repositories

- Neovim (kept separately): https://github.com/the-simen/nvchad-configs
- Install-everything script: https://github.com/the-simen/bash-scripts
