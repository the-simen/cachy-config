#!/bin/bash
systemctl --user list-unit-files --state=enabled | awk '{print $1}' | while read unit; do
    systemctl --user start "$unit"
done
