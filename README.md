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

### Quick start example
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

