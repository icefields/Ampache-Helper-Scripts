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

if (ampache.shouldPrintHelp()) then
    ampache.printHelp("playlists.lua")
    return
end

local args = ampache.parseArgs(arg)
args.action = "playlists"

local res, code, response_headers, status, jsonResponse, data = 
        ampacheHttp.makeRequest(args, args.is_print_url)

if code == 200 then
    -- if the -j option is passed, just print the json file
    if args.is_json_output == true then
    	print(jsonResponse)
	    return
    end

    for _, item in ipairs(data["playlist"]) do
        ampache.safePrint("name", string.format("%s (id: %s)", item.name, item.id))
        if item.owner then
            ampache.safePrint("owner", item.owner)
        end
        if item.items then
            ampache.safePrint("items", item.items)
        end
        ampache.safePrint("type", item.type)
        ampache.safePrint("last_update", item.last_update)
        if item.has_art then
            ampache.safePrint("art", item.art)
        end
        ampache.safePrint("flag", item.flag)
        ampache.safePrint("rating", item.rating)
        ampache.safePrint("averagerating", item.averagerating)

        print("\n")  -- Add a blank line between items
    end
else
    -- Print an error message if the request fails
    print("HTTP request failed with status: " .. status)
end
