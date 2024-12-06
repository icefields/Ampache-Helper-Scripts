```
   ▄        ▄     ▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄     ▄ 
  ▐░▌      ▐░▌   ▐░▌▐░█▀▀▀▀▀  ▀▀█░█▀▀ ▐░▌   ▐░▌
  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░█   █░▌
  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░░░░░░░▌
  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌    ▀▀▀▀▀█░▌
  ▐░█▄▄▄▄▄ ▐░█▄▄▄█░▌▐░█▄▄▄▄▄  ▄▄█░█▄▄       ▐░▌
   ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀        ▀ 
                                                                 
```

## Helper scripts for Ampache
Lua Dependencies (using LuaRocks):
```
luarocks install luafilesystem
luarocks install lua-cjson
luarocks install dkjson
# Some users might also need to install lua-socket
```

### Quick start examples

### <b> Main Script </b> arts-collage.lua
Generates a collage of images from the stat passed as a parameter.<br>
Stats can be `newest, highest, frequent, recent, forgotten, flagged, random`
```
lua arts-collage.lua -s <size> -f <stat> <serverAddress> <username> <password>
```
```
size: how many cover arts in the collage? Note, to make a squared image use: 4, 9, 16, 25, 32, ...
stat: can be newest, highest, frequent, recent, forgotten, flagged, random
serverAddress: your ampache instance address
```

Example of generated images:
| 16 covers | 9 covers | 25 covers |
| --- | --- | --- |
| ![tiled_image-16-readme](https://github.com/icefields/Ampache-Helper-Scripts/blob/main/tiled_image-16-readme.jpg?raw=true) | ![tiled_image-9-readme](https://github.com/icefields/Ampache-Helper-Scripts/blob/main/tiled_image-9-readme.jpg?raw=true) | ![tiled_image-25-readme](https://github.com/icefields/Ampache-Helper-Scripts/blob/main/tiled_image-25-readme.jpg?raw=true) |

### Print your stats (no image output)
Usage: 
```
lua stats.lua <server_url> <username> <password> [OPTIONS]
```
ARGUMENTS:
```
Required arguments:
  <server_url>   The URL of the Ampache server
  <username>     The username for authentication
  <password>     The password for authentication

Optional arguments:
  -l <limit>     Limit the number of items to retrieve (default: 10)
  -t <type>      Specify the type of items to retrieve (valid values: album, song, artist, video, playlist, podcast, podcast_episode; default: album)
  -f <filter>    Specify the filter for the items (valid values: newest, highest, frequent, recent, forgotten, flagged, random; default: newest)
  -j		     Prints the original json from the network response, when this is passed, all other optional args are ignored
  -h             Show this help message
```

### Other quick examples:
```
# just print the auth token
lua ampache-handshake-print.lua -a http://192.168.61.10 youruser yourpassword

# print the playlists response using the lua script to fetch the token in one line
curl "http://192.168.61.10/public/server/json.server.php?action=playlists&limit=100&filter=&exact=0&offset=0&hide_search=1&show_dupes=1&auth=$(lua ampache-handshake-print.lua -a http://192.168.61.10 youruser yourpassword)"

# save in a variable and reuse for multiple calls
#BASH
auth=$(lua ampache-handshake-print.lua -a http://192.168.61.10 youruser yourpassword)
#FISH
set auth $(lua ampache-handshake-print.lua -a http://192.168.61.10 youruser yourpassword)
curl "http://192.168.61.10/public/server/json.server.php?action=playlists&limit=100&filter=&exact=0&offset=0&hide_search=1&show_dupes=1&auth=$auth"
```

### ampache-handshake.lua
`require` this in your lua scripts (see ampache-handshake-print.lua for example usage).<br>

Exposed functions are:<br>
- `handshake` : returns the full handshake json. `serverUrl`, `username` and `password` are the require parameters
- `getAuthToken` : returns the auth token used for all the authorized calls. `serverUrl`, `username` and `password` are the require parameters

### ampache-handshake-print.lua
utility script to print handshake data.<br>
options: <br>
- `-H` `--handshake` or no option to print the full json response
- `-a` `-auth` to print the auth token, very useful to pipe to other commands or put into a variable in bash to run other commands
- `-h` `--help`, print help message

