-----------------------------------------------------
-- ----------------------------------------------- --
--   ▄        ▄     ▄  ▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄  ▄     ▄   --
--  ▐░▌      ▐░▌   ▐░▌▐░█▀▀▀▀▀  ▀▀█░█▀▀ ▐░▌   ▐░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░█   █░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌   ▐░░░░░░░▌  --
--  ▐░▌      ▐░▌   ▐░▌▐░▌         ▐░▌    ▀▀▀▀▀█░▌  --
--  ▐░█▄▄▄▄▄ ▐░█▄▄▄█░▌▐░█▄▄▄▄▄  ▄▄█░█▄▄       ▐░▌  --
--   ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀        ▀   --
-- ----------------------------------------------- --
-- ------- Luci4 util print Ampache stats -------- --
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

if (ampache.shouldPrintHelp()) then
    ampache.printHelp("artist_songs.lua")
    return
end

local server_url, username, password, limit, filter_value, is_json_output = 
    ampache.parseArgs(arg)

local res, code, response_headers, status, json_response, data = ampacheHttp.makeRequest({
        serverUrl = server_url,
        action = "artist_songs",
        username = username,
        password = password,
        limit = limit,
        filterValue = filter_value
    })

-- Check if the request was successful
if code == 200 then
    
    -- if the -j option is passed, just print the json file
    if is_json_output == true then
    	print(json_response)
	    return
    end

    for _, item in ipairs(data["song"]) do
        -- Print name if valid
        -- safePrint("title", string.format("%s (id: %s)", item.title, item.id))
        ampache.safePrint(item.artist.name, item.title)

        if item.url then
            print(item.url)
        end

        if item.album.name then
            print(item.album.name)
        end

        if item.art and item.has_art then
            print(item.art)
        end

        print("\n")  -- Add a blank line between items
    end
else
    -- Print an error message if the request fails
    print("HTTP request failed with status: " .. status)
end

