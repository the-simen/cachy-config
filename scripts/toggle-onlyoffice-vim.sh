#!/usr/bin/env bash

SERVICE="xremap-onlyoffice.service"

if systemctl --user is-active --quiet "$SERVICE"; then
    systemctl --user stop "$SERVICE"
    notify-send "ONLYOFFICE" "Vim-навигация выключена"
else
    systemctl --user start "$SERVICE"
    notify-send "ONLYOFFICE" "Vim-навигация включена"
fi
