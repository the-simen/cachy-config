#!/usr/bin/env bash
# =============================================================================
# Theme: Kanagawa
# Variant: Paper (mapped from material tokens)
# =============================================================================

declare -gA THEME_COLORS=(
    # =========================================================================
    # CORE
    # =========================================================================
    [background]="#f2f1ec"               # mSurface

    # =========================================================================
    # STATUS BAR
    # =========================================================================
    [statusbar-bg]="#e4e1d8"             # mSurfaceVariant
    [statusbar-fg]="#4f5357"             # mOnSurface

    # =========================================================================
    # SESSION
    # =========================================================================
    [session-bg]="#6b7f9f"               # mPrimary
    [session-fg]="#ffffff"               # mOnPrimary
    [session-prefix-bg]="#a7956a"        # terminal.yellow
    [session-copy-bg]="#809ba7"          # terminal.blue
    [session-search-bg]="#7b958e"        # terminal.green
    [session-command-bg]="#9e7e98"       # terminal.magenta

    # =========================================================================
    # WINDOW (active)
    # =========================================================================
    [window-active-base]="#c8c5bd"     # mShadow
    [window-active-style]="bold"

    # =========================================================================
    # WINDOW (inactive)
    # =========================================================================
    [window-inactive-base]="#4f5357"       # mOnSurface
    [window-inactive-style]="none"

    # =========================================================================
    # WINDOW STATE
    # =========================================================================
    [window-activity-style]="italics"
    [window-bell-style]="bold"
    [window-zoomed-bg]="#6f8795"         # mSecondary

    # =========================================================================
    # PANE
    # =========================================================================
    [pane-border-active]="#6b7f9f"       # mPrimary
    [pane-border-inactive]="#8e8a80"     # mOutline

    # =========================================================================
    # STATUS COLORS
    # =========================================================================
    [ok-base]="#666b70"                  # mOnSurfaceVariant
    [good-base]="#7b958e"                # terminal.green
    [info-base]="#809ba7"                # terminal.blue
    [warning-base]="#a7956a"             # terminal.yellow
    [error-base]="#c27672"               # mError
    [disabled-base]="#9e9e96"            # terminal.white

    # =========================================================================
    # MESSAGE
    # =========================================================================
    [message-bg]="#e4e1d8"               # mSurfaceVariant
    [message-fg]="#4f5357"               # mOnSurface

    # =========================================================================
    # POPUP & MENU
    # =========================================================================
    [popup-bg]="#e4e1d8"
    [popup-fg]="#4f5357"
    [popup-border]="#8e8a80"             # mOutline

    [menu-bg]="#e4e1d8"
    [menu-fg]="#4f5357"
    [menu-selected-bg]="#6b7f9f"         # mPrimary
    [menu-selected-fg]="#ffffff"         # mOnPrimary
    [menu-border]="#8e8a80"
)
