#!/bin/bash

#!/bin/bash
WORKING_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

selectsong() {
    input_data=$(cat)
    # oneline=$(awk 'BEGIN {RS=""; FS="\n"} {print $1 "\t" $2 "\n"}')
    #awk 'BEGIN {RS=""; FS="\n"} {print $1 ": " $2 "\t" $3}' | \
    printf "%s" "$input_data" | awk 'BEGIN {RS=""; FS="\n"} {print $1}' | \
        showmenu | \
        while read -r selection; do
            # Extract the URL part from the selection (after the tab)
            url=$(printf "%s" "$input_data" | grep -A 1 "$selection" | tail -n 1)

            # Output only the URL
            echo "$url"
        done
}

showmenu() {
    # Read input from standard input
    input=$(cat)
   
    if command -v wofi >/dev/null 2>&1; then
        echo "$input" | wofi --conf $HOME/.config/wofi/config-smenu --style $HOME/.config/wofi/styleS.css 
    elif command -v dmenu >/dev/null 2>&1; then
        echo "$input" | dmenu -i -l 25
    elif command -v fzf >/dev/null 2>&1; then
        echo "$input" | fzf
    else
        echo "Neither dmenu nor wofi is installed."
        return 1
    fi
}


playsong() {
    songurl=$(cat)
    mpv "$songurl"
}

# Check if exactly 3 parameters are provided
if [ $# -eq 3 ]; then
  serverurl=$1
  username=$2
  password=$3
else
  IFS=$'\n' read -d '' -r serverurl username password < $HOME/.config/ampache_credentials 
fi

song=$(cat songs_cache | awk 'BEGIN {RS=""; FS="\n"} {print $1}' | showmenu)
songsResult=$(lua "$WORKING_DIR/songs.lua" $serverurl $username $password -f "$song")
# FIX CACHE printf "%s" "$songsResult" >> songs_cache 
printf "%s" "$songsResult" |  selectsong | playsong
