----------------------------------------------------
-- ----------------------------------------------- --
--   ▄        ▄     ▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄     ▄   --
--  ▐░▌      ▐░▌   ▐░▌▐░█▀▀▀▀▀  ▀▀█░█▀▀ ▐░▌   ▐░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░█   █░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░░░░░░░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌    ▀▀▀▀▀█░▌  --
--  ▐░█▄▄▄▄▄ ▐░█▄▄▄█░▌▐░█▄▄▄▄▄  ▄▄█░█▄▄       ▐░▌  --
--   ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀        ▀   --
-- ----------------------------------------------- --
-- ----- Luci4 util print Ampache playlists ------ --
-- -------- https://github.com/icefields --------- --
-----------------------------------------------------

-- setting the local path so the script can find dependencies
local script_path = debug.getinfo(1, "S").source:match("(.*/)") or ""
script_path = script_path:sub(2)  -- Removes the '@' at the beginning if it exists
local script_dir = script_path:match("(.+)/")  -- Get everything before the last '/'
script_dir = script_dir or ""  -- If no directory, make it an empty string
package.path = script_dir .. "/?.lua;" .. package.path

local ampache = require("ampache-common")
local ampacheHttp = require("ampache-http")

local function read_credentials()
    local home = os.getenv("HOME")
    local filepath = home .. "/.config/ampache_credentials"
    local file = io.open(filepath, "r")
    if not file then
        error("Could not open credentials file: " .. filepath)
    end

    local server = file:read("*l") -- first line
    local username = file:read("*l") -- second line
    local password = file:read("*l") -- third line
    file:close()

    return server, username, password
end

local server, username, password = read_credentials()

local res, code, response_headers, status, jsonResponse, data = 
        ampacheHttp.makeRequest({
            serverUrl = server,
            action = "playlists",
            username = username,
            password = password,
            limit = 10,
            filterValue = nil, --ampache.urlencode(arg[1]),
            include = "song"
        }, false)

local token = ampacheHttp.authToken

function playlists()
    str = ''
    for _, item in ipairs(data["playlist"]) do
        print(item.name)
        --str = (item.name).."\n"..str
    end
    --print(str)
end

function songUrls()
    for _, item in ipairs(data["playlist"]) do
        if item.name == arg[1] then
            for _, item in ipairs(item.items) do
                print(ampacheHttp.streamUrl(server, username, password, item.id, token))
            end
        end
    end
end

if arg[2] == "-p" then
    playlists()
else
    songUrls()
end
    
