#!/usr/bin/env fish

lua artist-songs.lua $argv[1] $argv[2] $argv[3] -j -f $argv[4] | jq -r '.song[] | .url' | while read url
    set filename (basename $url)
    curl -o $HOME/Music/ampachedownloads/$filename $url
end

