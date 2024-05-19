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

