#!/bin/bash

WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

playlist_name=$(lua "$WORKING_DIR/generate-playlist.lua" "$playlist_name" "-p" | dmenu -i -l 10 -p "Choose playlist:")

if [ -z "$playlist_name" ]; then
    echo "No playlist selected."
    exit 1
fi

mpv $(lua "$WORKING_DIR/generate-playlist.lua" "$playlist_name")

